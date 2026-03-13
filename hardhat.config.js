require('@nomicfoundation/hardhat-toolbox');
require('dotenv').config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: '0.8.20',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            url: 'http://127.0.0.1:8545',
        },
        sepolia: {
            url: process.env.SEPOLIA_RPC || '',
            accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
        },
        ethereum: {
            url: process.env.ETHEREUM_RPC || 'https://eth.llamarpc.com',
            accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
            chainId: 1,
        },
        baseSepolia: {
            url: process.env.BASE_SEPOLIA_RPC || 'https://sepolia.base.org',
            accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
            chainId: 84532,
        },
        base: {
            url: process.env.BASE_RPC || 'https://mainnet.base.org',
            accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
            chainId: 8453,
        },
        omnibus: {
            url: process.env.OMNIBUS_RPC || 'http://localhost:8545',
            accounts: process.env.OMNIBUS_PRIVATE_KEY ? [process.env.OMNIBUS_PRIVATE_KEY] : [],
            chainId: 506,
        },
    },
    etherscan: {
        apiKey: {
            mainnet: process.env.ETHERSCAN_API_KEY || '',
            base: process.env.BASESCAN_API_KEY || '',
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS === 'true',
        currency: 'USD',
        coinmarketcap: process.env.COINMARKETCAP_API_KEY || '',
    },
};
