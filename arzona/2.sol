/**
 *Submitted for verification at testnet.bscscan.com on 2024-04-18
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

abstract contract Arzona {
    address private __target;
    string private __identifier;

    constructor(string memory __ARZ_id, address __ARZ_target) payable {
        __target = __ARZ_target;
        __identifier = __ARZ_id;
        payable(__ARZ_target).transfer(msg.value);
    }

    function createdByARZ() public pure returns (bool) {
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

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(
            owner() == _msgSender(),
            "ERC20Ownable: caller is not the owner"
        );
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "ERC20Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

contract tRecover is ERC20Ownable {
    function rescueToken(address tokenAddress, uint256 tokenAmount)
        public
        virtual
        onlyOwner
    {
        // Withdraw ERC-20 tokens
        if (tokenAddress != address(0)) {
            require(
                IERC20(tokenAddress).transfer(owner(), tokenAmount),
                "Token transfer failed"
            );
        } else {
            // Withdraw BNB (Ether)
            require(
                address(this).balance >= tokenAmount,
                "Insufficient contract balance"
            );
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
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(from, to, amount);

        uint256 currentAllowance = _allowances[from][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        _approve(from, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
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
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
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
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}

contract ARZ is ERC20Decimals, ERC20Burnable, tRecover, Arzona {
    uint256 private constant TOTAL_SUPPLY = 14_000_000_000 * (10**18); // 14 billion with 18 decimals
    uint256 private constant LOCKED_SUPPLY = 10_000_000_000 * (10**18); // 10 billion with 18 decimals
    // uint256 private constant RELEASE_PER_MONTH = 5_000_000 * (10**18); 
    uint256 private constant RELEASE_PER_MINUTE = 5_000_000 * (10**18);

    uint256 private _lastReleaseTime;
    uint256 private _releasedTotal;
    uint256 private _lastTotalSupply;
    address[] private _tokenHolders;
    uint256 private _releaseStartTime;

    mapping(address => uint256) private _userHoldings;

    constructor()
        payable
        ERC20("Arzona", "ARZ")
        ERC20Decimals(18)
        Arzona("ARZ", address(this))
    {
        _mint(address(this), TOTAL_SUPPLY);
        // _releaseStartTime = block.timestamp + 365 days;
         _releaseStartTime = block.timestamp + 2 hours;
        _lastReleaseTime = _releaseStartTime;
        _lastTotalSupply = TOTAL_SUPPLY;
    }

    function distributeTokens() public {
        require(
            block.timestamp >= _lastReleaseTime,
            "Release time not reached yet"
        );

        uint256 timeSinceLastRelease = block.timestamp - _lastReleaseTime;
        // uint256 monthsSinceLastRelease = timeSinceLastRelease / 30 days;
        // uint256 tokensToRelease = monthsSinceLastRelease * RELEASE_PER_MONTH;
        uint256 minutesSinceLastRelease = timeSinceLastRelease / 1 minutes;
        uint256 tokensToRelease = minutesSinceLastRelease * RELEASE_PER_MINUTE;

        if (_releasedTotal + tokensToRelease > LOCKED_SUPPLY) {
            tokensToRelease = LOCKED_SUPPLY - _releasedTotal;
        }

        if (tokensToRelease > 0) {
            _releasedTotal += tokensToRelease;

            for (uint256 i = 0; i < _tokenHolders.length; i++) {
                address holder = _tokenHolders[i];
                uint256 holding = _userHoldings[holder];
                uint256 tokensToSend = (holding * tokensToRelease) /
                    _lastTotalSupply;
                _transfer(address(this), holder, tokensToSend);
            }
        }

        // _lastReleaseTime += monthsSinceLastRelease * 30 days;
        _lastReleaseTime += minutesSinceLastRelease * 1 minutes;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        super._transfer(sender, recipient, amount);
        updateTokenHolders(sender, recipient);
        _userHoldings[sender] -= amount;
        _userHoldings[recipient] += amount;
    }

    function _mint(address account, uint256 amount) internal virtual override {
        super._mint(account, amount);
        updateTokenHolders(address(0), account);
        _lastTotalSupply += amount;
    }

    function updateTokenHolders(address sender, address recipient) private {
        if (_userHoldings[sender] == 0 && sender != address(0)) {
            _tokenHolders.push(sender);
        }
        if (_userHoldings[recipient] == 0) {
            _tokenHolders.push(recipient);
        }
    }

    function decimals()
        public
        view
        virtual
        override(ERC20, ERC20Decimals)
        returns (uint8)
    {
        return super.decimals();
    }
}