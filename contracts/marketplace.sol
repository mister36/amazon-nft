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

    IERC20 private USDC;
    IGiftCard private Card;
    // mumbai testnet USDC = 0xe11A86849d99F524cAC3E7A0Ec1241828e332C62

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        uint256 balance;
        bool active;
    }

    // mapping of token id => listing struct
    mapping(uint256 => Listing) private _listings;

    // mapping of token id => stake amount
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
    event Delist(address, uint256); // seller, token id

    constructor(IERC20 _USDC, IGiftCard _Card) {
        USDC = _USDC;
        Card = _Card;
    }

    function listCard(
        uint256 tokenId,
        uint256 price,
        uint256 stake
    ) external returns (Listing memory) {
        uint256 balance = Card.getBalance(tokenId);
        require(
            price <= balance,
            "Price must be equal to / lower than balance"
        );
        require(
            stake >= price / 3,
            "Stake value must be at least 1/3 of price"
        );
        require(msg.sender == Card.ownerOf(tokenId), "Card isn't yours");
        require(
            Card.isCodeApplied(tokenId) == false,
            "Claim code already applied"
        );

        // takes stake and escrows gift card
        USDC.transferFrom(msg.sender, address(this), stake);
        Card.transferFrom(msg.sender, address(this), tokenId);

        _stakes[tokenId] += stake;

        Listing memory listing = Listing(
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

        USDC.transferFrom(address(this), msg.sender, _stakes[tokenId]);
        Card.transferFrom(address(this), msg.sender, tokenId);

        delete _stakes[tokenId];
        emit Delist(msg.sender, tokenId);
    }

    function updatePrice(
        uint256 tokenId,
        uint256 newPrice,
        uint256 additionalStake
    ) external onlySeller(_listings[tokenId].seller) {
        Listing storage listing = _listings[tokenId];

        uint256 diffFromStake = additionalStake +
            _stakes[tokenId] -
            (newPrice / 3);

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

        USDC.transferFrom(msg.sender, address(this), additionalStake);

        listing.price = newPrice;
        _stakes[tokenId] += additionalStake;
    }

    function buyCard(uint256 tokenId) external {
        Listing storage listing = _listings[tokenId];
        require(msg.sender != listing.seller, "Cannot buy your own listing");

        USDC.transferFrom(msg.sender, listing.seller, listing.price);
        Card.transferFrom(address(this), msg.sender, tokenId);

        _soldBlockNumbers[tokenId] = block.number;
        listing.active = false;

        emit Sale(listing.seller, msg.sender, tokenId, listing.price);
    }

    function verifyCard(
        bool codeWorks,
        uint256 tokenId,
        uint256 priceDiff
    ) external onlyTokenExists(tokenId) {
        Listing memory listing = _listings[tokenId];
        address seller = listing.seller;

        require(
            Card.isCodeApplied(tokenId) == true,
            "Code was not applied yet"
        );
        require(
            priceDiff < Card.getBalance(tokenId),
            "Balance of zero or below not possible"
        );
        require(
            msg.sender == listing.seller || msg.sender == Card.ownerOf(tokenId),
            "Must be the buyer or seller"
        );

        if (msg.sender == listing.seller) {
            require(
                block.number - _soldBlockNumbers[tokenId] >= 20,
                "Must wait approx. 5 min to verify your own card"
            );

            USDC.transferFrom(
                address(this),
                msg.sender,
                listing.price + _stakes[tokenId]
            );
        } else {
            if (codeWorks && priceDiff == 0) {
                USDC.transferFrom(
                    address(this),
                    msg.sender,
                    listing.price + _stakes[tokenId]
                );
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

                USDC.transferFrom(address(this), seller, payment);
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
