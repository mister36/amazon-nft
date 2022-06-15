// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GiftCard is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping of token id => balance
    mapping(uint256 => uint256) public balances;

    // mapping of token id => claim code
    mapping(uint256 => string) private _codes;

    // mapping of token id => whether code was applied
    mapping(uint256 => bool) private codesApplied;

    // bool codeApplied;

    constructor() ERC721("Amazon Gift Card", "AMZ-GFT") {}

    // TODO: must store balance and claim code, but claim code only visible to owner
    function mintCard(
        address to,
        uint256 balance,
        string calldata claimCode
    ) external returns (uint256) {
        require(balance > 0, "Balance must be postive");
        // TODO: Implement check for amazon code format (regex)
        uint256 newId = _tokenIds.current();
        _mint(to, newId);

        balances[newId] = balance;
        _codes[newId] = claimCode;
        codesApplied[newId] = false;

        _tokenIds.increment();

        return newId;
    }
}
