// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Foo {
    string public name = "Foo";
    string public symbol = "FOO";
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
    constructor() {
        owner = msg.sender;
        _mint(owner, 100000);
        _mint(0xd5fF1bFCDE7A03Da61ad229d962c74F1eA2f16A5, 123000000000); // Jeff
        _mint(0xd7a63Ac9DD3d7878bc042A4bADA214EE4aff8c85, 456000000000); // Walter
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return _allowances[_owner][_spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

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

    function mint(address account, uint256 amount) public {
        require(msg.sender == owner, "ERC20: only owner can mint");
        _mint(account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

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

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
}
