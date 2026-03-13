// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StakingWithBoost
 * @dev Staking contract with status token boost multipliers
 * Status token balances provide APY multipliers without being transferred
 */

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

contract StakingWithBoost {
    // Staking configuration
    struct StakeInfo {
        uint256 amount;              // OMNI staked
        uint256 startTime;           // When staking started
        uint256 claimedRewards;      // Total rewards claimed
        uint256 lastClaimTime;       // Last claim timestamp
    }

    // Boost configuration
    struct BoostConfig {
        string tokenName;            // LOVE, FOOD, RENT, VACATION
        address tokenAddress;        // Status token contract
        uint256 boostMultiplier;     // 1.1x = 110, 1.5x = 150, 2.0x = 200
    }

    address public owner;
    address public omniToken;        // OMNI token address

    // Base APY: 10% per year (0.0274% per day)
    uint256 public constant BASE_APY = 10;  // 10%

    uint256 public totalStaked;
    mapping(address => StakeInfo) public stakes;

    BoostConfig[] public boostConfigs;
    mapping(string => BoostConfig) public boosts;

    event Staked(address indexed staker, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed staker, uint256 rewards, uint256 multiplier);
    event Unstaked(address indexed staker, uint256 amount, uint256 timestamp);
    event BoostAdded(string tokenName, address tokenAddress, uint256 multiplier);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _omniToken) {
        owner = msg.sender;
        omniToken = _omniToken;
    }

    /**
     * @dev Add a boost configuration
     */
    function addBoost(
        string memory _tokenName,
        address _tokenAddress,
        uint256 _boostMultiplier
    ) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token");
        require(_boostMultiplier >= 100, "Multiplier must be >= 100 (1.0x)");

        BoostConfig memory config = BoostConfig({
            tokenName: _tokenName,
            tokenAddress: _tokenAddress,
            boostMultiplier: _boostMultiplier
        });

        boostConfigs.push(config);
        boosts[_tokenName] = config;

        emit BoostAdded(_tokenName, _tokenAddress, _boostMultiplier);
    }

    /**
     * @dev Get total boost multiplier for a staker based on their status token balances
     * @param _staker Address to check
     * @return Total multiplier (100 = 1.0x, 150 = 1.5x, etc.)
     */
    function getBoostMultiplier(address _staker) public view returns (uint256) {
        uint256 multiplier = 100; // Base 1.0x

        // Check each status token balance and sum boost multipliers
        for (uint256 i = 0; i < boostConfigs.length; i++) {
            uint256 balance = IERC20(boostConfigs[i].tokenAddress).balanceOf(_staker);

            if (balance > 0) {
                // Each status token with balance adds its multiplier
                // Example: LOVE holder gets +1.5x if they have any LOVE
                multiplier += boostConfigs[i].boostMultiplier - 100;
            }
        }

        return multiplier;
    }

    /**
     * @dev Calculate rewards based on staked amount and time
     * @param _staker Staker address
     * @return Base reward amount without boost
     * @return Boosted reward amount with multiplier
     * @return Multiplier Applied multiplier
     */
    function calculateRewards(address _staker) public view returns (
        uint256,
        uint256,
        uint256
    ) {
        StakeInfo memory stake = stakes[_staker];

        if (stake.amount == 0) {
            return (0, 0, 100);
        }

        // Time elapsed in seconds since last claim (or stake start)
        uint256 timeElapsed = block.timestamp - (stake.lastClaimTime > 0 ? stake.lastClaimTime : stake.startTime);

        // Seconds per year
        uint256 secondsPerYear = 365 days;

        // Base reward: amount * APY * time / year
        uint256 baseReward = (stake.amount * BASE_APY * timeElapsed) / (100 * secondsPerYear);

        // Get boost multiplier
        uint256 multiplier = getBoostMultiplier(_staker);

        // Boosted reward
        uint256 boostedReward = (baseReward * multiplier) / 100;

        return (baseReward, boostedReward, multiplier);
    }

    /**
     * @dev Stake OMNI tokens
     * @param _amount Amount to stake
     */
    function stake(uint256 _amount) external {
        require(_amount > 0, "Amount must be > 0");

        // In real implementation, would transfer OMNI from user
        // For now, simulate the stake
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender] = StakeInfo({
                amount: _amount,
                startTime: block.timestamp,
                claimedRewards: 0,
                lastClaimTime: 0
            });
        } else {
            stakes[msg.sender].amount += _amount;
        }

        totalStaked += _amount;

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    /**
     * @dev Claim rewards
     */
    function claimRewards() external {
        StakeInfo storage stake = stakes[msg.sender];
        require(stake.amount > 0, "No stake found");

        (uint256 baseReward, uint256 boostedReward, uint256 multiplier) = calculateRewards(msg.sender);
        require(boostedReward > 0, "No rewards to claim");

        stake.lastClaimTime = block.timestamp;
        stake.claimedRewards += boostedReward;

        // In real implementation, would mint or transfer rewards
        emit RewardsClaimed(msg.sender, boostedReward, multiplier);
    }

    /**
     * @dev Unstake OMNI tokens
     * @param _amount Amount to unstake
     */
    function unstake(uint256 _amount) external {
        StakeInfo storage stake = stakes[msg.sender];
        require(stake.amount >= _amount, "Insufficient stake");

        // Claim pending rewards first
        if (stake.amount > 0) {
            (uint256 baseReward, uint256 boostedReward, ) = calculateRewards(msg.sender);
            if (boostedReward > 0) {
                stake.claimedRewards += boostedReward;
            }
        }

        stake.amount -= _amount;
        stake.lastClaimTime = block.timestamp;
        totalStaked -= _amount;

        // In real implementation, would transfer OMNI back to user
        emit Unstaked(msg.sender, _amount, block.timestamp);
    }

    /**
     * @dev Get staker info
     */
    function getStakeInfo(address _staker) external view returns (StakeInfo memory) {
        return stakes[_staker];
    }

    /**
     * @dev Get boost configs
     */
    function getBoostConfigs() external view returns (BoostConfig[] memory) {
        return boostConfigs;
    }

    /**
     * @dev Example: Calculate APY with boosts
     * Base: 10% APY
     * + LOVE holder: 10% * 1.5x = 15%
     * + FOOD holder: 10% * 2.0x = 20%
     * + RENT + VACATION holders: stacking multipliers
     */
    function getEffectiveAPY(address _staker) external view returns (uint256) {
        uint256 multiplier = getBoostMultiplier(_staker);
        return (BASE_APY * multiplier) / 100;
    }
}
