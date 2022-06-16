// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "./IGiftCard.sol";
import "./HitchensUnorderedKeySet.sol";

contract Marketplace {
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    HitchensUnorderedKeySetLib.Set private _listingKeys;

    struct Listing {
        address tokenAddress;
        address seller;
        uint256 tokenId;
        uint256 price; // in wei
        bool active;
    }

    // mapping of token id => listing struct
    mapping(uint256 => Listing) private _listings;

    // mapping of token id => stake amount
    mapping(uint256 => uint256) private _stakes;

    // mapping of token id => block number when card was sold
    mapping(uint256 => uint256) private _soldBlockNumbers;

    event Sale(address, address, uint256, uint256); // seller, buyer, token id, price
    event Listed(address, uint256, uint256); // seller, token id, price

    // TODO: Add "delete listing" event

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
            msg.value >= price / 3,
            "Stake value must be at least 1/3 of price"
        );
        require(msg.sender == card.ownerOf(tokenId), "Card isn't yours");
        require(
            card.isCodeApplied(tokenId) == false,
            "Claim code already applied"
        );

        _stakes[tokenId] += msg.value;

        Listing memory listing = Listing(
            tokenAddress,
            msg.sender,
            tokenId,
            price,
            true
        );
        _listings[tokenId] = listing;
        _listingKeys.insert(bytes32(tokenId));

        emit Listed(msg.sender, tokenId, price);
        return listing;
    }

    function buyCard(uint256 tokenId) external payable {
        Listing storage listing = _listings[tokenId];
        require(msg.sender != listing.seller, "Cannot buy your own listing");
        require(msg.value >= listing.price, "Insufficient funds");

        /* TODO: Check to see if seller still owns the card
        (might have sold it outside of marketplace). If they don't,
        delete the listing
        */

        IGiftCard(listing.tokenAddress).transferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );

        _soldBlockNumbers[tokenId] = block.number;
        listing.active = false;

        emit Sale(listing.seller, msg.sender, tokenId, msg.value);
    }

    function verifyCard(
        bool codeWorks,
        uint256 tokenId,
        uint256 priceDiff,
        address tokenAddress
    ) external {
        IGiftCard card = IGiftCard(tokenAddress);
        Listing memory listing = _listings[tokenId];
        address seller = listing.seller;

        require(
            card.isCodeApplied(tokenId) == true,
            "Code was not applied yet"
        );
        require(
            priceDiff < card.getBalance(tokenId),
            "Balance of zero or below not possible"
        );
        require(
            _listingKeys.exists(bytes32(tokenId)),
            "Listing does not exist"
        );
        require(
            msg.sender == listing.seller || msg.sender == card.ownerOf(tokenId),
            "Must be the owner or seller"
        );

        if (msg.sender == listing.seller) {
            require(
                block.number - _soldBlockNumbers[tokenId] >= 20,
                "Must wait approx. 5 min to verify your own card"
            );

            payable(msg.sender).transfer(listing.price + _stakes[tokenId]);
        } else {
            if (codeWorks && priceDiff == 0) {
                payable(seller).transfer(listing.price + _stakes[tokenId]);
            } else if (codeWorks && priceDiff > 0) {
                uint256 payment = 0;
                uint256 trueBalance = listing.price - priceDiff;

                /*
                Without check, could be possible that .transfer(value)
                would contain a negative value. E.g, if a card had a balance
                of $100 and sold for $10, but the true value was $10,
                then listing.price - priceDiff = $-90. Seller should be 
                sent no money in this case.
               */
                if (trueBalance > 0) payment = trueBalance;

                payable(seller).transfer(payment);
            }
            // if !codeWorks, seller doesn't get stake or buyer money
        }

        delete _stakes[tokenId];
        delete _listings[tokenId];
        _listingKeys.remove(bytes32(tokenId));
    }

    function getListing(uint256 tokenId)
        external
        view
        returns (Listing memory)
    {
        require(_listingKeys.exists(bytes32(tokenId)), "Listing doesn't exist");
        return _listings[tokenId];
    }

    function getAllListings() external view returns (bytes32[] memory) {
        return _listingKeys.keyList;
    }
}
