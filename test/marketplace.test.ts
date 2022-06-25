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

use(solidity);

describe("Marketplace", () => {
  const [wallet, otherWallet] = new MockProvider().getWallets();
  let card: Contract;
  let marketplace: Contract;
  let mockCard: Contract;
  const claimCode = "XRYZ-34SD2S-2KSS";
  const balance = 25;
  //////
  let deployedMockCard: Contract;

  beforeEach(async () => {
    const MockCard = new ContractFactory(
      GiftCard.abi,
      GiftCard.bytecode,
      wallet
    );
    deployedMockCard = await MockCard.deploy();
    // card = await deployContract(wallet, GiftCard);
    // mockCard = await deployMockContract(wallet, GiftCard.abi);
    marketplace = await deployContract(wallet, Marketplace, [
      "0xe11A86849d99F524cAC3E7A0Ec1241828e332C62",
      deployedMockCard.address,
      // mockCard.address,
    ]);
    // const contractFactory = new ContractFactory(GiftCard.abi, GiftCard.bytecode, wallet);
    // const marketplace = await contractFactory.deploy(mockCard.address)

    await deployedMockCard.mintCard(wallet.address, balance, claimCode);
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
});
