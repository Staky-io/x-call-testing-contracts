import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('NFTProxy', function () {
  async function deployNFTBridge() {
    const ICON_NETWORK_ID = '0x7.icon' // ICON berlin network id
    const ETH_NETWORK_ID = '0xaa36a7.eth2' // ETH sepolia network id

    const CALL_SERVICE_ADDRESS = '0x9B68bd3a04Ff138CaFfFe6D96Bc330c699F34901' // ETH sepolia testnet address
    const NFT_BRIDGE_ADDRESS = 'cx1111111111111111111111111111111111111111' // ICON NFT bridge address
    const NFT_BRIDGE_BTP_ADDRESS = `btp://${ICON_NETWORK_ID}/${NFT_BRIDGE_ADDRESS}`
    const [deployer, user] = await ethers.getSigners();

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
      ETH_NETWORK_ID
    );

    await nftBridge.deployed();

    nftBridge.allowBridgeAddress(NFT_BRIDGE_BTP_ADDRESS);

    return {
      ICON_NETWORK_ID,
      ETH_NETWORK_ID,
      NFT_BRIDGE_BTP_ADDRESS,
      NFT_BRIDGE_ADDRESS,
      nftBridge,
      wrappedMultiTokenNFT,
      wrappedSingleTokenNFT,
      deployer,
      user
    };
  }

  describe('NFT Bridge test suite', function () {
    it('Should be implemented', async function () {        
      const { NFT_BRIDGE_BTP_ADDRESS, user, nftBridge } = await loadFixture(deployNFTBridge);

      expect(false).to.be.equal(true);
    })
  })
});
