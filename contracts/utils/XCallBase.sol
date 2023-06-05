// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../xcall/libraries/BTPAddress.sol";
import "../xcall/interfaces/IFeeManage.sol";
import "../xcall/interfaces/ICallService.sol";
import "../xcall/interfaces/ICallServiceReceiver.sol";

contract XCallBase is ICallServiceReceiver, Initializable, Ownable {
    address public callSvc;

    string public callSvcBtpAddr;
    string public networkID;

    uint256 private lastRollbackId;

    struct RollbackData {
        uint256 id;
        bytes rollbackData;
        uint256 ssn;
    }

    mapping(uint256 => RollbackData) private rollbacks;

    event MessageReceived(string indexed _from, bytes _data);
    event MessageSent(address indexed _from, uint256 indexed _messageId, bytes _data);
    event RollbackDataReceived(string indexed _from, bytes _data);

    receive() external payable {}
    fallback() external payable {}

    modifier onlyCallService() {
        require(msg.sender == callSvc, "NFTProxy: only CallService can call this function");
        _;
    }

    /**
        @notice Initializer. Replaces constructor.
        @dev Callable only once by deployer.
        @param _callServiceAddress Address of x-call service on the current chain
        @param _networkID The network ID of the current chain
     */
    function initialize(
        address _callServiceAddress,
        string memory _networkID
    ) public initializer {
        callSvc = _callServiceAddress;
        networkID = _networkID;
        callSvcBtpAddr = ICallService(callSvc).getBtpAddress();
    }

    function compareTo(
        string memory _base,
        string memory _value
    ) internal pure returns (bool) {
        if (keccak256(abi.encodePacked(_base)) == keccak256(abi.encodePacked(_value))) {
            return true;
        }

        return false;
    }

    function _processXCallRollback(bytes memory _data) internal virtual {
        emit RollbackDataReceived(callSvcBtpAddr, _data);
        revert("NFTProxy: method not supported");
    }

    function _processXCallMethod(
        string calldata _from,
        bytes memory _data
    ) internal virtual {
        emit MessageReceived(_from, _data);
        revert("NFTProxy: method not supported");
    }

    function _processXCallMessage(
        string calldata _from,
        bytes calldata _data
    ) internal {
        if (compareTo(_from, callSvcBtpAddr)) {
            (uint256 rbid, bytes memory encodedRb) = abi.decode(_data, (uint256, bytes));
            RollbackData memory storedRb = rollbacks[rbid];

            require(compareTo(string(encodedRb), string(storedRb.rollbackData)), "NFTProxy: rollback data mismatch");

            _processXCallRollback(encodedRb);

            delete rollbacks[rbid];
            return;
        }

        _processXCallMethod(_from, _data);
    }


    /**
        @notice Sends XCall message to destination chain.
        @param _to The destination BTP address
        @param _data The data needed to be sent
        @param _rollback The rollback data needed to be sent back in case of failure
     */
    function _sendXCallMessage(
        string memory _to,
        bytes memory _data,
        bytes memory _rollback
    ) internal {
        if (_rollback.length > 0) {
            uint fee = getXCallFee(_to, true);
            require(msg.value >= fee, "NFTProxy: insufficient fee");

            uint256 id = ++lastRollbackId;
            bytes memory encodedRd = abi.encode(id, _rollback);

            uint256 sn = ICallService(callSvc).sendCallMessage{value:msg.value}(
                _to,
                _data,
                encodedRd
            );

            rollbacks[id] = RollbackData(id, _rollback, sn);

            emit MessageSent(msg.sender, sn, _data);
        } else {
            uint fee = getXCallFee(_to, false);
            require(msg.value >= fee, "NFTProxy: insufficient fee");

            uint256 sn = ICallService(callSvc).sendCallMessage{value:msg.value}(
                _to,
                _data,
                _rollback
            );

            emit MessageSent(msg.sender, sn, _data);
        }
    }

    /**
        @notice Used for unit testing.
        @dev Only callable from the owner.
        @param _data The mock calldata delivered from the test suite
        (supposed to be as close as handleCallMessage input)
     */
    function testXCall(
        string calldata _from,
        bytes calldata _data
    ) public onlyOwner {
        _processXCallMessage(_from, _data);
    }

    /**
        @notice Handles the call message received from the source chain.
        @dev Only called from the Call Message Service.
        @param _from The BTP address of the caller on the source chain
        @param _data The calldata delivered from the caller
     */
    function handleCallMessage(
        string calldata _from,
        bytes calldata _data
    ) external override onlyCallService {
        _processXCallMessage(_from, _data);
    }

    function getXCallFee(
        string memory _to,
        bool _useCallback
    ) public view returns (uint) {
        string memory destinationNetworkID = BTPAddress.networkAddress(_to);
        return IFeeManage(callSvc).getFee(destinationNetworkID, _useCallback);
    }

    function setCallServiceAdress(
        address _callServiceAddress
    ) public onlyOwner {
        callSvc = _callServiceAddress;
        callSvcBtpAddr = ICallService(callSvc).getBtpAddress();
    }
}
