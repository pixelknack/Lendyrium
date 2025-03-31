const { ethers } = require("hardhat");

async function main() {
  // Step 1: Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Step 2: Deploy the LendyriumFactory contract
  const LendyriumFactory = await ethers.getContractFactory("LendyriumFactory");
  const factory = await LendyriumFactory.deploy();
  await factory.deployed();
  console.log("LendyriumFactory deployed to:", factory.address);

  // Step 3: Specify parameters for deploying the Lendyrium ecosystem
  const oracleAddress = "0x0000000000000000000000000000000000000001"; // Example oracle address
  const judgeAddress = "0x0000000000000000000000000000000000000002"; // Example judge address
  const nativeToken = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"; // Example token address
  const tx = await factory.deployLendyrium(oracleAddress, judgeAddress, nativeToken);
  await tx.wait();
  console.log("Lendyrium ecosystem deployed successfully");

  // Step 5: Retrieve the addresses of the deployed contracts
  const governanceToken = await factory.governanceToken();
  const dao = await factory.dao();
  const lendyrium = await factory.lendyrium();

  // Step 6: Log the deployed contract addresses
  console.log("LendyriumGovernanceToken deployed to:", governanceToken);
  console.log("LendyriumDAO deployed to:", dao);
  console.log("Lendyrium deployed to:", lendyrium);
}

// Execute the script and handle errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error deploying contracts:", error);
    process.exit(1);
  });