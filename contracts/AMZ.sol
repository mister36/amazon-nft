// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GiftCard is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping of token id => card balance
    mapping(uint256 => uint256) private _balances;

    // mapping of token id => claim code
    mapping(uint256 => string) private _codes;

    // mapping of token id => whether code was applied
    mapping(uint256 => bool) private _codesApplied;

    // mapping of claim code => whether claim code has been minted
    mapping(string => bool) private _claimCodeMinted;

    // mapping of tokenId => original minter
    mapping(uint256 => address) private _minters;

    constructor() ERC721("Amazon Gift Card", "AMZ-GFT") {}

    function mintCard(
        address to,
        uint256 balance,
        string calldata claimCode
    ) external returns (uint256) {
        require(_claimCodeMinted[claimCode] == false, "Code already exists");
        require(balance > 0, "Balance must be postive");
        // TODO: Implement check for amazon code format (regex)
        uint256 newId = _tokenIds.current();
        _mint(to, newId);

        _balances[newId] = balance;
        _codes[newId] = claimCode;
        _claimCodeMinted[claimCode] = true;
        _minters[newId] = msg.sender;

        _tokenIds.increment();

        return newId;
    }

    // potential minter can check so they don't waste gas minting
    function wasCardMinted(string calldata claimCode)
        external
        view
        returns (bool)
    {
        return _claimCodeMinted[claimCode];
    }

    function getBalance(uint256 tokenId) external view returns (uint256) {
        return _balances[tokenId];
    }

    function getClaimCode(uint256 tokenId) external returns (string memory) {
        require(_exists(tokenId), "Token doesn't exist");
        require(msg.sender == ownerOf(tokenId), "!owner");
        if (_minters[tokenId] != ownerOf(tokenId) && !_codesApplied[tokenId]) {
            // ensures that if token was sold and new owner views code,
            // contract marks gift card as applied
            _codesApplied[tokenId] = true;
        }
        return _codes[tokenId];
    }

    function getOriginalMinter(uint256 tokenId)
        external
        view
        returns (address)
    {
        return _minters[tokenId];
    }

    function isCodeApplied(uint256 tokenId) external view returns (bool) {
        return _codesApplied[tokenId];
    }
}
