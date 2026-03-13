// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StatusToken
 * @dev Non-transferable status token for OmniBus ecosystem
 * Used for LOVE, FOOD, RENT, VACATION tokens with smart contract boost multipliers
 */

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract StatusToken is IERC20 {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    address public owner;
    address public minter;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Mint events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event MinterUpdated(address indexed newMinter);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Only minter can call this");
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        minter = msg.sender;
    }

    /**
     * @dev Mint new tokens (only minter can call)
     * @param _to Recipient address
     * @param _amount Amount to mint
     */
    function mint(address _to, uint256 _amount) external onlyMinter {
        require(_to != address(0), "Cannot mint to zero address");

        balanceOf[_to] += _amount;
        totalSupply += _amount;

        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
    }

    /**
     * @dev Burn tokens from caller
     * @param _amount Amount to burn
     */
    function burn(uint256 _amount) external {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");

        balanceOf[msg.sender] -= _amount;
        totalSupply -= _amount;

        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
    }

    /**
     * @dev Set new minter address
     * @param _newMinter New minter address
     */
    function setMinter(address _newMinter) external onlyOwner {
        require(_newMinter != address(0), "Cannot set zero minter");
        minter = _newMinter;
        emit MinterUpdated(_newMinter);
    }

    /**
     * @dev Transfer is disabled for status tokens
     */
    function transfer(address _to, uint256 _amount) external override returns (bool) {
        revert("Status tokens are non-transferable");
    }

    /**
     * @dev TransferFrom is disabled for status tokens
     */
    function transferFrom(address _from, address _to, uint256 _amount) external override returns (bool) {
        revert("Status tokens are non-transferable");
    }

    /**
     * @dev Approve is disabled for status tokens
     */
    function approve(address _spender, uint256 _amount) external override returns (bool) {
        revert("Status tokens cannot be approved");
    }

    /**
     * @dev Get allowance (always 0 for status tokens)
     */
    function getAllowance(address _owner, address _spender) external view returns (uint256) {
        return 0;
    }
}
