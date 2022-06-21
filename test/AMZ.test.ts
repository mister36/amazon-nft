import { expect, use } from "chai";
import { Contract, BigNumber, constants, ethers } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import GiftCard from "../build/GiftCard.json";

use(solidity);

describe("GiftCard", () => {
  const [wallet, otherWallet] = new MockProvider().getWallets();
  let card: Contract;
  const claimCode = "XRYZ-34SD2S-2KSS";
  const balance = 25;

  beforeEach(async () => {
    card = await deployContract(wallet, GiftCard);
  });

  it("Mints a card", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);
  });

  it("Can't mint 2nd card because claim code already exists", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    await expect(
      card.mintCard(wallet.address, 50, claimCode)
    ).to.be.revertedWith("Code already exists");
  });

  it("Can't mint card with zero balance", async () => {
    await expect(
      card.mintCard(wallet.address, 0, claimCode)
    ).to.be.revertedWith("Balance must be postive");
  });

  it("Confirms card was minted already", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    expect(await card.wasCardMinted(claimCode)).to.equal(true);
  });

  it("Confirms card was not minted already", async () => {
    expect(await card.wasCardMinted(claimCode)).to.equal(false);
  });

  it("Returns correct balance", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    expect(await card.getBalance(0)).to.equal(balance);
  });

  it("Can't reveal claim code for token that doesn't exist", async () => {
    await expect(card.getClaimCode(0)).to.be.revertedWith(
      "Token doesn't exist"
    );
  });

  it("Doesn't reveal claim code since caller isn't the owner", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    await expect(card.connect(otherWallet).getClaimCode(0)).to.be.revertedWith(
      "!owner"
    );
  });

  it("Reveals claim code", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    expect(await card.callStatic.getClaimCode(0)).to.equal(claimCode);
  });

  it("Reveals and applies claim code", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    await expect(card.transferFrom(wallet.address, otherWallet.address, 0))
      .to.emit(card, "Transfer")
      .withArgs(wallet.address, otherWallet.address, 0);

    expect(await card.connect(otherWallet).callStatic.getClaimCode(0)).to.equal(
      claimCode
    );
    await card.connect(otherWallet).getClaimCode(0);

    expect(await card.isCodeApplied(0)).to.equal(true);
  });

  it("Returns 'code not applied' since owner is the minter and past owner didn't reveal code", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    await expect(card.transferFrom(wallet.address, otherWallet.address, 0))
      .to.emit(card, "Transfer")
      .withArgs(wallet.address, otherWallet.address, 0);

    await expect(
      card
        .connect(otherWallet)
        .transferFrom(otherWallet.address, wallet.address, 0)
    )
      .to.emit(card, "Transfer")
      .withArgs(otherWallet.address, wallet.address, 0);

    expect(await card.connect(wallet).callStatic.getClaimCode(0)).to.equal(
      claimCode
    );
    await card.getClaimCode(0);

    expect(await card.isCodeApplied(0)).to.equal(false);
  });

  it("Returns zero address since card hasn't been minted", async () => {
    expect(await card.getOriginalMinter(0)).to.equal(constants.AddressZero);
  });

  it("Returns the original minter", async () => {
    await expect(card.mintCard(wallet.address, balance, claimCode))
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, wallet.address, 0);

    await expect(card.transferFrom(wallet.address, otherWallet.address, 0))
      .to.emit(card, "Transfer")
      .withArgs(wallet.address, otherWallet.address, 0);

    expect(await card.getOriginalMinter(0)).to.equal(wallet.address);
  });
});
