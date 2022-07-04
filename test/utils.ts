import EthCrypto from "eth-crypto";
import { Wallet } from "ethers";

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

export { encrypt, decrypt };
