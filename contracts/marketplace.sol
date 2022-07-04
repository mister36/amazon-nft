// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IGiftCard.sol";
import "./HitchensUnorderedKeySet.sol";
import "./math.sol";

contract Marketplace {
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    using DSMath for uint256;

    HitchensUnorderedKeySetLib.Set private _listingKeys;

    IERC20 private immutable USDC;
    IGiftCard private immutable Card;
    // mumbai testnet USDC = 0xe11A86849d99F524cAC3E7A0Ec1241828e332C62

    struct Listing {
        address seller;
        string hashedCode;
        uint256 price;
        uint256 balance;
        bool active;
        address lastBidder;
    }

    // mapping of hashed code => listing struct
    mapping(string => Listing) private _listings;

    // mapping of hashed claim code => stake amount
    mapping(string => uint256) private _stakes;

    // mapping of hashed claim code => block number when card was sold
    mapping(string => uint256) private _soldBlockNumbers;

    modifier onlyTokenExists(string calldata hashedCode) {
        require(
            _listingKeys.exists(bytes32(bytes(hashedCode))),
            "Listing doesn't exist"
        );
        _;
    }

    modifier onlySeller(address seller) {
        require(msg.sender == seller, "!seller");
        _;
    }

    event Sale(address, address, uint256); // seller, buyer, price
    event Listed(address, uint256); // seller, price
    event PriceUpdate(address, uint256); // seller, new price
    event BuyRequest(address, string); // buyer, hashed claim code
    event Verified(address, address, int256, string); // seller, buyer, price, hashcode
    event Delist(address); // seller

    constructor(IERC20 _USDC, IGiftCard _Card) {
        USDC = _USDC;
        Card = _Card;
    }

    function listCard(
        string calldata hashedCode,
        uint256 price,
        uint256 balance,
        uint256 stake
    ) external returns (Listing memory) {
        require(
            price <= balance,
            "Price must be equal to / lower than balance"
        );
        require(
            stake >= price / 3,
            "Stake value must be at least 1/3 of price"
        );
        require(
            Card.wasCardMinted(hashedCode) == false,
            "Claim code already minted"
        );

        // takes stake and escrows gift card
        USDC.transferFrom(msg.sender, address(this), stake);

        _stakes[hashedCode] += stake;

        Listing memory listing = Listing(
            msg.sender,
            hashedCode,
            price,
            balance,
            true,
            address(0)
        );
        _listings[hashedCode] = listing;
        _listingKeys.insert(bytes32(bytes(hashedCode)));

        emit Listed(msg.sender, price);
        return listing;
    }

    function removeCard(string calldata hashedCode)
        external
        onlySeller(_listings[hashedCode].seller)
    {
        Listing memory listing = _listings[hashedCode];
        require(listing.active, "Listing not active");

        delete _listings[hashedCode];
        _listingKeys.remove(bytes32(bytes(hashedCode)));

        USDC.transfer(msg.sender, _stakes[hashedCode]);

        delete _stakes[hashedCode];
        emit Delist(msg.sender);
    }

    function updatePrice(
        string calldata hashedCode,
        uint256 newPrice,
        uint256 additionalStake
    ) external onlySeller(_listings[hashedCode].seller) {
        Listing storage listing = _listings[hashedCode];

        int256 diffFromStake = int256(additionalStake + _stakes[hashedCode]) -
            int256(newPrice / 3);

        require(listing.active, "Listing not active");
        require(
            newPrice <= listing.balance,
            "Price must be equal to / lower than balance"
        );

        if (diffFromStake < 0) {
            string memory diffFromStakeError = string.concat(
                "Stake to add: ",
                Strings.toString(uint256(-diffFromStake))
            );
            revert(diffFromStakeError);
        }

        USDC.transferFrom(msg.sender, address(this), additionalStake);

        listing.price = newPrice;
        _stakes[hashedCode] += additionalStake;

        emit PriceUpdate(msg.sender, newPrice);
    }

    function sendBuyRequest(string calldata hashedCode) external {
        Listing storage listing = _listings[hashedCode];
        require(msg.sender != listing.seller, "Cannot buy your own listing");
        require(listing.active, "Listing is not active");

        // make the last bidder
        listing.lastBidder = msg.sender;

        emit BuyRequest(msg.sender, hashedCode);
    }

    function acceptBuyRequest(
        string calldata encryptedCode,
        string calldata hashedCode
    ) external onlySeller(_listings[hashedCode].seller) {
        Listing storage listing = _listings[hashedCode];
        require(listing.lastBidder != address(0), "No bids on listing");

        USDC.transferFrom(listing.lastBidder, address(this), listing.price);

        // mints gift card to buyer
        Card.mintCard(
            listing.lastBidder,
            listing.balance,
            encryptedCode,
            hashedCode
        );

        _soldBlockNumbers[hashedCode] = block.number;
        listing.active = false;

        emit Sale(msg.sender, listing.lastBidder, listing.price);
    }

    function verifyCard(
        bool codeWorks,
        string calldata hashedCode,
        uint256 priceDiff
    ) external onlyTokenExists(hashedCode) {
        Listing memory listing = _listings[hashedCode];
        address seller = listing.seller;

        require(
            Card.isCodeApplied(hashedCode) == true,
            "Code was not applied yet"
        );
        require(
            priceDiff < Card.getBalance(hashedCode),
            "Balance of zero or below not possible"
        );
        require(
            msg.sender == listing.seller ||
                msg.sender == Card.getBuyer(hashedCode),
            "Must be the buyer or seller"
        );

        if (msg.sender == listing.seller) {
            require(
                block.number - _soldBlockNumbers[hashedCode] >= 20,
                "Must wait approx. 5 min to verify your own card"
            ); // TODO: Will have to adjust "20" since polygon has shorter block time

            USDC.transfer(msg.sender, listing.price + _stakes[hashedCode]);

            emit Verified(
                msg.sender,
                listing.lastBidder,
                int256(listing.price),
                hashedCode
            ); // seller, buyer, price, hashcode
        } else {
            if (codeWorks && priceDiff == 0) {
                USDC.transfer(
                    listing.seller,
                    listing.price + _stakes[hashedCode]
                );
                emit Verified(
                    listing.seller,
                    listing.lastBidder,
                    int256(listing.price),
                    hashedCode
                );
            } else if (codeWorks && priceDiff > 0) {
                int256 truePrice = int256(listing.price) - int256(priceDiff);

                /*
                Without check, could be possible that .transfer(value)
                would contain a negative value. E.g, if a card had a balance
                of $100 and sold for $10, but the true value was $10,
                then listing.price - priceDiff = $-90. Seller should be 
                sent no money in this case.
               */
                if (truePrice > 0) {
                    USDC.transfer(seller, uint256(truePrice)); // no stake
                }
                emit Verified(
                    listing.seller,
                    listing.lastBidder,
                    truePrice,
                    hashedCode
                );
            } else {
                // if !codeWorks, seller doesn't get stake or buyer money
                emit Verified(
                    listing.seller,
                    listing.lastBidder,
                    0,
                    hashedCode
                );
            }
        }

        delete _stakes[hashedCode];
        delete _listings[hashedCode];
        _listingKeys.remove(bytes32(bytes(hashedCode)));
    }

    function getListing(string calldata hashedCode)
        external
        view
        onlyTokenExists(hashedCode)
        returns (Listing memory)
    {
        return _listings[hashedCode];
    }

    function getAllListings() external view returns (bytes32[] memory) {
        return _listingKeys.keyList;
    }
}
