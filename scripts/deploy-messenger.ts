import hre from "hardhat";
import { ethers } from "hardhat";
import { getNetworkSettings } from "./utils";
import fs from "fs";

export default async function main() {
  try {
    const { callService, networkID } = getNetworkSettings(hre.network.name)

    const contracts: object[] = [];

    const deploy = async (factory: string, args: any[], overrides = {}) => {
      const ContractFactory = await ethers.getContractFactory(factory);
      const contract = await ContractFactory.deploy(...args, overrides);

      console.log(`Deploying contract ${factory} with args:`, args)
  
      await contract.deployed();

      contracts.push({ name: factory, address: contract.address, args: args });
  
      console.log(`${factory}: ${contract.address}`);
      return contract;
    }

    await deploy('Messenger', [callService, networkID]);

    if (!fs.existsSync('./deployments')) {
      fs.mkdirSync('./deployments');
    }

    fs.writeFileSync(
      `deployments/messenger-${hre.network.name}.json`,
      JSON.stringify(contracts, null, 4)
    );
  } catch (err) {
    console.error(err);
  }
}

main()
