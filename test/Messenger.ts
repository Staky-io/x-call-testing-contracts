import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('Messenger', function () {
  async function deployMessenger() {
    const [deployer, user] = await ethers.getSigners();
    const NETWORK_ID = '0xaa36a7.eth2' // ETH sepolia network id
    const CALL_SERVICE_ADDRESS = '0x9B68bd3a04Ff138CaFfFe6D96Bc330c699F34901' // ETH sepolia testnet address

    const Messenger = await ethers.getContractFactory('Messenger');
    const messenger = await Messenger.deploy(CALL_SERVICE_ADDRESS, NETWORK_ID);

    await messenger.deployed();

    return {
      NETWORK_ID,
      CALL_SERVICE_ADDRESS,
      messenger,
      deployer,
      user
    };
  }

  describe('Messenger testsuite', function () {
    it('Should be implemented', async function () {
      const { messenger, NETWORK_ID, deployer } = await loadFixture(deployMessenger);

      expect(false).to.be.equal(true);
    })
  })
});
