// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./IGiftCard.sol";

contract GiftCard is ERC721, IGiftCard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct Pair {
        address buyer;
        address seller;
    }

    // mapping of hashed code => card balance
    mapping(string => uint256) private _balances;

    // mapping of hashed code => encrypted claim code
    mapping(string => string) private _codes;

    // mapping of sha-256 hashed claim code => token id
    mapping(string => uint256) private _ids;

    // mapping of hashed code => whether code was applied
    mapping(string => bool) private _codesApplied;

    // mapping of hashed claim code => whether hashed claim code has been minted
    mapping(string => bool) private _codeMinted;

    // mapping of hashed code => pair of buyer/seller
    mapping(string => Pair) private _pairs;

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

        _balances[hashedCode] = balance;
        _codes[hashedCode] = encryptedCode;
        _ids[hashedCode] = newId;
        _codeMinted[hashedCode] = true;
        _pairs[hashedCode] = Pair(to, msg.sender);

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

    function getBalance(string calldata hashedCode)
        external
        view
        returns (uint256)
    {
        return _balances[hashedCode];
    }

    function getClaimCode(string calldata hashedCode)
        external
        returns (string memory)
    {
        uint256 tokenId = _ids[hashedCode];
        require(_exists(tokenId), "Token doesn't exist");
        require(msg.sender == ownerOf(tokenId), "!owner");
        if (!_codesApplied[hashedCode]) {
            _codesApplied[hashedCode] = true;
        }
        return _codes[hashedCode];
    }

    function getSeller(string calldata hashedCode)
        external
        view
        returns (address)
    {
        return _pairs[hashedCode].seller;
    }

    function getBuyer(string calldata hashedCode)
        external
        view
        returns (address)
    {
        return _pairs[hashedCode].buyer;
    }

    function isCodeApplied(string calldata hashedCode)
        external
        view
        returns (bool)
    {
        return _codesApplied[hashedCode];
    }
}
