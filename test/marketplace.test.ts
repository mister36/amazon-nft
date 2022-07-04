import { expect, use } from "chai";
import {
  Contract,
  BigNumber,
  constants,
  ContractFactory,
  ethers,
} from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import { encrypt, decrypt } from "./utils";
import sha256 from "crypto-js/sha256";
import Base64 from "crypto-js/enc-base64";

import GiftCard from "../build/GiftCard.json";
import Marketplace from "../build/Marketplace.json";
import MockERC20 from "../build/MockERC20.json";

use(solidity);

describe("Marketplace", async () => {
  const provider = new MockProvider();
  const [wallet, otherWallet, outsiderWallet] = provider.getWallets();

  let card: Contract;
  let marketplace: Contract;
  let usdc: Contract;

  const claimCode = "xyz-sd-23ds";
  const encryptedClaimCode = await encrypt(claimCode, wallet, otherWallet);
  const hashedClaimCode = sha256(claimCode).toString(Base64);
  const balance = 25;
  const blockDifference = 20;

  const setUpListCard = async () => {
    await usdc.mint(wallet.address, 100);
    await usdc.mint(otherWallet.address, 100);
    await usdc.approve(marketplace.address, constants.MaxInt256);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);
  };

  const mineNBlocks = async (n: number, provider: MockProvider) => {
    for (let index = 0; index < n; index++) {
      await provider.send("evm_mine", []);
    }
  };

  beforeEach(async () => {
    const MockCard = new ContractFactory(
      GiftCard.abi,
      GiftCard.bytecode,
      wallet
    );
    const MockUSDC = new ContractFactory(
      MockERC20.abi,
      MockERC20.bytecode,
      wallet
    );

    card = await MockCard.deploy();
    usdc = await MockUSDC.deploy();

    marketplace = await deployContract(wallet, Marketplace, [
      usdc.address,
      card.address,
    ]);

    // await card.mintCard(
    //   otherWallet.address,
    //   balance,
    //   encryptedClaimCode,
    //   hashedClaimCode
    // );
  });

  it("Can't list card since price is higher than card balance", async () => {
    await expect(
      marketplace.listCard(hashedClaimCode, balance + 10, balance, 10)
    ).to.be.revertedWith("Price must be equal to / lower than balance");
  });

  it("Can't list card since stake is less than 1/3 the price", async () => {
    await expect(
      marketplace.listCard(hashedClaimCode, balance, balance, 1)
    ).to.be.revertedWith("Stake value must be at least 1/3 of price");
  });

  it("Can't list card since the code was already minted", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );
    await expect(
      marketplace
        .connect(otherWallet)
        .listCard(hashedClaimCode, balance, balance, 10)
    ).to.be.revertedWith("Claim code already minted");
  });

  it("Can't list card since code was already listed on marketplace", async () => {
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 20);

    await marketplace.listCard(hashedClaimCode, balance, balance, 10);
    await expect(
      marketplace.listCard(hashedClaimCode, balance, balance, 10)
    ).to.be.revertedWith(
      "UnorderedKeySet(101) - Key already exists in the set."
    );
  });

  it("Lists card", async () => {
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 10);

    await expect(marketplace.listCard(hashedClaimCode, balance, balance, 10))
      .to.emit(marketplace, "Listed")
      .withArgs(wallet.address, balance);
  });

  it("Can't remove listing since caller isn't the seller", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 10);

    await marketplace.listCard(hashedClaimCode, balance, balance, 10);

    // attempts to remove
    await expect(
      marketplace.connect(otherWallet).removeCard(0)
    ).to.be.revertedWith("!seller");
  });

  it("Removes listing", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 10);

    await marketplace.listCard(hashedClaimCode, balance, balance, 10);

    // removes
    await expect(marketplace.removeCard(hashedClaimCode))
      .to.emit(marketplace, "Delist")
      .withArgs(wallet.address);
  });

  it("Can't update price since caller isn't the seller", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 10);
    await marketplace.listCard(hashedClaimCode, balance, balance, 10);

    await expect(
      marketplace
        .connect(otherWallet)
        .updatePrice(hashedClaimCode, balance - 1, 0)
    ).to.be.revertedWith("!seller");
  });

  it("Can't update price since new price is higher than the balance", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 10);
    await marketplace.listCard(hashedClaimCode, balance, balance, 10);

    await expect(
      marketplace.updatePrice(hashedClaimCode, balance + 1, 0)
    ).to.be.revertedWith("Price must be equal to / lower than balance");
  });

  it("Can't update price since the stake isn't high enough", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 10);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    await expect(
      marketplace.updatePrice(hashedClaimCode, 51, 0)
    ).to.be.revertedWith("Stake to add: 8");
  });

  it("Updates price", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 50);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    await expect(marketplace.updatePrice(hashedClaimCode, 51, 8))
      .to.emit(marketplace, "PriceUpdate")
      .withArgs(wallet.address, 51);
  });

  it("Won't allow seller to buy it's own listing", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 50);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    await expect(
      marketplace.sendBuyRequest(hashedClaimCode)
    ).to.be.revertedWith("Cannot buy your own listing");
  });

  it("Sends buy request", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 50);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    await expect(
      marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode)
    )
      .to.emit(marketplace, "BuyRequest")
      .withArgs(otherWallet.address, hashedClaimCode);
  });

  it("Can't accept buy request since caller isn't the seller", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 50);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    await expect(
      marketplace
        .connect(otherWallet)
        .acceptBuyRequest(encryptedClaimCode, hashedClaimCode)
    ).to.be.revertedWith("!seller");
  });

  it("Can't accept buy request since there are no bids on listing", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, 50);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    await expect(
      marketplace.acceptBuyRequest(encryptedClaimCode, hashedClaimCode)
    ).to.be.revertedWith("No bids on listing");
  });

  it("Accepts buy request", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.mint(otherWallet.address, 100);
    await usdc.approve(marketplace.address, 9);
    await marketplace.listCard(hashedClaimCode, 25, 100, 9);

    // sends bid/buy request
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);
    await usdc.connect(otherWallet).approve(marketplace.address, 25);

    // accepts bid
    await expect(
      marketplace
        .connect(wallet)
        .acceptBuyRequest(encryptedClaimCode, hashedClaimCode)
    )
      .to.emit(marketplace, "Sale")
      .withArgs(wallet.address, otherWallet.address, 25);
  });

  it("Can't verify card since listing doesn't exist", async () => {
    await expect(
      marketplace.verifyCard(true, hashedClaimCode, 0)
    ).to.be.revertedWith("Listing doesn't exist");
  });

  it("Can't verify card since code wasn't applied", async () => {
    // lists card
    await setUpListCard();

    await expect(
      marketplace.verifyCard(true, hashedClaimCode, 0)
    ).to.be.revertedWith("Code was not applied yet");
  });

  it("Can't verify card since the price difference is impossible", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);
    await usdc.connect(otherWallet).approve(marketplace.address, 25);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    await expect(
      marketplace.verifyCard(true, hashedClaimCode, 100)
    ).to.be.revertedWith("Balance of zero or below not possible");
  });

  it("Can't verify card since caller isn't the buyer or seller", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);
    await usdc.connect(otherWallet).approve(marketplace.address, 25);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    await expect(
      marketplace.connect(outsiderWallet).verifyCard(true, hashedClaimCode, 0)
    ).to.be.revertedWith("Must be the buyer or seller");
  });

  it("Can't verify card since seller didn't wait 5 min", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);
    await usdc.connect(otherWallet).approve(marketplace.address, 25);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    await expect(
      marketplace.verifyCard(true, hashedClaimCode, 0)
    ).to.be.revertedWith("Must wait approx. 5 min to verify your own card");
  });

  it("Allows seller to verify card", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await usdc
      .connect(otherWallet)
      .approve(marketplace.address, constants.MaxInt256);
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // check marketplace balance
    expect(await usdc.balanceOf(marketplace.address)).to.equal(9 + 25);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    // fast forward blockDifference ahead
    await mineNBlocks(blockDifference, provider);

    await expect(marketplace.verifyCard(true, hashedClaimCode, 0))
      .to.emit(marketplace, "Verified")
      .withArgs(wallet.address, otherWallet.address, 25, hashedClaimCode);

    // checks seller balance
    expect(await usdc.balanceOf(wallet.address)).to.equal(100 + 25);
    expect(await usdc.balanceOf(otherWallet.address)).to.equal(100 - 25);
  });

  it("Allows buyer to verify card with no issues", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await usdc
      .connect(otherWallet)
      .approve(marketplace.address, constants.MaxInt256);
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    // verify
    await expect(
      marketplace.connect(otherWallet).verifyCard(true, hashedClaimCode, 0)
    )
      .to.emit(marketplace, "Verified")
      .withArgs(wallet.address, otherWallet.address, 25, hashedClaimCode);

    // checks balances
    expect(await usdc.balanceOf(wallet.address)).to.equal(100 + 25);
    expect(await usdc.balanceOf(otherWallet.address)).to.equal(100 - 25);
  });

  it("Allows buyer to verify card with a price difference, seller gets money", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await usdc
      .connect(otherWallet)
      .approve(marketplace.address, constants.MaxInt256);
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    // verify
    await expect(
      marketplace.connect(otherWallet).verifyCard(true, hashedClaimCode, 10)
    )
      .to.emit(marketplace, "Verified")
      .withArgs(wallet.address, otherWallet.address, 15, hashedClaimCode);

    // checks balances
    expect(await usdc.balanceOf(wallet.address)).to.equal(100 - 9 + 15);
    expect(await usdc.balanceOf(otherWallet.address)).to.equal(100 - 25);
  });

  it("Allows buyer to verify card with a price difference, seller gets no money", async () => {
    // lists card
    await setUpListCard();

    // sends bid/buy request
    await usdc
      .connect(otherWallet)
      .approve(marketplace.address, constants.MaxInt256);
    await marketplace.connect(otherWallet).sendBuyRequest(hashedClaimCode);

    // accepts bid
    await marketplace
      .connect(wallet)
      .acceptBuyRequest(encryptedClaimCode, hashedClaimCode);

    // apply card
    await card.connect(otherWallet).getClaimCode(hashedClaimCode);

    // verify
    await expect(
      marketplace.connect(otherWallet).verifyCard(true, hashedClaimCode, 75)
    )
      .to.emit(marketplace, "Verified")
      .withArgs(wallet.address, otherWallet.address, -50, hashedClaimCode);

    // checks balances
    expect(await usdc.balanceOf(wallet.address)).to.equal(100 - 9);
    expect(await usdc.balanceOf(otherWallet.address)).to.equal(100 - 25);

    // listing gone
    await expect(marketplace.getListing(hashedClaimCode)).to.be.revertedWith(
      "Listing doesn't exist"
    );
  });
});
