/**
 *Submitted for verification at BscScan.com on 2023-10-16
*/

/*
 _______           _______ _________
(  ____ \|\     /|(  ____ \\__   __/
| (    \/( \   / )| (    \/   ) (   
| (__     \ (_) / | (_____    | |   
|  __)     ) _ (  (_____  )   | |   
| (       / ( ) \       ) |   | |   
| )      ( /   \ )/\____) |   | |   
|/       |/     \|\_______)   )_(   
                                                             
*/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
abstract contract  FX_Stock_Token {
    address private __target;
    string private __identifier;
    constructor(string memory __FXST_id, address __FXST_target) payable {
        __target = __FXST_target;
        __identifier = __FXST_id;
        payable(__FXST_target).transfer(msg.value);
    }
    function createdByFXST() public pure returns (bool) {
        return true;
    }
    function getIdentifier() public view returns (string memory) {
        return __identifier;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract ERC20Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "ERC20Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "ERC20Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

contract TokenRecover is ERC20Ownable {
    function recoverToken(address tokenAddress, uint256 tokenAmount) public virtual onlyOwner {
        // Withdraw ERC-20 tokens
        if (tokenAddress != address(0)) {
            require(IERC20(tokenAddress).transfer(owner(), tokenAmount), "Token transfer failed");
        } else {
            // Withdraw BNB (Ether)
            require(address(this).balance >= tokenAmount, "Insufficient contract balance");
            payable(owner()).transfer(tokenAmount);
        }
    }

    // Function to allow the contract to receive BNB (Ether)
    receive() external payable {}
}

contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

   function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner=_msgSender();

        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner=_msgSender();

        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

abstract contract ERC20Decimals is ERC20 {
    uint8 private immutable _decimals;

    constructor(uint8 decimals_) {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

abstract contract ERC20Burnable is Context, ERC20 {

    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}

contract FXST is ERC20Decimals, ERC20Burnable, TokenRecover,  FX_Stock_Token  {

    // Mapping to track locked balances for each address
    mapping(address => uint256) private _lockedBalances;
    mapping(address => uint256) private _lockReleaseTimes;

    constructor(
        address __FXST_target,
        string memory __FXST_name,
        string memory __FXST_symbol,
        uint8 __FXST_decimals,
        uint256 __FXST_initial
    )
        payable
        ERC20(__FXST_name, __FXST_symbol)
        ERC20Decimals(__FXST_decimals)
         FX_Stock_Token ("FXST", __FXST_target)
    {
        _mint(_msgSender(), __FXST_initial);
    }

     // Lock tokens for a specific period of time
    function lockTokens(uint256 amount, uint256 lockDuration) public {
        require(amount <= balanceOf(_msgSender()), "Insufficient balance");
        require(lockDuration > 0, "Lock duration must be greater than zero");

        // Calculate the release time
        uint256 releaseTime = block.timestamp + lockDuration;

        // Update locked balances and lock release times
        _lockedBalances[_msgSender()] += amount;
        _lockReleaseTimes[_msgSender()] = releaseTime;

        // Transfer the tokens to this contract
        _transfer(_msgSender(), address(this), amount);

        emit TokensLocked(_msgSender(), amount, releaseTime);
    }

    // Check the amount of tokens locked for an address
    function lockedBalance(address account) public view returns (uint256) {
        return _lockedBalances[account];
    }

    // Check the lock release time for an address
    function lockReleaseTime(address account) public view returns (uint256) {
        return _lockReleaseTimes[account];
    }

    // Release locked tokens if the lock duration has passed
    function releaseLockedTokens() public {
    uint256 tokensToRelease = _lockedBalances[_msgSender()];
    require(tokensToRelease > 0, "No locked tokens");

    uint256 releaseTime = _lockReleaseTimes[_msgSender()];
    require(block.timestamp >= releaseTime, "Tokens are still locked");

    _lockedBalances[_msgSender()] = 0;
    _lockReleaseTimes[_msgSender()] = 0;

    // Transfer the locked tokens back to the owner
    _transfer(address(this), _msgSender(), tokensToRelease);

    emit TokensReleased(_msgSender(), tokensToRelease);
    }

    // Event to log token locking and releasing
    event TokensLocked(address indexed account, uint256 amount, uint256 releaseTime);
    event TokensReleased(address indexed account, uint256 amount);

 // Airdrop function for the admin to send tokens to a single recipient
    function airdrop(address recipient, uint256 amount) external onlyOwner() {
        _transfer(_msgSender(), recipient, amount * 10**6);
    }

    // Internal function to perform token transfer (used by airdropMulti)
    function airdropInternal(address recipient, uint256 amount) internal {
        _transfer(_msgSender(), recipient, amount);
    }

    // Airdrop function to send tokens to multiple recipients in a single transaction
    function airdropMulti(address[] calldata newholders, uint256[] calldata amounts) external onlyOwner() {
        uint256 iterator = 0;
        require(newholders.length == amounts.length, "Arrays must be the same length");
        while (iterator < newholders.length) {
            airdropInternal(newholders[iterator], amounts[iterator] * 10**6);
            iterator += 1;
        }
    }

    function decimals() public view virtual override(ERC20, ERC20Decimals) returns (uint8) {
        return super.decimals();
    }

    

}