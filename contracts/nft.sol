// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./stringUtils.sol";

contract GiftCard is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping of token id => card balance
    mapping(uint256 => uint256) public balances;

    // mapping of token id => claim code
    mapping(uint256 => string) private _codes;

    // mapping of token id => whether code was applied
    mapping(uint256 => bool) public codesApplied;

    // mapping of claim code => whether claim code has been minted
    mapping(string => bool) public claimCodeMinted;

    constructor() ERC721("Amazon Gift Card", "AMZ-GFT") {}

    modifier onlyTokenOwner(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId), "!owner");
        _;
    }

    modifier onlyPositiveBalance(uint256 balance) {
        require(balance > 0, "Balance must be postive");
        _;
    }

    function mintCard(
        address to,
        uint256 balance,
        string calldata claimCode
    ) external onlyPositiveBalance(balance) returns (uint256) {
        require(claimCodeMinted[claimCode] == false, "Code already exists");
        // TODO: Implement check for amazon code format (regex)
        uint256 newId = _tokenIds.current();
        _mint(to, newId);

        balances[newId] = balance;
        _codes[newId] = claimCode;
        codesApplied[newId] = false;
        claimCodeMinted[claimCode] = true;

        _tokenIds.increment();

        return newId;
    }

    function getBalance(uint256 tokenId) external view returns (uint256) {
        return balances[tokenId];
    }

    function getClaimCode(uint256 tokenId)
        external
        view
        onlyTokenOwner(tokenId)
        returns (string memory)
    {
        return _codes[tokenId];
    }

    function changeBalance(uint256 newBalance, uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        onlyPositiveBalance(newBalance)
        returns (uint256)
    {
        balances[tokenId] = newBalance;
        return newBalance;
    }
}
