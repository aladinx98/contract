// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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

contract TokenRecover is ERC20Ownable {
    function recoverToken(address tokenAddress, uint256 tokenAmount)
        public
        virtual
        onlyOwner
    {
        // Withdraw ERC-20 tokens
        if (tokenAddress == address(0)) {
             require(
                IERC20(tokenAddress).transfer(owner(), tokenAmount),
                "Owner cannot recover their own ERC-20 tokens"
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

contract ARZ is ERC20Decimals, ERC20Burnable, TokenRecover, Arzona {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant TOTAL_SUPPLY = 14e9 * (10**18);
    uint256 private constant INITIAL_LOCKED_AMOUNT = 10e9 * (10**18);
    uint256 private constant RELEASE_START = 5 minutes;
    uint256 private constant RELEASE_INTERVAL = 2 minutes;
    uint256 private constant RELEASE_AMOUNT = 5e6 * (10**18);
     uint256 private _releaseStartTime;
    uint256 public lastDistributionTime;
    uint256 private _nextDistributionTime;

    // Mapping to track locked balances for each address
    mapping(address => uint256) private _lockedBalances;
    mapping(address => uint256) private _lockReleaseTimes;
    EnumerableSet.AddressSet private _excludedFromDistribution;
    EnumerableSet.AddressSet private _holders;

    constructor(
        address __ARZ_target,
        string memory __ARZ_name,
        string memory __ARZ_symbol,
        uint8 __ARZ_decimals
    )
        payable
        ERC20(__ARZ_name, __ARZ_symbol)
        ERC20Decimals(__ARZ_decimals)
        Arzona("ARZ", __ARZ_target)
    {
        _mint(address(this), TOTAL_SUPPLY);
        _lockedBalances[address(this)] = INITIAL_LOCKED_AMOUNT;
        _releaseStartTime = block.timestamp + RELEASE_START;

        // Transfer 4 billion tokens to the owner's wallet
        uint256 ownerBalance = TOTAL_SUPPLY - INITIAL_LOCKED_AMOUNT;
        _transfer(address(this), _msgSender(), ownerBalance);
        _holders.add(_msgSender());
    }

    function excludeFromDistribution(address _address) public onlyOwner {
        _excludedFromDistribution.add(_address);
    }

        // Function to get all holders and their balances
    function getAllHoldersWithBalances() public view returns (address[] memory, uint256[] memory) {
        uint256 length = _holders.length();
        address[] memory tHolders = new address[](length);
        uint256[] memory tBalances = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            address tHolder = _holders.at(i);
            if (!isExcludedFromDistribution(tHolder) && tHolder != owner() && tHolder != address(0)) {
            tHolders[i] = tHolder;
            tBalances[i] = balanceOf(tHolder);
            }
        }
        
        return (tHolders, tBalances);
    }

 function viewTokenHoldersWithBalances() external view returns (address[] memory, uint256[] memory, uint256) {
    (address[] memory holders, uint256[] memory balances) = getAllHoldersWithBalances();
    uint256 totalBalance = 0;

    // Calculate total balance
    for (uint256 i = 0; i < holders.length; i++) {
        totalBalance += balances[i];
    }

    return (holders, balances, totalBalance);
}

    // Function to distribute released tokens to all holders according to their holdings
        function distributeReleasedTokens() public {
        if (block.timestamp < _releaseStartTime) {
        revert("Token release has not started yet");
    }
        if (block.timestamp < _nextDistributionTime) {
        revert("Distribution interval not reached");
    }
        uint256 totalSupplyWithoutLocked = totalSupply() - INITIAL_LOCKED_AMOUNT;
        uint256 tokensToRelease = RELEASE_AMOUNT;
        require(tokensToRelease <= totalSupplyWithoutLocked, "Insufficient circulating supply");

        (address[] memory holders, uint256[] memory balances) = getAllHoldersWithBalances();
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < holders.length; i++) {
            if (!isExcludedFromDistribution(holders[i]) && holders[i] != owner() && holders[i] != address(0)) {
                totalBalance += balances[i];
            }
        }
        require(totalBalance > 0, "No balance to distribute");

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            if (!isExcludedFromDistribution(holder) && holder != owner() && holder != address(0)) {
                uint256 userProportion = (balances[i] * 1e18) / totalBalance;
                uint256 distributionAmount = (userProportion * tokensToRelease) / 1e18;
                _transfer(address(this), holder, distributionAmount);
            }
        }

        lastDistributionTime = block.timestamp;
        _nextDistributionTime = lastDistributionTime + RELEASE_INTERVAL;
    }


    function isExcludedFromDistribution(address _address) public view returns (bool) {
        return _excludedFromDistribution.contains(_address);
    }

    // Function to burn remaining locked tokens after distribution
    function burnLockedTokens() public onlyOwner {
        _burn(address(this), balanceOf(address(this)));
    }

    // Override transfer function to track token holders
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        super._transfer(sender, recipient, amount);
        if (amount > 0) {
            _holders.add(recipient);
        }
    }

    // Override decimals function
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
