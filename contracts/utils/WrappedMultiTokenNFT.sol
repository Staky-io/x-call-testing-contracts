// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.5;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract WrappedMultiTokenNFT is ERC1155, ERC1155Burnable {
    bool private initialized;
    address public owner;

    constructor(string memory _uri) ERC1155(_uri) {}

    modifier onlyOwner() {
        require(msg.sender == owner, "WrappedMultiTokenNFT: caller is not the owner");
        _;
    }

    function init(string calldata _uri) public {
        require(initialized == false, "Already initialized");

        owner = msg.sender;
        _setURI(_uri);

        initialized = true;
    }

    function setURI(
        string memory newuri
    ) public onlyOwner {
        _setURI(newuri);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }
}