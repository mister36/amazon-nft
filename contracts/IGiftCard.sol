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

    function getBalance(string calldata hashedCode)
        external
        view
        returns (uint256);

    function getClaimCode(string calldata hashedCode)
        external
        returns (string memory);

    function getSeller(string calldata hashedCode)
        external
        view
        returns (address);

    function getBuyer(string calldata hashedCode)
        external
        view
        returns (address);

    function isCodeApplied(string calldata hashedCode)
        external
        view
        returns (bool);
}
