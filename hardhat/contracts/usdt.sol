// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Minimal ERC20 Token
 * @dev Implements the basic ERC20 interface.
 */
contract MyToken {
    // Token details
    string public name = "MyToken";
    string public symbol = "MTK";
    uint8 public decimals = 18;

    // Tracks the total token supply
    uint256 public totalSupply;

    // Owner of the token contract (for minting, etc., if desired)
    address public owner;

    // Balances for each account
    mapping(address => uint256) private _balances;

    // Allowances for each account, where allowances[from][spender] = amount
    mapping(address => mapping(address => uint256)) private _allowances;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Constructor: Mint an initial supply to the deployer
    constructor(uint256 initialSupply) {
        owner = msg.sender;
        _mint(owner, initialSupply);
    }

    /**
     * @dev Returns the balance of a given account.
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Moves `amount` tokens from caller's account to `recipient`.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Returns the remaining number of tokens that `spender` is allowed
     * to spend on behalf of `owner` through `transferFrom`.
     */
    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's allowance.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");

        _approve(sender, msg.sender, currentAllowance - amount);
        _transfer(sender, recipient, amount);

        return true;
    }

    /**
     * @dev Creates new tokens and assigns them to `account`, increasing the total supply.
     *
     * Emits a {Transfer} event.
     *
     * WARNING: This function is public. In production, consider restricting access (e.g. onlyOwner).
     */
    function mint(address account, uint256 amount) public {
        require(msg.sender == owner, "ERC20: only owner can mint");
        _mint(account, amount);
    }

    // ---------------------
    // Internal / Private
    // ---------------------

    /**
     * @dev Internal function that moves `amount` tokens from `sender` to `recipient`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev Internal function that sets `amount` as the allowance of `spender` over the `owner` s tokens.
     */
    function _approve(
        address tokenOwner,
        address spender,
        uint256 amount
    ) internal {
        require(tokenOwner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    /**
     * @dev Internal function to create `amount` tokens and assign them to `account`.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}
