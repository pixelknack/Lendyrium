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
      url: 'https://testnet.hashio.io/api',
      accounts: ["YOUR-KEY-YOUR-COINS"],
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
