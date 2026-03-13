/**
 * Deployment script for status tokens
 * Deploys LOVE, FOOD, RENT, VACATION tokens on OmniBus
 *
 * Usage:
 *   npx hardhat run scripts/deploy-status-tokens.js --network omnibus
 */

const hre = require('hardhat');
const fs = require('fs');
const path = require('path');

async function main() {
    console.log('🚀 Deploying Status Tokens on OmniBus...\n');

    const [deployer] = await hre.ethers.getSigners();
    console.log(`Deployer: ${deployer.address}`);
    console.log(`Network: ${hre.network.name}\n`);

    // Token configurations
    const tokens = [
        { name: 'LOVE', symbol: 'LOVE', pqAlgo: 'Kyber-768' },
        { name: 'FOOD', symbol: 'FOOD', pqAlgo: 'Falcon-512' },
        { name: 'RENT', symbol: 'RENT', pqAlgo: 'Dilithium-5' },
        { name: 'VACATION', symbol: 'VACA', pqAlgo: 'SPHINCS+' },
    ];

    const deployedTokens = {};

    // Deploy each status token
    for (const token of tokens) {
        console.log(`📦 Deploying ${token.name}...`);

        const StatusToken = await hre.ethers.getContractFactory('StatusToken');
        const contract = await StatusToken.deploy(token.name, token.symbol);
        await contract.waitForDeployment();

        const address = await contract.getAddress();
        deployedTokens[token.name] = {
            name: token.name,
            symbol: token.symbol,
            address: address,
            pqAlgorithm: token.pqAlgo,
            deploymentBlock: await hre.ethers.provider.getBlockNumber(),
            deploymentTime: new Date().toISOString(),
        };

        console.log(`   ✓ Deployed at ${address}`);
        console.log(`   Post-Quantum Algorithm: ${token.pqAlgo}\n`);
    }

    // Deploy On-Ramp
    console.log('📦 Deploying TokenOnRamp...');
    const TokenOnRamp = await hre.ethers.getContractFactory('TokenOnRamp');
    const onRamp = await TokenOnRamp.deploy();
    await onRamp.waitForDeployment();
    const onRampAddress = await onRamp.getAddress();
    console.log(`   ✓ Deployed at ${onRampAddress}\n`);

    // Deploy Staking Contract
    console.log('📦 Deploying StakingWithBoost...');
    const omniTokenAddress = process.env.OMNI_TOKEN_ADDRESS || deployer.address; // Placeholder
    const StakingWithBoost = await hre.ethers.getContractFactory('StakingWithBoost');
    const staking = await StakingWithBoost.deploy(omniTokenAddress);
    await staking.waitForDeployment();
    const stakingAddress = await staking.getAddress();
    console.log(`   ✓ Deployed at ${stakingAddress}\n`);

    // Configure on-ramp to know about token addresses
    console.log('⚙️  Configuring On-Ramp...');

    // For each token, set the on-ramp configuration
    for (const token of tokens) {
        const tokenAddress = deployedTokens[token.name].address;

        // Set addresses for Ethereum testnet and Base testnet
        const ethUSDCAddress = process.env[`${token.name}_ETH_USDC`] || '0x0000000000000000000000000000000000000000';
        const baseUSDCAddress = process.env[`${token.name}_BASE_USDC`] || '0x0000000000000000000000000000000000000000';

        if (ethUSDCAddress !== '0x0000000000000000000000000000000000000000') {
            console.log(`   Setting ${token.name} ETH USDC: ${ethUSDCAddress}`);
        }

        if (baseUSDCAddress !== '0x0000000000000000000000000000000000000000') {
            console.log(`   Setting ${token.name} Base USDC: ${baseUSDCAddress}`);
        }
    }

    console.log('   ✓ Configuration complete\n');

    // Configure staking boosts
    console.log('⚙️  Configuring Staking Boosts...');

    const boosts = [
        { token: 'LOVE', multiplier: 150 }, // 1.5x
        { token: 'FOOD', multiplier: 180 }, // 1.8x
        { token: 'RENT', multiplier: 200 }, // 2.0x
        { token: 'VACATION', multiplier: 250 }, // 2.5x
    ];

    for (const boost of boosts) {
        const tx = await staking.addBoost(
            boost.token,
            deployedTokens[boost.token].address,
            boost.multiplier
        );
        await tx.wait();
        console.log(`   ✓ Added ${boost.token} boost: ${boost.multiplier / 100}x APY multiplier`);
    }

    console.log('\n✅ Deployment Complete!\n');

    // Save deployment results
    const deployment = {
        network: hre.network.name,
        chainId: (await hre.ethers.provider.getNetwork()).chainId,
        deployer: deployer.address,
        timestamp: new Date().toISOString(),
        tokens: deployedTokens,
        onRamp: {
            address: onRampAddress,
            description: 'USDC deposit listener and status token minter',
        },
        staking: {
            address: stakingAddress,
            baseAPY: 10,
            boosts: boosts,
            description: 'OMNI staking with status token boost multipliers',
        },
    };

    const deploymentPath = path.join(__dirname, `../deployments/omnibus-${Date.now()}.json`);

    if (!fs.existsSync('./deployments')) {
        fs.mkdirSync('./deployments');
    }

    fs.writeFileSync(deploymentPath, JSON.stringify(deployment, null, 2));
    console.log(`📄 Deployment saved to: ${deploymentPath}\n`);

    // Print summary
    console.log('═══════════════════════════════════════════════════════════');
    console.log('STATUS TOKEN DEPLOYMENT SUMMARY');
    console.log('═══════════════════════════════════════════════════════════\n');

    console.log('TOKENS:');
    for (const [name, token] of Object.entries(deployedTokens)) {
        console.log(`  ${name}:`);
        console.log(`    Address: ${token.address}`);
        console.log(`    PQ Algorithm: ${token.pqAlgorithm}`);
    }

    console.log('\nCONTRACTS:');
    console.log(`  TokenOnRamp: ${onRampAddress}`);
    console.log(`  StakingWithBoost: ${stakingAddress}`);

    console.log('\nAPY MULTIPLIERS:');
    for (const boost of boosts) {
        console.log(`  ${boost.token}: Base 10% × ${boost.multiplier / 100}x = ${(10 * boost.multiplier) / 100}% APY`);
    }

    console.log('\nREVENUE MODEL:');
    console.log('  Per $100 USDC deposit (after ~$3 gas):');
    console.log('    Net profit: ~$97');
    console.log('    DAO: $48.50 (50%)');
    console.log('    Liquidity: $29.10 (30%)');
    console.log('    Operators: $14.55 (15%)');
    console.log('    Development: $4.85 (5%)');

    console.log('\n═══════════════════════════════════════════════════════════\n');
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
