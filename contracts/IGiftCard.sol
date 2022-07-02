// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IGiftCard is IERC721 {
    function mintCard(
        address to,
        uint256 balance,
        string calldata encryptedCode,
        string calldata hashedCode
    ) external returns (uint256);

    function wasCardMinted(string calldata hashedCode)
        external
        view
        returns (bool);

    function getBalance(uint256 tokenId) external view returns (uint256);

    function getClaimCode(uint256 tokenId) external returns (string memory);

    function getSeller(uint256 tokenId) external view returns (address);

    function isCodeApplied(uint256 tokenId) external view returns (bool);
}
