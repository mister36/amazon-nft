// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "./IGiftCard.sol";

contract Marketplace {
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price; // in wei
    }

    // mapping of token id => listing struct
    mapping(uint256 => Listing) private _listings;

    // mapping of seller address => stake amount
    mapping(address => uint256) private _stakes;

    // mapping of token id => block number when it was sold
    mapping(uint256 => uint256) private _soldBlockNumbers;

    event Sale(address, address, uint256, uint256); // seller, buyer, token id, price
    event Listed(address, uint256, uint256); // seller, token id, price

    function listCard(
        uint256 tokenId,
        uint256 price,
        address tokenAddress
    ) external payable returns (Listing memory) {
        IGiftCard card = IGiftCard(tokenAddress);
        require(
            price <= card.getBalance(tokenId),
            "Price must be equal to / lower than balance"
        );
        require(
            msg.value >= price / 4,
            "Stake value must be at least 1/4 of price"
        );
        require(msg.sender == card.ownerOf(tokenId), "Card isn't yours");
        require(
            card.isCodeApplied(tokenId) == false,
            "Claim code already applied"
        );

        _stakes[msg.sender] += msg.value;

        Listing memory listing = Listing(msg.sender, tokenId, price);
        _listings[tokenId] = listing;

        emit Listed(msg.sender, tokenId, price);
        return listing;
    }
}
