import hre from "hardhat";
import { ethers } from "hardhat";

const getNetworkSettings = (network: string): { callService: string, networkID: string } => {
  switch (network) {
    case 'sepolia':
      return {
        callService: '0x9B68bd3a04Ff138CaFfFe6D96Bc330c699F34901',
        networkID: '0xaa36a7.eth2',
      }
    case 'bsctestnet':
      return {
        callService: '0x6193c0b12116c4963594761d859571b9950a8686',
        networkID: '0x61.bsc',
      }
    case 'hardhat':
      return {
        callService: '0x6193c0b12116c4963594761d859571b9950a8686',
        networkID: '0xaa36a7.eth2',
      }
    default:
      throw new Error('Invalid network')
  }
}

async function main() {
  const { callService, networkID } = getNetworkSettings(hre.network.name)

  const WrappedMultiTokenNFT = await ethers.getContractFactory('WrappedMultiTokenNFT');
  const wrappedMultiTokenNFT = await WrappedMultiTokenNFT.deploy("");

  await wrappedMultiTokenNFT.deployed();

  console.log('WrappedMultiTokenNFT deployed to:', wrappedMultiTokenNFT.address);

  const WrappedSingleTokenNFT = await ethers.getContractFactory('WrappedSingleTokenNFT');
  const wrappedSingleTokenNFT = await WrappedSingleTokenNFT.deploy("Wrapped NFT", "WNFT");

  await wrappedSingleTokenNFT.deployed();

  console.log('WrappedSingleTokenNFT deployed to:', wrappedSingleTokenNFT.address);

  const NFTBridge = await ethers.getContractFactory('NFTBridge');
  const nftBridge = await NFTBridge.deploy(
    wrappedMultiTokenNFT.address,
    wrappedSingleTokenNFT.address,
    callService,
    networkID
  );

  await nftBridge.deployed();

  console.log('NFTBridge deployed to:', nftBridge.address);

  const Messenger = await ethers.getContractFactory('Messenger');
  const messenger = await Messenger.deploy(
    callService,
    networkID
  );

  await messenger.deployed();

  console.log('Messenger deployed to:', messenger.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
