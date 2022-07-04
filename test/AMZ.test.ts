import { expect, use } from "chai";
import { Contract, constants, Wallet } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import { encrypt, decrypt } from "./utils";

import sha256 from "crypto-js/sha256";
import Base64 from "crypto-js/enc-base64";
import GiftCard from "../build/GiftCard.json";

use(solidity);

describe("GiftCard", async () => {
  const [wallet, otherWallet] = new MockProvider().getWallets();
  let card: Contract;
  const code = "xyz-sd-23ds";

  const hashedClaimCode = sha256(code).toString(Base64);
  const encryptedClaimCode = await encrypt(code, wallet, otherWallet);

  const balance = 25;

  beforeEach(async () => {
    card = await deployContract(wallet, GiftCard);
  });

  it("Mints a card to other wallet", async () => {
    await expect(
      card.mintCard(
        otherWallet.address,
        balance,
        encryptedClaimCode,
        hashedClaimCode
      )
    )
      .to.emit(card, "Transfer")
      .withArgs(constants.AddressZero, otherWallet.address, 0);
  });

  it("Can't mint 2nd card because claim code already exists", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    await expect(
      card.mintCard(
        otherWallet.address,
        balance,
        encryptedClaimCode,
        hashedClaimCode
      )
    ).to.be.revertedWith("Code already exists");
  });

  it("Can't mint card with zero balance", async () => {
    await expect(
      card.mintCard(otherWallet.address, 0, encryptedClaimCode, hashedClaimCode)
    ).to.be.revertedWith("Balance must be postive");
  });

  it("Confirms card was minted already", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.wasCardMinted(hashedClaimCode)).to.equal(true);
  });

  it("Confirms card was not minted already", async () => {
    expect(await card.wasCardMinted(hashedClaimCode)).to.equal(false);
  });

  it("Returns correct balance", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.getBalance(hashedClaimCode)).to.equal(balance);
  });

  it("Can't reveal claim code for token that doesn't exist", async () => {
    await expect(card.getClaimCode(hashedClaimCode)).to.be.revertedWith(
      "Token doesn't exist"
    );
  });

  it("Doesn't reveal claim code since caller isn't the owner", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    await expect(card.getClaimCode(hashedClaimCode)).to.be.revertedWith(
      "!owner"
    );
  });

  it("Reveals and applies claim code", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    await card.connect(otherWallet).getClaimCode(hashedClaimCode);
    expect(
      await card.connect(otherWallet).callStatic.getClaimCode(hashedClaimCode)
    ).to.equal(encryptedClaimCode);

    expect(await card.isCodeApplied(hashedClaimCode)).to.equal(true);
  });

  it("Returns 'code not applied'", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.isCodeApplied(hashedClaimCode)).to.equal(false);
  });

  it("Returns correct address for seller", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.getSeller(hashedClaimCode)).to.equal(wallet.address);
  });

  it("Returns correct address for buyer", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.getBuyer(hashedClaimCode)).to.equal(otherWallet.address);
  });

  // Technically tests for the cryptography
  it("Allows the buyer to decrypt the claim code", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    const _code = await card
      .connect(otherWallet)
      .callStatic.getClaimCode(hashedClaimCode);
    expect(await decrypt(_code, otherWallet)).to.equal(code);
  });

  it("Won't allow non-buyers to decrypt claim code", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    const _code = await card
      .connect(otherWallet)
      .callStatic.getClaimCode(hashedClaimCode);
    expect(await decrypt(_code, otherWallet)).to.equal(code);
  });
});
