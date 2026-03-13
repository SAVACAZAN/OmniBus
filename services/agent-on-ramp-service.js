/**
 * Agent On-Ramp Service
 * Listens for USDC deposits on ETH/Base → mints status tokens on OmniBus
 *
 * Deployment:
 *   npm install ethers dotenv
 *   Set ETHEREUM_RPC, BASE_RPC, OMNIBUS_RPC in .env
 *   node agent-on-ramp-service.js
 */

const ethers = require('ethers');
const fs = require('fs');
require('dotenv').config();

// Configuration
const CONFIG = {
    ethereum: {
        rpc: process.env.ETHEREUM_RPC || 'https://eth.llamarpc.com',
        chainId: 1,
        chainName: 'Ethereum',
        confirmations: 12,
    },
    base: {
        rpc: process.env.BASE_RPC || 'https://mainnet.base.org',
        chainId: 8453,
        chainName: 'Base',
        confirmations: 3,
    },
    omnibus: {
        rpc: process.env.OMNIBUS_RPC || 'http://localhost:8545',
        chainId: 506,
        chainName: 'OmniBus',
    },
    tokens: {
        LOVE: {
            name: 'LOVE',
            usdcAddress: '', // Set from args
            statusTokenAddress: '', // Set from args
            agentAddress: '', // Private key holder
        },
        FOOD: {
            name: 'FOOD',
            usdcAddress: '',
            statusTokenAddress: '',
            agentAddress: '',
        },
        RENT: {
            name: 'RENT',
            usdcAddress: '',
            statusTokenAddress: '',
            agentAddress: '',
        },
        VACATION: {
            name: 'VACATION',
            usdcAddress: '',
            statusTokenAddress: '',
            agentAddress: '',
        },
    },
};

// USDC ABI (minimal)
const USDC_ABI = [
    'event Transfer(address indexed from, address indexed to, uint256 value)',
    'function balanceOf(address account) external view returns (uint256)',
    'function decimals() external view returns (uint8)',
];

// Status Token ABI
const STATUS_TOKEN_ABI = [
    'function mint(address to, uint256 amount) external',
    'function balanceOf(address account) external view returns (uint256)',
];

// On-Ramp ABI
const ON_RAMP_ABI = [
    'function mintFromDeposit(address _depositor, string memory _tokenName, uint256 _usdcAmount, bytes32 _txHash) external',
];

class AgentOnRampService {
    constructor(config) {
        this.config = config;
        this.providers = {};
        this.signers = {};
        this.contracts = {};
        this.processedHashes = new Set();
        this.lastBlockNumber = {};
    }

    /**
     * Initialize providers and contracts
     */
    async initialize() {
        console.log('🚀 Initializing Agent On-Ramp Service...');

        // Initialize Ethereum provider
        this.providers.ethereum = new ethers.JsonRpcProvider(this.config.ethereum.rpc);
        console.log(`✓ Connected to Ethereum: ${await this.providers.ethereum.getNetwork()}`);

        // Initialize Base provider
        this.providers.base = new ethers.JsonRpcProvider(this.config.base.rpc);
        console.log(`✓ Connected to Base: ${await this.providers.base.getNetwork()}`);

        // Initialize OmniBus provider
        this.providers.omnibus = new ethers.JsonRpcProvider(this.config.omnibus.rpc);
        try {
            const network = await this.providers.omnibus.getNetwork();
            console.log(`✓ Connected to OmniBus: Chain ID ${network.chainId}`);
        } catch (e) {
            console.warn('⚠ OmniBus RPC unavailable (will retry)');
        }

        // Initialize signers with private key
        if (process.env.AGENT_PRIVATE_KEY) {
            this.signers.ethereum = new ethers.Wallet(process.env.AGENT_PRIVATE_KEY, this.providers.ethereum);
            this.signers.base = new ethers.Wallet(process.env.AGENT_PRIVATE_KEY, this.providers.base);
            this.signers.omnibus = new ethers.Wallet(process.env.AGENT_PRIVATE_KEY, this.providers.omnibus);
            console.log(`✓ Agent wallet: ${this.signers.ethereum.address}`);
        }

        // Get starting block numbers
        this.lastBlockNumber.ethereum = await this.providers.ethereum.getBlockNumber();
        this.lastBlockNumber.base = await this.providers.base.getBlockNumber();

        console.log(`✓ Starting Ethereum at block ${this.lastBlockNumber.ethereum}`);
        console.log(`✓ Starting Base at block ${this.lastBlockNumber.base}`);

        console.log('\n📡 Agent On-Ramp Service initialized successfully\n');
    }

    /**
     * Listen for USDC transfers to agent addresses
     */
    async startListening() {
        console.log('👂 Starting to listen for USDC deposits...\n');

        // Poll every 12 seconds
        setInterval(() => this.pollBlocks(), 12000);

        // Also listen for new blocks in real-time
        this.providers.ethereum.on('block', (blockNumber) => {
            this.handleNewBlockEthereum(blockNumber);
        });

        this.providers.base.on('block', (blockNumber) => {
            this.handleNewBlockBase(blockNumber);
        });
    }

    /**
     * Poll for new blocks and transactions
     */
    async pollBlocks() {
        try {
            // Check Ethereum
            const ethBlockNumber = await this.providers.ethereum.getBlockNumber();
            if (ethBlockNumber > this.lastBlockNumber.ethereum) {
                await this.scanBlocksEthereum(this.lastBlockNumber.ethereum + 1, ethBlockNumber);
                this.lastBlockNumber.ethereum = ethBlockNumber;
            }

            // Check Base
            const baseBlockNumber = await this.providers.base.getBlockNumber();
            if (baseBlockNumber > this.lastBlockNumber.base) {
                await this.scanBlocksBase(this.lastBlockNumber.base + 1, baseBlockNumber);
                this.lastBlockNumber.base = baseBlockNumber;
            }
        } catch (error) {
            console.error('❌ Polling error:', error.message);
        }
    }

    /**
     * Scan Ethereum blocks for USDC transfers
     */
    async scanBlocksEthereum(fromBlock, toBlock) {
        console.log(`[ETH] Scanning blocks ${fromBlock} → ${toBlock}`);

        for (const [tokenName, tokenConfig] of Object.entries(this.config.tokens)) {
            if (!tokenConfig.usdcAddress) continue;

            try {
                const contract = new ethers.Contract(
                    tokenConfig.usdcAddress,
                    USDC_ABI,
                    this.providers.ethereum
                );

                const filter = contract.filters.Transfer(null, this.signers.ethereum.address);
                const events = await contract.queryFilter(filter, fromBlock, toBlock);

                for (const event of events) {
                    await this.handleUSDCDeposit(event, 'ethereum', tokenName);
                }
            } catch (error) {
                console.error(`[ETH] Error scanning ${tokenName}:`, error.message);
            }
        }
    }

    /**
     * Scan Base blocks for USDC transfers
     */
    async scanBlocksBase(fromBlock, toBlock) {
        console.log(`[BASE] Scanning blocks ${fromBlock} → ${toBlock}`);

        for (const [tokenName, tokenConfig] of Object.entries(this.config.tokens)) {
            if (!tokenConfig.usdcAddress) continue;

            try {
                const contract = new ethers.Contract(
                    tokenConfig.usdcAddress,
                    USDC_ABI,
                    this.providers.base
                );

                const filter = contract.filters.Transfer(null, this.signers.base.address);
                const events = await contract.queryFilter(filter, fromBlock, toBlock);

                for (const event of events) {
                    await this.handleUSDCDeposit(event, 'base', tokenName);
                }
            } catch (error) {
                console.error(`[BASE] Error scanning ${tokenName}:`, error.message);
            }
        }
    }

    /**
     * Handle USDC deposit
     */
    async handleUSDCDeposit(event, chain, tokenName) {
        const txHash = event.transactionHash;

        // Skip if already processed
        if (this.processedHashes.has(txHash)) {
            return;
        }

        this.processedHashes.add(txHash);

        const depositor = event.args.from; // or args[0]
        const amount = event.args.value;

        console.log(`\n💰 USDC Deposit Detected on ${chain.toUpperCase()}`);
        console.log(`   Token: ${tokenName}`);
        console.log(`   From: ${depositor}`);
        console.log(`   Amount: ${ethers.formatUnits(amount, 6)} USDC`);
        console.log(`   Tx: ${txHash}`);

        // Wait for confirmations
        const confirmations = chain === 'ethereum'
            ? this.config.ethereum.confirmations
            : this.config.base.confirmations;

        const provider = chain === 'ethereum'
            ? this.providers.ethereum
            : this.providers.base;

        try {
            const receipt = await provider.waitForTransaction(txHash, confirmations);

            if (receipt && receipt.status === 1) {
                console.log(`   ✓ Confirmed with ${confirmations} confirmations`);

                // Mint status tokens on OmniBus
                await this.mintStatusTokens(depositor, tokenName, amount, txHash);
            } else {
                console.log(`   ❌ Transaction failed or not confirmed`);
            }
        } catch (error) {
            console.error(`   ❌ Error waiting for confirmation:`, error.message);
        }
    }

    /**
     * Mint status tokens on OmniBus
     */
    async mintStatusTokens(depositor, tokenName, usdcAmount, txHash) {
        console.log(`\n🔄 Minting ${tokenName} on OmniBus...`);

        try {
            const tokenConfig = this.config.tokens[tokenName];

            // Create on-ramp contract instance
            const onRampContract = new ethers.Contract(
                process.env.ON_RAMP_ADDRESS,
                ON_RAMP_ABI,
                this.signers.omnibus
            );

            // Convert USDC to status token amount (1:1)
            const statusTokenAmount = usdcAmount; // Assumes both have same decimals

            // Call mintFromDeposit
            const tx = await onRampContract.mintFromDeposit(
                depositor,
                tokenName,
                statusTokenAmount,
                txHash
            );

            console.log(`   Tx submitted: ${tx.hash}`);

            const receipt = await tx.wait();
            console.log(`   ✓ Minting complete! Block: ${receipt.blockNumber}`);
            console.log(`   Status token amount: ${ethers.formatUnits(statusTokenAmount, 18)} ${tokenName}`);

            // Log to file
            this.logTransaction({
                timestamp: new Date().toISOString(),
                depositor,
                tokenName,
                usdcAmount: ethers.formatUnits(usdcAmount, 6),
                statusTokenAmount: ethers.formatUnits(statusTokenAmount, 18),
                sourceChain: txHash.includes('0x') ? 'ethereum' : 'base',
                sourceChainTx: txHash,
                omnibusTx: tx.hash,
                status: 'SUCCESS',
            });

        } catch (error) {
            console.error(`   ❌ Minting failed:`, error.message);

            this.logTransaction({
                timestamp: new Date().toISOString(),
                depositor,
                tokenName,
                usdcAmount: ethers.formatUnits(usdcAmount, 6),
                sourceChain: 'ethereum',
                sourceChainTx: txHash,
                status: 'FAILED',
                error: error.message,
            });
        }
    }

    /**
     * Log transaction to file
     */
    logTransaction(data) {
        const logFile = './logs/on-ramp-transactions.jsonl';

        // Ensure logs directory exists
        if (!fs.existsSync('./logs')) {
            fs.mkdirSync('./logs');
        }

        fs.appendFileSync(logFile, JSON.stringify(data) + '\n');
    }

    /**
     * Health check endpoint
     */
    getStatus() {
        return {
            service: 'Agent On-Ramp',
            status: 'running',
            chains: {
                ethereum: {
                    lastBlock: this.lastBlockNumber.ethereum,
                    connected: true,
                },
                base: {
                    lastBlock: this.lastBlockNumber.base,
                    connected: true,
                },
                omnibus: {
                    connected: true,
                },
            },
            processedTransactions: this.processedHashes.size,
            timestamp: new Date().toISOString(),
        };
    }
}

// Start service
async function main() {
    const service = new AgentOnRampService(CONFIG);

    try {
        await service.initialize();
        await service.startListening();

        // Health check every 60 seconds
        setInterval(() => {
            console.log('📊 Service Status:', service.getStatus());
        }, 60000);

        console.log('✅ Agent On-Ramp Service running. Press Ctrl+C to exit.\n');
    } catch (error) {
        console.error('❌ Failed to start service:', error);
        process.exit(1);
    }
}

main().catch(console.error);

module.exports = AgentOnRampService;
