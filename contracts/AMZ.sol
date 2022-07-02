// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IGiftCard.sol";

contract GiftCard is ERC721, IGiftCard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping of token id => card balance
    mapping(uint256 => uint256) private _balances;

    // mapping of token id => encrypted claim code
    mapping(uint256 => string) private _codes;

    // mapping of token id => sha-256 hashed claim code
    mapping(uint256 => string) private _hashes;

    // mapping of token id => whether code was applied
    mapping(uint256 => bool) private _codesApplied;

    // mapping of hashed claim code => whether hashed claim code has been minted
    mapping(string => bool) private _codeMinted;

    // mapping of tokenId => seller
    mapping(uint256 => address) private _sellers;

    constructor() ERC721("Amazon Gift Card", "AMZ-GFT") {}

    function mintCard(
        address to,
        uint256 balance,
        string calldata encryptedCode,
        string calldata hashedCode
    ) external returns (uint256) {
        require(_codeMinted[hashedCode] == false, "Code already exists");
        require(balance > 0, "Balance must be postive");
        uint256 newId = _tokenIds.current();
        _mint(to, newId);

        _balances[newId] = balance;
        _codes[newId] = encryptedCode;
        _hashes[newId] = hashedCode;
        _codeMinted[hashedCode] = true;
        _sellers[newId] = msg.sender;

        _tokenIds.increment();

        return newId;
    }

    // potential minter can check so they don't waste gas minting
    function wasCardMinted(string calldata hashedCode)
        external
        view
        returns (bool)
    {
        return _codeMinted[hashedCode];
    }

    function getBalance(uint256 tokenId) external view returns (uint256) {
        return _balances[tokenId];
    }

    function getClaimCode(uint256 tokenId) external returns (string memory) {
        require(_exists(tokenId), "Token doesn't exist");
        require(msg.sender == ownerOf(tokenId), "!owner");
        if (!_codesApplied[tokenId]) {
            _codesApplied[tokenId] = true;
        }
        return _codes[tokenId];
    }

    function getSeller(uint256 tokenId) external view returns (address) {
        return _sellers[tokenId];
    }

    function isCodeApplied(uint256 tokenId) external view returns (bool) {
        return _codesApplied[tokenId];
    }
}
