import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";

async function main(hre: HardhatRuntimeEnvironment) {
  const CALL_SERVICE_ADDRESS = '0x9B68bd3a04Ff138CaFfFe6D96Bc330c699F34901' // ETH sepolia testnet address

  const WrappedMultiTokenNFT = await ethers.getContractFactory('WrappedMultiTokenNFT');
  const wrappedMultiTokenNFT = await WrappedMultiTokenNFT.deploy("");

  await wrappedMultiTokenNFT.deployed();

  const WrappedSingleTokenNFT = await ethers.getContractFactory('WrappedSingleTokenNFT');
  const wrappedSingleTokenNFT = await WrappedSingleTokenNFT.deploy("Wrapped NFT", "WNFT");

  await wrappedSingleTokenNFT.deployed();

  const NFTBridge = await ethers.getContractFactory('NFTBridge');
  const nftBridge = await NFTBridge.deploy(
    wrappedMultiTokenNFT.address,
    wrappedSingleTokenNFT.address,
    CALL_SERVICE_ADDRESS,
  );

  await nftBridge.deployed();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
