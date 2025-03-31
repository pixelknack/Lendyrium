import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-etherscan'

export default {
  defaultNetwork: 'testnet',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    testnet: {
      url: 'https://296.rpc.thirdweb.com/d391b93f5f62d9c15f67142e43841acc',
      accounts: ["0xf76c1d3173b95df92480c690d227d30cf2eab6150b5cf0018b71f68df8e7cf96"],
      chainId: 296,
   }
  },
  solidity: {
    version: '0.8.28',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true
    },
  },
}
