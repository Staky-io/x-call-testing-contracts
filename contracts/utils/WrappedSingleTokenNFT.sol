// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.5;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract WrappedSingleTokenNFT is ERC721, ERC721Burnable {
    address public owner;
    bool private initialized;
    string private baseURI;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

     modifier onlyOwner() {
        require(msg.sender == owner, "WrappedMultiTokenNFT: caller is not the owner");
        _;
    }

    function init(string calldata _uri) public {
        require(initialized == false, "Already initialized");

        owner = msg.sender;
        setBaseURI(_uri);

        initialized = true;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(
        string memory _uri
    ) public onlyOwner {
        baseURI = _uri;
    }

    function mint(
        address _to,
        uint256 _id
    ) public onlyOwner {
        _safeMint(_to, _id);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _tokenId,
        uint256 _batchSize
    ) internal override(ERC721) {
        super._beforeTokenTransfer(_from, _to, _tokenId, _batchSize);
    }
}