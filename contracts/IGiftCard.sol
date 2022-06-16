// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IGiftCard is IERC721 {
    function mintCard(
        address to,
        uint256 balance,
        string calldata claimCode
    ) external returns (uint256);

    function checkIfCardIsMinted(string calldata claimCode)
        external
        view
        returns (bool);

    function getBalance(uint256 tokenId) external view returns (uint256);

    function getClaimCode(uint256 tokenId) external returns (string memory);

    function getOriginalMinter(uint256 tokenId) external view returns (address);

    function isCodeApplied(uint256 tokenId) external view returns (bool);

    function changeBalance(uint256 newBalance, uint256 tokenId)
        external
        returns (uint256);
}
