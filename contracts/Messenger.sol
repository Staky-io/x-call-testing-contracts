// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./xcall/libraries/BTPAddress.sol";
import "./xcall/libraries/ParseAddress.sol";
import "./xcall/interfaces/ICallService.sol";
import "./utils/XCallBase.sol";

contract Messenger is XCallBase {
    uint256 private lastRollbackId;

    mapping(uint256 => RollbackData) private rollbacks;

    mapping(string => bool) private authorizedMessengers; // Authorized messenger contracts on other chains
    mapping(string => string) public messengersNID; // networkID => Messenger BTP Address

    mapping(string => string) public receivedMessages; // received messageID => message
    mapping(string => string) public sentMessages; // sent messageID => message
    mapping(address => uint) public sentMessagesCount; // user => count

    event TextMessageReceived(string indexed _from, string indexed _messageID);
    event TextMessageSent(address indexed _from, string indexed _messageID);

    /**
        @param _callServiceAddress Address of x-call service on the current chain
        @param _networkID The network ID of the current chain
     */

    constructor(
        address _callServiceAddress,
        string memory _networkID
    ) {
        initialize(
            _callServiceAddress,
            _networkID
        );
    }

    // public functions

    function sendMessage(
        string memory _to, // address of the recipient (BTP address of Messenger contract on the other chain)
        string memory _message // message to send
    ) public payable {
        uint fee = getXCallFee(_to, true);

        require(msg.value >= fee, "Messenger: insufficient fee");
        require(authorizedMessengers[_to] == true, "Messenger: no bridge found for this network");

        string memory messageId = string(
            abi.encodePacked(
                networkID,
                ".",
                abi.encodePacked(msg.sender),
                ".",
                Strings.toString(sentMessagesCount[msg.sender])
            )
        );

        bytes memory payload = abi.encode("SEND_TEXT_MESSAGE", abi.encode(messageId, _message));
        bytes memory rollbackData = abi.encode("ROLLBACK_TEXT_MESSAGE", abi.encode(messageId));

        _sendXCallMessage(_to, payload, rollbackData);

        sentMessages[messageId] = _message;
        sentMessagesCount[msg.sender]++;

        emit TextMessageSent(msg.sender, messageId);
    }

    function sendArbitraryCall(
        string memory _to,
        bytes memory _data
    ) public payable {
        uint fee = getXCallFee(_to, true);

        string memory destinationNetworkID = BTPAddress.networkAddress(_to);
        string memory messengerAddress = messengersNID[destinationNetworkID];

        require(msg.value >= fee, "Messenger: insufficient fee");

        bytes memory payload = abi.encode("ARBITRARY_CALL", abi.encode(_to, _data));

        _sendXCallMessage(messengerAddress, payload, "");
    }

    // internal functions

    function _processTextMessage(
        string memory _from,
        bytes memory _data
    ) internal {
        (string memory messageID, string memory message) = abi.decode(_data, (string, string));

        receivedMessages[messageID] = message;

        emit TextMessageReceived(_from, messageID);
    }

    function _processArbitraryCall(
        bytes memory _data
    ) internal {
        (string memory destBTP, bytes memory data) = abi.decode(_data, (string, bytes));

        (, string memory destString) = BTPAddress.parseBTPAddress(destBTP);
        address to = ParseAddress.parseAddress(destString, '');
        (bool success, ) = to.call(data);

        require(success, "Messenger: arbitrary call failed");
    }

    function _rollbackTextMessage(
        bytes memory _data
    ) internal {
        string memory messageID = abi.decode(_data, (string));
        delete sentMessages[messageID];
    }

    // X-Call handlers

    function _processXCallRollback(
        bytes memory _data
    ) internal override {
        (string memory method, bytes memory data) = abi.decode(_data, (string, bytes));

        if (compareTo(method, "ROLLBACK_TEXT_MESSAGE")) {
            _rollbackTextMessage(data);
        } else {
            revert("NFTProxy: method not supported");
        }

        emit RollbackDataReceived(callSvcBtpAddr, _data);
    }

    function _processXCallMethod(
        string calldata _from,
        bytes memory _data
    ) internal override {
        (string memory method, bytes memory data) = abi.decode(_data, (string, bytes));

        require(authorizedMessengers[_from] == true, "Messenger: only authorized messengers can call this method");

        if (compareTo(method, "SEND_TEXT_MESSAGE")) {
            _processTextMessage(_from, data);
        } else if (compareTo(method, "ARBITRARY_CALL")) {
            _processArbitraryCall(data);
        } else {
            revert("NFTProxy: method not supported");
        }

        emit MessageReceived(_from, _data);
    }

    // Admin functions

    function authorizeMessenger(
        string memory _BTPaddress
    ) public onlyOwner {
        authorizedMessengers[_BTPaddress] = true;
        string memory nid = BTPAddress.networkAddress(_BTPaddress);
        messengersNID[nid] = _BTPaddress;
    }

    function revokeMessenger(
        string memory _BTPaddress
    ) public onlyOwner {
        authorizedMessengers[_BTPaddress] = false;
        string memory nid = BTPAddress.networkAddress(_BTPaddress);
        delete messengersNID[nid];
    }
}
