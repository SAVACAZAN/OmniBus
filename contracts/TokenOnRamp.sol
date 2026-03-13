// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title TokenOnRamp
 * @dev On-ramp system for USDC deposits → status token minting
 * Users send USDC on ETH/Base → mints equivalent status tokens on OmniBus
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStatusToken {
    function mint(address to, uint256 amount) external;
}

contract TokenOnRamp {
    // Token configuration
    struct TokenConfig {
        string name;                    // LOVE, FOOD, RENT, VACATION
        address statusTokenAddress;     // Address on OmniBus
        address usdcAddress;            // Address on source chain (ETH/Base)
        uint256 exchangeRate;           // Status token per USDC (18 decimals)
        bool enabled;
    }

    // Deposit record
    struct Deposit {
        address depositor;
        string tokenName;
        uint256 usdcAmount;
        uint256 statusTokenAmount;
        uint256 timestamp;
        bytes32 txHash;
        bool processed;
    }

    address public owner;
    address public agent;

    mapping(string => TokenConfig) public tokens;
    mapping(bytes32 => Deposit) public deposits;

    uint256 public totalDeposited;
    uint256 public totalMinted;

    // Revenue tracking
    uint256 public gasFeesSaved;
    uint256 public daoRevenue;
    uint256 public liquidityRevenue;
    uint256 public operatorRevenue;
    uint256 public developmentRevenue;

    string[] public tokenList;

    event DepositReceived(
        address indexed depositor,
        string tokenName,
        uint256 usdcAmount,
        uint256 statusTokenAmount,
        uint256 timestamp
    );

    event TokensMinted(
        address indexed recipient,
        string tokenName,
        uint256 amount,
        bytes32 indexed txHash
    );

    event ConfigUpdated(string tokenName, address statusTokenAddress);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAgent() {
        require(msg.sender == agent, "Only agent");
        _;
    }

    constructor() {
        owner = msg.sender;
        agent = msg.sender;

        // Initialize token configs
        // Exchange rate: 1 USDC = 1 status token (1e18)
        uint256 rate = 1e18;

        // LOVE Token
        tokens["LOVE"] = TokenConfig({
            name: "LOVE",
            statusTokenAddress: address(0), // Set by setTokenAddress
            usdcAddress: address(0),        // ETH/Base USDC
            exchangeRate: rate,
            enabled: false
        });
        tokenList.push("LOVE");

        // FOOD Token
        tokens["FOOD"] = TokenConfig({
            name: "FOOD",
            statusTokenAddress: address(0),
            usdcAddress: address(0),
            exchangeRate: rate,
            enabled: false
        });
        tokenList.push("FOOD");

        // RENT Token
        tokens["RENT"] = TokenConfig({
            name: "RENT",
            statusTokenAddress: address(0),
            usdcAddress: address(0),
            exchangeRate: rate,
            enabled: false
        });
        tokenList.push("RENT");

        // VACATION Token
        tokens["VACATION"] = TokenConfig({
            name: "VACATION",
            statusTokenAddress: address(0),
            usdcAddress: address(0),
            exchangeRate: rate,
            enabled: false
        });
        tokenList.push("VACATION");
    }

    /**
     * @dev Set token contract addresses
     */
    function setTokenAddress(
        string memory _tokenName,
        address _statusTokenAddress,
        address _usdcAddress
    ) external onlyOwner {
        require(tokens[_tokenName].statusTokenAddress == address(0), "Already set");

        tokens[_tokenName].statusTokenAddress = _statusTokenAddress;
        tokens[_tokenName].usdcAddress = _usdcAddress;
        tokens[_tokenName].enabled = true;

        emit ConfigUpdated(_tokenName, _statusTokenAddress);
    }

    /**
     * @dev Agent receives deposit notification and mints tokens
     * This would be called by backend service after verifying USDC transfer on source chain
     */
    function mintFromDeposit(
        address _depositor,
        string memory _tokenName,
        uint256 _usdcAmount,
        bytes32 _txHash
    ) external onlyAgent {
        require(tokens[_tokenName].enabled, "Token not enabled");
        require(!deposits[_txHash].processed, "Already processed");

        TokenConfig storage config = tokens[_tokenName];

        // Calculate status token amount (1:1 by default)
        uint256 statusTokenAmount = _usdcAmount * config.exchangeRate / 1e18;

        // Record deposit
        Deposit memory deposit = Deposit({
            depositor: _depositor,
            tokenName: _tokenName,
            usdcAmount: _usdcAmount,
            statusTokenAmount: statusTokenAmount,
            timestamp: block.timestamp,
            txHash: _txHash,
            processed: true
        });

        deposits[_txHash] = deposit;

        // Mint status tokens
        IStatusToken(config.statusTokenAddress).mint(_depositor, statusTokenAmount);

        totalDeposited += _usdcAmount;
        totalMinted += statusTokenAmount;

        emit DepositReceived(_depositor, _tokenName, _usdcAmount, statusTokenAmount, block.timestamp);
        emit TokensMinted(_depositor, _tokenName, statusTokenAmount, _txHash);
    }

    /**
     * @dev Calculate revenue distribution
     * 50% DAO, 30% Liquidity, 15% Operators, 5% Development
     */
    function calculateRevenue(uint256 _depositAmount) public pure returns (
        uint256 dao,
        uint256 liquidity,
        uint256 operator,
        uint256 development
    ) {
        // Assuming ~$2-3 gas fees per deposit on Ethereum, we net ~$0.97 per token after gas
        // Revenue calculation based on deposit amount after fees
        uint256 netProfit = _depositAmount > 3 * 1e6 ? _depositAmount - (3 * 1e6) : 0;

        dao = (netProfit * 50) / 100;
        liquidity = (netProfit * 30) / 100;
        operator = (netProfit * 15) / 100;
        development = (netProfit * 5) / 100;
    }

    /**
     * @dev Record revenue distribution
     */
    function recordRevenue(uint256 _depositAmount) internal {
        (uint256 dao, uint256 liquidity, uint256 operator, uint256 development) =
            calculateRevenue(_depositAmount);

        daoRevenue += dao;
        liquidityRevenue += liquidity;
        operatorRevenue += operator;
        developmentRevenue += development;
    }

    /**
     * @dev Get token configuration
     */
    function getTokenConfig(string memory _tokenName) external view returns (TokenConfig memory) {
        return tokens[_tokenName];
    }

    /**
     * @dev Get deposit details
     */
    function getDeposit(bytes32 _txHash) external view returns (Deposit memory) {
        return deposits[_txHash];
    }

    /**
     * @dev Get revenue summary
     */
    function getRevenueSummary() external view returns (
        uint256 total,
        uint256 dao,
        uint256 liquidity,
        uint256 operator,
        uint256 development
    ) {
        total = daoRevenue + liquidityRevenue + operatorRevenue + developmentRevenue;
        dao = daoRevenue;
        liquidity = liquidityRevenue;
        operator = operatorRevenue;
        development = developmentRevenue;
    }

    /**
     * @dev Set agent address
     */
    function setAgent(address _agent) external onlyOwner {
        require(_agent != address(0), "Invalid agent");
        agent = _agent;
    }

    /**
     * @dev Get all tokens
     */
    function getTokenList() external view returns (string[] memory) {
        return tokenList;
    }
}
