// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./IGiftCard.sol";
import "./HitchensUnorderedKeySet.sol";
import "./math.sol";

contract Marketplace {
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    using DSMath for uint256;

    HitchensUnorderedKeySetLib.Set private _listingKeys;

    AggregatorV3Interface private priceFeed =
        AggregatorV3Interface(0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada);

    struct Listing {
        address tokenAddress;
        address seller;
        uint256 tokenId;
        uint256 price; // USD
        uint256 balance; // USD
        bool active;
    }

    // mapping of token id => listing struct
    mapping(uint256 => Listing) private _listings;

    // mapping of token id => stake amount in wei matic
    mapping(uint256 => uint256) private _stakes;

    // mapping of token id => block number when card was sold
    mapping(uint256 => uint256) private _soldBlockNumbers;

    modifier onlyTokenExists(uint256 tokenId) {
        require(_listingKeys.exists(bytes32(tokenId)), "Listing doesn't exist");
        _;
    }

    modifier onlySeller(address seller) {
        require(msg.sender == seller, "Must be the seller");
        _;
    }

    event Sale(address, address, uint256, uint256); // seller, buyer, token id, price
    event Listed(address, uint256, uint256); // seller, token id, price

    function toUSD(uint256 weiMatic) private view returns (uint256) {
        uint256 matic = weiMatic.wdiv(10**18);
        (, int256 price, , , ) = priceFeed.latestRoundData();

        // conversion of price to uint256
        uint256 uPrice;
        price < 0 ? uPrice = uint256(price * -1) : uPrice = uint256(price);

        uPrice = uPrice.wdiv(10**8); // chainlink returns 8 places, 30000000 => .3
        return uPrice.wmul(matic);
    }

    function toWeiMatic(uint256 usd) private view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();

        // conversion of price to uint256
        uint256 uPrice;
        price < 0 ? uPrice = uint256(price * -1) : uPrice = uint256(price);

        uPrice = uPrice.wdiv(10**8); // chainlink returns 8 places, 30000000 => .3
        return usd.wdiv(uPrice);
    }

    function listCard(
        uint256 tokenId,
        uint256 price,
        address tokenAddress
    ) external payable returns (Listing memory) {
        IGiftCard card = IGiftCard(tokenAddress);
        uint256 balance = card.getBalance(tokenId);
        require(
            price <= balance,
            "Price must be equal to / lower than balance"
        );
        require(
            toUSD(msg.value) >= price / 3,
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
            balance,
            true
        );
        _listings[tokenId] = listing;
        _listingKeys.insert(bytes32(tokenId));

        emit Listed(msg.sender, tokenId, price);
        return listing;
    }

    function removeCard(uint256 tokenId)
        external
        onlySeller(_listings[tokenId].seller)
    {
        Listing memory listing = _listings[tokenId];
        require(listing.active, "Listing not active");

        delete _listings[tokenId];
        _listingKeys.remove(bytes32(tokenId));
        payable(msg.sender).transfer(_stakes[tokenId]);
        delete _stakes[tokenId];
    }

    function updatePrice(uint256 tokenId, uint256 newPrice)
        external
        payable
        onlySeller(_listings[tokenId].seller)
    {
        Listing storage listing = _listings[tokenId];
        uint256 diffFromStake = toUSD(
            msg.value + _stakes[tokenId] - (toWeiMatic(newPrice / 3))
        );

        require(listing.active, "Listing not active");
        require(
            newPrice <= listing.balance,
            "Price must be equal to / lower than balance"
        );

        if (diffFromStake > 0) {
            string memory diffFromStakeError = string.concat(
                "Must add",
                Strings.toString(diffFromStake)
            );
            diffFromStakeError = string.concat(
                diffFromStakeError,
                "more to stake"
            );
            revert(diffFromStakeError);
        }

        listing.price = newPrice;
        _stakes[tokenId] += msg.value;
    }

    function buyCard(uint256 tokenId) external payable {
        Listing storage listing = _listings[tokenId];
        require(msg.sender != listing.seller, "Cannot buy your own listing");
        require(toUSD(msg.value) >= listing.price, "Insufficient funds");

        if (IGiftCard(listing.tokenAddress).isCodeApplied(tokenId)) {
            // if card was applied, delete listing, revert call
            delete _listings[tokenId];
            delete _stakes[tokenId];
            _listingKeys.remove(bytes32(tokenId));
            revert("Gift card already applied. Deleting from marketplace...");
        }

        IGiftCard(listing.tokenAddress).transferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );

        _soldBlockNumbers[tokenId] = block.number;
        listing.active = false;

        emit Sale(listing.seller, msg.sender, tokenId, toUSD(msg.value));
    }

    function verifyCard(
        bool codeWorks,
        uint256 tokenId,
        uint256 priceDiff,
        address tokenAddress
    ) external onlyTokenExists(tokenId) {
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
        onlyTokenExists(tokenId)
        returns (Listing memory)
    {
        return _listings[tokenId];
    }

    function getAllListings() external view returns (bytes32[] memory) {
        return _listingKeys.keyList;
    }
}
