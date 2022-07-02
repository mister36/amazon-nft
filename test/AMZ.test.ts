import { expect, use } from "chai";
import { Contract, constants, Wallet } from "ethers";
import { deployContract, MockProvider, solidity } from "ethereum-waffle";
import EthCrypto from "eth-crypto";

import sha256 from "crypto-js/sha256";
import Base64 from "crypto-js/enc-base64";
import GiftCard from "../build/GiftCard.json";

use(solidity);

const encrypt = async (code: string, from: Wallet, to: Wallet) => {
  const signature = EthCrypto.sign(
    from.privateKey,
    EthCrypto.hash.keccak256(code)
  );
  const payload = {
    message: code,
    signature,
  };

  const encrypted = await EthCrypto.encryptWithPublicKey(
    to.publicKey.slice(2),
    JSON.stringify(payload)
  );

  return EthCrypto.cipher.stringify(encrypted);
};

const decrypt = async (code: string, receiver: Wallet) => {
  const encryptedObject = EthCrypto.cipher.parse(code);

  const decrypted = await EthCrypto.decryptWithPrivateKey(
    receiver.privateKey,
    encryptedObject
  );
  return JSON.parse(decrypted).message;
};

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

    expect(await card.getBalance(0)).to.equal(balance);
  });

  it("Can't reveal claim code for token that doesn't exist", async () => {
    await expect(card.getClaimCode(0)).to.be.revertedWith(
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

    await expect(card.getClaimCode(0)).to.be.revertedWith("!owner");
  });

  it("Reveals and applies claim code", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    await card.connect(otherWallet).getClaimCode(0);
    expect(await card.connect(otherWallet).callStatic.getClaimCode(0)).to.equal(
      encryptedClaimCode
    );

    expect(await card.isCodeApplied(0)).to.equal(true);
  });

  it("Returns 'code not applied'", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.isCodeApplied(0)).to.equal(false);
  });

  it("Returns correct address for seller", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    expect(await card.getSeller(0)).to.equal(wallet.address);
  });

  // Technically tests for the cryptography
  it("Allows the buyer to decrypt the claim code", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    const _code = await card.connect(otherWallet).callStatic.getClaimCode(0);
    expect(await decrypt(_code, otherWallet)).to.equal(code);
  });

  it("Won't allow non-buyers to decrypt claim code", async () => {
    await card.mintCard(
      otherWallet.address,
      balance,
      encryptedClaimCode,
      hashedClaimCode
    );

    const _code = await card.connect(otherWallet).callStatic.getClaimCode(0);
    expect(await decrypt(_code, otherWallet)).to.equal(code);
  });
});
