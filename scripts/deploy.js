const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);

    // 1. Deploy Native Token (WETH mock)
    const LendyriumToken = await ethers.getContractFactory("LendyriumToken");
    const nativeToken = await LendyriumToken.deploy(deployer.address);
    await nativeToken.deployed();
    console.log("Native Token deployed to:", nativeToken.address);

    // 2. Deploy Factory
    const LendyriumFactory = await ethers.getContractFactory("LendyriumFactory");
    const factory = await LendyriumFactory.deploy();
    await factory.deployed();
    console.log("Factory deployed to:", factory.address);

    // 3. Deploy full ecosystem through factory
    console.log("Deploying ecosystem through factory...");
    const tx = await factory.deployLendyrium(
        deployer.address,  // Judge address
        nativeToken.address,
        deployer.address   // Initial owner
    );
    await tx.wait();

    // 4. Get deployed addresses from factory
    const governanceToken = await factory.governanceToken();
    const dao = await factory.dao();
    const lendyrium = await factory.lendyrium();
    const oracle = await factory.oracle();
    const disasterResponse = await factory.disasterResponse();

    console.log("\nEcosystem contracts deployed:");
    console.log("- Governance Token:", governanceToken);
    console.log("- DAO:", dao);
    console.log("- Lendyrium:", lendyrium);
    console.log("- Oracle:", oracle);
    console.log("- Disaster Response:", disasterResponse);

    // 5. Verify DisasterResponse initialization
    const drContract = await ethers.getContractAt("DisasterResponse", disasterResponse);
    const lendyriumInDR = await drContract.lendyrium();
    if (lendyriumInDR !== lendyrium) {
        throw new Error("DisasterResponse not initialized with Lendyrium address");
    }

    // 6. Prepare and save deployment addresses
    const addresses = {
        Factory: factory.address,
        NativeToken: nativeToken.address,
        GovernanceToken: governanceToken,
        DAO: dao,
        Lendyrium: lendyrium,
        PriceOracle: oracle,
        DisasterResponse: disasterResponse,
        Deployer: deployer.address
    };

    const network = await ethers.provider.getNetwork();
    const chainId = network.chainId;
    const filePath = path.join(__dirname, `../deployments/${chainId}.json`);
    
    fs.writeFileSync(filePath, JSON.stringify(addresses, null, 2));
    console.log("\nDeployment addresses saved to:", filePath);

    // 7. Final verification
    console.log("\nVerifying deployment...");
    const daoContract = await ethers.getContractAt("LendyriumDAO", dao);
    const daoGovToken = await daoContract.governanceToken();
    
    if (daoGovToken !== governanceToken) {
        throw new Error("DAO not connected to governance token");
    }
    
    console.log("All contracts verified successfully!");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error("Deployment failed:", error);
        process.exit(1);
    });