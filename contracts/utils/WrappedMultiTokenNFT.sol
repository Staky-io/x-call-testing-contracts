// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.8.5;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract WrappedMultiTokenNFT is ERC1155, Ownable, ERC1155Burnable {
    constructor(string memory _uri) ERC1155(_uri) {}

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