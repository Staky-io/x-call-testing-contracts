import deployMessenger from "./deploy-messenger";
import deployNFTBridge from "./deploy-nftbridge";

async function main() {
    await deployNFTBridge();
    await deployMessenger();
}