import { expect, use } from "chai";
import {
  Contract,
  BigNumber,
  constants,
  ContractFactory,
  ethers,
} from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import { deployMockContract } from "@ethereum-waffle/mock-contract";
import GiftCard from "../build/GiftCard.json";
import Marketplace from "../build/Marketplace.json";
import IERC20 from "../build/IERC20.json";
import MockERC20 from "../build/MockERC20.json";

use(solidity);

describe("Marketplace", () => {
  const [wallet, otherWallet] = new MockProvider().getWallets();

  let card: Contract;
  let marketplace: Contract;
  let usdc: Contract;

  const claimCode = "812ee676cf06ba72316862fd3dabe7e403c7395bda62243b7b0eea5eb";
  const balance = 25;

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

    await card.mintCard(wallet.address, balance, claimCode);
  });

  it("Can't list card since price is higher than card balance", async () => {
    await expect(marketplace.listCard(0, balance + 10, 10)).to.be.revertedWith(
      "Price must be equal to / lower than balance"
    );
  });

  it("Can't list card since stake is less than 1/3 the price", async () => {
    await expect(marketplace.listCard(0, balance, 1)).to.be.revertedWith(
      "Stake value must be at least 1/3 of price"
    );
  });

  it("Can't list card since the lister doesn't own it", async () => {
    await expect(
      marketplace.connect(otherWallet).listCard(0, balance, 10)
    ).to.be.revertedWith("Card isn't yours");
  });

  it("Can't list card since the code was already applied", async () => {
    await card.transferFrom(wallet.address, otherWallet.address, 0);

    await card.connect(otherWallet).getClaimCode(0);

    await expect(
      marketplace.connect(otherWallet).listCard(0, balance, 10)
    ).to.be.revertedWith("Claim code already applied");
  });

  it("Lists card", async () => {
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, balance + 10);
    await card.approve(marketplace.address, 0);

    await expect(marketplace.listCard(0, balance, 10))
      .to.emit(marketplace, "Listed")
      .withArgs(wallet.address, 0, balance);
  });

  it("Can't remove listing since caller doesn't own it", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, balance + 10);
    await card.approve(marketplace.address, 0);

    await expect(marketplace.listCard(0, balance, 10))
      .to.emit(marketplace, "Listed")
      .withArgs(wallet.address, 0, balance);

    // attempts to remove
    await expect(
      marketplace.connect(otherWallet).removeCard(0)
    ).to.be.revertedWith("!seller");
  });

  it("Removes listing", async () => {
    // lists card
    await usdc.mint(wallet.address, 100);
    await usdc.approve(marketplace.address, balance + 10);
    await card.approve(marketplace.address, 0);

    await expect(marketplace.listCard(0, balance, 10))
      .to.emit(marketplace, "Listed")
      .withArgs(wallet.address, 0, balance);

    // removes
    await expect(marketplace.removeCard(0))
      .to.emit(marketplace, "Delist")
      .withArgs(wallet.address, 0);
  });
});
