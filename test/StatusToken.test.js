/**
 * Status Token Tests
 * Tests for non-transferable status token contract
 */

const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('StatusToken', function () {
    let token;
    let owner;
    let minter;
    let user1;
    let user2;

    beforeEach(async function () {
        [owner, minter, user1, user2] = await ethers.getSigners();

        const StatusToken = await ethers.getContractFactory('StatusToken');
        token = await StatusToken.deploy('LOVE', 'LOVE');
        await token.waitForDeployment();

        // Set minter
        await token.setMinter(minter.address);
    });

    describe('Deployment', function () {
        it('Should set correct name and symbol', async function () {
            expect(await token.name()).to.equal('LOVE');
            expect(await token.symbol()).to.equal('LOVE');
        });

        it('Should have decimals of 18', async function () {
            expect(await token.decimals()).to.equal(18);
        });

        it('Should have zero total supply initially', async function () {
            expect(await token.totalSupply()).to.equal(0);
        });
    });

    describe('Minting', function () {
        it('Should mint tokens', async function () {
            const amount = ethers.parseEther('100');
            await token.connect(minter).mint(user1.address, amount);

            expect(await token.balanceOf(user1.address)).to.equal(amount);
            expect(await token.totalSupply()).to.equal(amount);
        });

        it('Should emit Mint event', async function () {
            const amount = ethers.parseEther('100');
            await expect(token.connect(minter).mint(user1.address, amount))
                .to.emit(token, 'Mint')
                .withArgs(user1.address, amount);
        });

        it('Should revert if non-minter tries to mint', async function () {
            const amount = ethers.parseEther('100');
            await expect(
                token.connect(user1).mint(user1.address, amount)
            ).to.be.revertedWith('Only minter can call this');
        });

        it('Should revert if minting to zero address', async function () {
            const amount = ethers.parseEther('100');
            await expect(
                token.connect(minter).mint(ethers.ZeroAddress, amount)
            ).to.be.revertedWith('Cannot mint to zero address');
        });
    });

    describe('Burning', function () {
        beforeEach(async function () {
            const amount = ethers.parseEther('100');
            await token.connect(minter).mint(user1.address, amount);
        });

        it('Should burn tokens', async function () {
            const burnAmount = ethers.parseEther('50');
            await token.connect(user1).burn(burnAmount);

            expect(await token.balanceOf(user1.address)).to.equal(
                ethers.parseEther('50')
            );
            expect(await token.totalSupply()).to.equal(ethers.parseEther('50'));
        });

        it('Should emit Burn event', async function () {
            const burnAmount = ethers.parseEther('50');
            await expect(token.connect(user1).burn(burnAmount))
                .to.emit(token, 'Burn')
                .withArgs(user1.address, burnAmount);
        });

        it('Should revert if burning more than balance', async function () {
            const burnAmount = ethers.parseEther('150');
            await expect(
                token.connect(user1).burn(burnAmount)
            ).to.be.revertedWith('Insufficient balance');
        });
    });

    describe('Non-Transferability', function () {
        beforeEach(async function () {
            const amount = ethers.parseEther('100');
            await token.connect(minter).mint(user1.address, amount);
        });

        it('Should reject transfer', async function () {
            const amount = ethers.parseEther('50');
            await expect(
                token.connect(user1).transfer(user2.address, amount)
            ).to.be.revertedWith('Status tokens are non-transferable');
        });

        it('Should reject transferFrom', async function () {
            const amount = ethers.parseEther('50');
            await expect(
                token.connect(owner).transferFrom(user1.address, user2.address, amount)
            ).to.be.revertedWith('Status tokens are non-transferable');
        });

        it('Should reject approve', async function () {
            const amount = ethers.parseEther('50');
            await expect(
                token.connect(user1).approve(user2.address, amount)
            ).to.be.revertedWith('Status tokens cannot be approved');
        });
    });

    describe('Minter Management', function () {
        it('Should update minter', async function () {
            await token.setMinter(user1.address);
            expect(await token.minter()).to.equal(user1.address);
        });

        it('Should emit MinterUpdated event', async function () {
            await expect(token.setMinter(user1.address))
                .to.emit(token, 'MinterUpdated')
                .withArgs(user1.address);
        });

        it('Should revert if non-owner tries to set minter', async function () {
            await expect(
                token.connect(user1).setMinter(user2.address)
            ).to.be.revertedWith('Only owner can call this');
        });

        it('Should revert if setting zero minter', async function () {
            await expect(
                token.setMinter(ethers.ZeroAddress)
            ).to.be.revertedWith('Cannot set zero minter');
        });
    });
});
