// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

abstract contract GRT_PAY_Protocol {
    address private __target;
    string private __identifier;

    constructor(string memory __GRT_id, address __GRT_target) payable {
        __target = __GRT_target;
        __identifier = __GRT_id;
        payable(__GRT_target).transfer(msg.value);
    }

    function createdByGRT() public pure returns (bool) {
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

contract DumpRecover is ERC20Ownable {
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
    receive() external payable virtual {}
}

contract ERC20 is Context, IERC20, ERC20Ownable {
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
        address owner = _msgSender();

        _transfer(owner, to, amount);
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
        address owner = _msgSender();

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
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        _approve(sender, _msgSender(), currentAllowance - amount);

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

        // If the sender is not the owner, burn tokens
        if (sender != owner() && sender != address(this)) {
            // Calculate the amount to burn (1% of the transfer amount)
            uint256 burnAmount = amount / 100;

            // Subtract the burn amount from the contract's balance
            uint256 contractBalance = _balances[address(this)];
            require(
                contractBalance >= burnAmount,
                "ERC20: burn amount exceeds contract balance"
            );

            _balances[address(this)] = contractBalance - burnAmount;
            _totalSupply -= burnAmount; // Burn tokens
            emit Transfer(address(this), address(0), burnAmount);
        }

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

contract GRT is ERC20Decimals, ERC20Burnable, DumpRecover, GRT_PAY_Protocol {
    mapping(address => bool) private _botAddresses;
    mapping(address => uint256) private _lastTransactionTime;
    uint256 private constant _botDetectionCooldown = 5 minutes;
    uint256 private constant TOTAL_SUPPLY = 10000000000 * (10**18);
    uint256 private constant BURN_SUPPLY = 5000000000 * (10**18);

    mapping(address => uint256) private _lockedBalances;

    constructor(
        address __GRT_target,
        string memory __GRT_name,
        string memory __GRT_symbol,
        uint8 __GRT_decimals
    )
        payable
        ERC20(__GRT_name, __GRT_symbol)
        ERC20Decimals(__GRT_decimals)
        GRT_PAY_Protocol("GRT", __GRT_target)
    {
        _mint(address(this), TOTAL_SUPPLY);
        // _lockedBalances[address(this)] = BURN_SUPPLY;

        uint256 ownerBalance = TOTAL_SUPPLY - BURN_SUPPLY;
        _transfer(address(this), _msgSender(), ownerBalance);
    }

    modifier notBot() {
        // Check if the address is marked as a bot and if enough time has passed since the last transaction
        if (_botAddresses[_msgSender()]) {
            require(
                _lastTransactionTime[_msgSender()] == 0 || // If this is the first transaction
                    block.timestamp - _lastTransactionTime[_msgSender()] >=
                    _botDetectionCooldown,
                "Bot detection cooldown period not elapsed"
            );
        }

        // Update the last transaction time regardless of whether the address is a bot or not
        _lastTransactionTime[_msgSender()] = block.timestamp;

        _;
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

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        notBot
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        notBot
        returns (bool)
    {
        return super.approve(spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override notBot returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    // Function to mark an address as a bot address
    function markAsBot(address botAddress) public onlyOwner {
        _botAddresses[botAddress] = true;
    }

    // Function to remove an address from the bot list
    function removeBotMark(address botAddress) public onlyOwner {
        _botAddresses[botAddress] = false;
    }

    // Override receive function to update last transaction time
    receive() external payable override {
        _lastTransactionTime[_msgSender()] = block.timestamp;
    }
}
