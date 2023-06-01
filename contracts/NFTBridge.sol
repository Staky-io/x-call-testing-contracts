// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0 <0.8.5;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./xcall/libraries/BTPAddress.sol";
import "./xcall/interfaces/ICallService.sol";
import "./utils/CloneFactory.sol";
import "./utils/XCallBase.sol";
import "./utils/WrappedMultiTokenNFT.sol";
import "./utils/WrappedSingleTokenNFT.sol";

contract NFTBridge is XCallBase, CloneFactory {
    address public wrappedMultiTokenNftAddress;
    address public wrappedSingleTokenNftAddress;

    uint256 private lastRollbackId;

    mapping(uint256 => RollbackData) private rollbacks;

    mapping(string => address) public wrappedTokens; // nativeToken on other chain => wrappedToken on this chain
    mapping(address => string) public nativeTokens; // wrappedToken on this chain => nativeToken on other chain
    mapping(string => bool) public authorizedBridges; // authorized bridges on other chains (BTP Address) => true/false
    mapping(string => string) public bridgesNID; // networkID => Bridge BTP Address

    event TokenMinted(address indexed _token, address indexed _to, uint indexed _id, uint _value);
    event TokenUnlocked(address indexed _token, address indexed _to, uint indexed _id, uint _value);

    /**
        @notice Initializer. Replaces constructor.
        @dev Callable only once by deployer.
        @param _wrappedMultiTokenNftAddress Instance of multi token NFT contract to clone
        @param _wrappedSingleTokenNftAddress Instance of single token NFT contract to clone
        @param _callServiceAddress Address of x-call service on the current chain
        @param _networkID The network ID of the current chain
     */

    constructor(
        address _wrappedMultiTokenNftAddress,
        address _wrappedSingleTokenNftAddress,
        address _callServiceAddress,
        string memory _networkID
    ) {
        wrappedMultiTokenNftAddress = _wrappedMultiTokenNftAddress;
        wrappedSingleTokenNftAddress = _wrappedSingleTokenNftAddress;

        initialize(
            _callServiceAddress,
            _networkID
        );
    }

    // utility functions

    function _isMultiToken(address _inputToken, uint _id) internal view returns(bool) {
        bool isMultiToken;

        try WrappedSingleTokenNFT(_inputToken).ownerOf(_id) returns (address) {
            isMultiToken = false;
        } catch {
            isMultiToken = true;
        }

        return isMultiToken;
    }

    function allowBridgeAddress(string memory _bridgeBTPAddress) public onlyOwner {
        authorizedBridges[_bridgeBTPAddress] = true;
        string memory nid = BTPAddress.networkAddress(_bridgeBTPAddress);
        bridgesNID[nid] = _bridgeBTPAddress;
    }

    function revokeBridgeAddress(string memory _bridgeBTPAddress) public onlyOwner {
        authorizedBridges[_bridgeBTPAddress] = false;
        string memory nid = BTPAddress.networkAddress(_bridgeBTPAddress);
        delete bridgesNID[nid];
    }

    function setWrappedSingleTokenNFTAdress(
        address _wrappedSingleTokenNftAddress
    ) public onlyOwner {
        wrappedSingleTokenNftAddress = _wrappedSingleTokenNftAddress;
    }

    function setWrappedMultiTokenNFTAdress(
        address _wrappedMultiTokenNftAddress
    ) public onlyOwner {
        wrappedMultiTokenNftAddress = _wrappedMultiTokenNftAddress;
    }

    // Create Wrapped NFT functions

    function _getOrCreateMultiTokenNFT(
        string memory _originalToken,
        string memory _uri
    ) internal returns (WrappedMultiTokenNFT) {
        // Create NFT
        if (wrappedTokens[_originalToken] == address(0x0)) {
            address wrappedNFTClone = createClone(wrappedMultiTokenNftAddress);

            WrappedMultiTokenNFT(wrappedNFTClone).setURI(_uri);
            WrappedMultiTokenNFT nftdeploy = WrappedMultiTokenNFT(wrappedNFTClone);

            wrappedTokens[_originalToken] = address(nftdeploy);
            nativeTokens[address(nftdeploy)] = _originalToken;

            return nftdeploy;
        }

        // Return existing NFT
        return WrappedMultiTokenNFT(wrappedTokens[_originalToken]);
    }

    function _getOrCreateSingleTokenNFT(
        string memory _originalToken,
        string memory _uri
    ) internal returns (WrappedSingleTokenNFT) {
        // Create NFT
        if (wrappedTokens[_originalToken] == address(0x0)) {
            address wrappedNFTClone = createClone(wrappedSingleTokenNftAddress);

            WrappedSingleTokenNFT(wrappedNFTClone).setBaseURI(_uri);
            WrappedSingleTokenNFT nftdeploy = WrappedSingleTokenNFT(wrappedNFTClone);

            wrappedTokens[_originalToken] = address(nftdeploy);
            nativeTokens[address(nftdeploy)] = _originalToken;

            return nftdeploy;
        }

        // Return existing NFT
        return WrappedSingleTokenNFT(wrappedTokens[_originalToken]);
    }

    // Unlock NFT functions

    function _unlockToken(bytes memory _data) internal {
        /**
            @notice The data is encoded as follows:
            @param to The destination address on the current chain
            @param inputToken The token address on the current chain
            @param id The token id
            @param value The token value (must be 1 for single token NFTs and greater or equal than 1 for multi token NFTs)
        */

        (address to, address inputToken, uint256 id, uint256 value) = abi.decode(
            _data, (
                address,
                address,
                uint256,
                uint256
            )
        );

        bool isMultiToken = _isMultiToken(inputToken, id);

        if (isMultiToken) {
            require(value >= 1, "NFTProxy: value must be greater or equal than 1 for multi token NFTs");

            WrappedMultiTokenNFT multiNft = WrappedMultiTokenNFT(inputToken);
            uint nftBalance = multiNft.balanceOf(address(this), id);

            require(nftBalance >= value, "NFTProxy: proxy doesn't have enough tokens to unlock");

            multiNft.safeTransferFrom(address(this), to, id, value, "");
            emit TokenUnlocked(inputToken, to, id, value);
        } else {
            require(value == 1, "NFTProxy: value must be 1 for single token NFTs");

            WrappedSingleTokenNFT singleNft = WrappedSingleTokenNFT(inputToken);
            address owner = singleNft.ownerOf(id);

            require(owner == address(this), "NFTProxy: proxy doesn't own this token");

            singleNft.safeTransferFrom(address(this), to, id);
            emit TokenUnlocked(inputToken, to, id, value);
        }
    }

    // Bridge NFT functions

    function _processBridgeNFTFromChain(
        bytes memory _data
    ) internal {
        /**
            @notice The data is encoded as follows:
            @param to The destination address on the current chain
            @param originalToken The original token BTP address on the source chain
            @param id The token id
            @param value The token value (must be 1 for single token NFTs)
            @param uri The token URI
            @param multiToken Whether the token is multi token or not
            (supposed to be as close as handleCallMessage input)
        */

        (address to, string memory originalToken, uint256 id, uint256 value, string memory uri, bool multiToken) = abi.decode(
            _data, (
                address,
                string,
                uint256,
                uint256,
                string,
                bool
            )
        );

        if (multiToken) {
            require(value >= 1, "NFTProxy: value must be greater or equal than 1 for multi token NFTs");
            WrappedMultiTokenNFT nft = _getOrCreateMultiTokenNFT(originalToken, uri);
            nft.mint(to, id, value, "");
            emit TokenMinted(address(nft), to, id, value);
        } else {
            require(value == 1, "NFTProxy: value must be 1 for single token NFTs");
            WrappedSingleTokenNFT nft = _getOrCreateSingleTokenNFT(originalToken, uri);
            nft.mint(to, id);
            emit TokenMinted(address(nft), to, id, value);
        }
    }

    function _bridgeSingleNFTToChain(
        string memory _bridgeAddress,
        string memory _to,
        address _inputToken,
        uint256 _id,
        uint256 _value
    ) internal {
        WrappedSingleTokenNFT tokenERC721 = WrappedSingleTokenNFT(_inputToken);

        address approved = tokenERC721.getApproved(_id);

        require(approved == address(this), "NFTProxy: proxy is not approved to transfer this token");
        require(_value == 1, "NFTProxy: value must be 1 for single token NFTs");

        tokenERC721.safeTransferFrom(msg.sender, address(this), _id);

        string memory uri = tokenERC721.tokenURI(_id);

        if (compareTo(nativeTokens[_inputToken], "")) {
            bytes memory payload = abi.encode("BRIDGE_NFT_FROM_CHAIN", abi.encode(_to, nativeTokens[_inputToken], _id, _value, uri, false));
            bytes memory rollbackData = abi.encode("ROLLBACK_BRIDGE_NFT_FROM_CHAIN", abi.encode(msg.sender, _inputToken, _id, _value));

            _sendXCallMessage(_bridgeAddress, payload, rollbackData);
        } else {
            tokenERC721.burn(_id);

            bytes memory payload = abi.encode("UNLOCK_ORIGINAL_NFT", abi.encode(_to, nativeTokens[_inputToken], _id, _value));
            bytes memory rollbackData = abi.encode("ROLLBACK_UNLOCK_ORIGINAL_NFT", abi.encode(msg.sender, _inputToken, _id, _value, false));

            _sendXCallMessage(_bridgeAddress, payload, rollbackData);
        }
    }

    function _bridgeMultiTokenNFTToChain(
        string memory _bridgeAddress,
        string memory _to,
        address _inputToken,
        uint256 _id,
        uint256 _value
    ) internal {
        WrappedMultiTokenNFT tokenERC1155 = WrappedMultiTokenNFT(_inputToken);

        bool approved = tokenERC1155.isApprovedForAll(msg.sender, address(this));

        require(approved == true, "NFTProxy: proxy is not approved to transfer this token");
        require(_value == 1, "NFTProxy: value must be 1 for single token NFTs");

        tokenERC1155.safeTransferFrom(msg.sender, address(this), _id, _value, "");

        string memory uri = tokenERC1155.uri(_id);

        if (compareTo(nativeTokens[_inputToken], "")) {
            bytes memory payload = abi.encode("BRIDGE_NFT_FROM_CHAIN", abi.encode(_to, nativeTokens[_inputToken], _id, _value, uri, true));
            bytes memory rollbackData = abi.encode("ROLLBACK_BRIDGE_NFT_FROM_CHAIN", abi.encode(msg.sender, _inputToken, _id, _value));

            _sendXCallMessage(_bridgeAddress, payload, rollbackData);
        } else {
            tokenERC1155.burn(address(this), _id, _value);

            bytes memory payload = abi.encode("UNLOCK_ORIGINAL_NFT", abi.encode(_to, nativeTokens[_inputToken], _id, _value));
            bytes memory rollbackData = abi.encode("ROLLBACK_UNLOCK_ORIGINAL_NFT", abi.encode(msg.sender, _inputToken, _id, _value, uri, true));

            _sendXCallMessage(_bridgeAddress, payload, rollbackData);
        }
    }

     /**
        @notice Handles bridge NFT to chain. Callable by everyone.
        @param _to The BTP address of the recipient on the destination chain
        @param _inputToken Address of the input token on the current chain
        @param _id The token id
        @param _value The token amount (must be 1 for single token NFTs, and greater or equal than 1 for multi token NFTs)
     */
    function bridgeNFToChain(
        string memory _to,
        address _inputToken,
        uint256 _id,
        uint256 _value
    ) public payable {
        uint fee = getXCallFee(_to, true);
        string memory destinationNetworkID = BTPAddress.networkAddress(_to);
        string memory bridgeAddress = bridgesNID[destinationNetworkID];

        require(msg.value >= fee, "NFTProxy: insufficient fee");
        require(authorizedBridges[bridgeAddress] == true, "NFTProxy: no bridge found for this network");
        
        // check if inputToken is ERC721 or ERC1155
        bool isMultiToken = _isMultiToken(_inputToken, _id);

        if (isMultiToken) {
            _bridgeMultiTokenNFTToChain(bridgeAddress, _to, _inputToken, _id, _value);
        } else {
            _bridgeSingleNFTToChain(bridgeAddress, _to, _inputToken, _id, _value);
        }
    }

    // X-Call handlers

    function _processXCallRollback(bytes memory _data) internal override {
        (string memory method, bytes memory data) = abi.decode(_data, (string, bytes));

        if (compareTo(method, "ROLLBACK_BRIDGE_NFT_FROM_CHAIN")) {
            _unlockToken(data);
        } else if (compareTo(method, "ROLLBACK_UNLOCK_ORIGINAL_NFT")) {
            _processBridgeNFTFromChain(data);
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

        if (compareTo(method, "BRIDGE_NFT_FROM_CHAIN")) {
            require(authorizedBridges[_from] == true, "NFTProxy: only NFT Bridge can call this function");
            _processBridgeNFTFromChain(data);
        } else if (compareTo(method, "UNLOCK_ORIGINAL_NFT")) {
            require(authorizedBridges[_from] == true, "NFTProxy: only NFT Bridge can call this function");
            _unlockToken(data);
        } else {
            revert("NFTProxy: method not supported");
        }

        emit MessageReceived(_from, _data);
    }
}
