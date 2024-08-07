//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

contract ARZ_Presale {
    IERC20 public token;
    uint256 public tokensPerUSDT;
    address public preSaleOwner;
    uint256 public totalFundsRaised;
    uint256 public totalTokenSold;
    uint256 public constant MinBuyAmount = 100 * (10**18);

    struct User_children {
        address[] children;
    }

    struct User_levels {
        mapping(uint256 => address[]) levelUsers;
        mapping(uint256 => uint256) levelCountUsers;
    }

    mapping(address => address) public parent;
    mapping(address => User_children) private referrerToDirectChildren;
    mapping(address => User_children) private referrerToIndirectChildren;
    mapping(address => User_levels) private userLevels;
    mapping(address => uint256) public maxTierReferralCounts;
    mapping(address => bool) public userValidation;

    // Events
    event FundsRaised(uint256 amount);

    struct Buyer {
        address referrer;
        uint256 totalPurchased;
        uint256 totalReferralRewards;
    }

    mapping(address => Buyer) public buyers;

    IERC20 USDT = IERC20(0xf3d74182247eF963E0De37E3F2e174E98dCBfAE1);

    constructor(
        address _tokenAddress,
        address _owner,
        uint256 _tokensPerUSDT
    ) {
        token = IERC20(_tokenAddress);
        preSaleOwner = _owner;
        tokensPerUSDT = _tokensPerUSDT;
        totalFundsRaised = 0;
        totalTokenSold = 0;
    }

    modifier onlyOwner() {
        require(
            msg.sender == preSaleOwner,
            "ONLY_OWNER_CAN_ACCESS_THIS_FUNCTION"
        );
        _;
    }

    function updateRate(uint256 newTokensPerUSDT) public onlyOwner {
        tokensPerUSDT = newTokensPerUSDT;
    }

    function endPreSale() public onlyOwner {
        uint256 contractTokenBalance = token.balanceOf(address(this));
        token.transfer(msg.sender, contractTokenBalance);
    }

    function setDirectAndIndirectUsers(address _referral, address _referrer)
        private
    {
        referrerToDirectChildren[_referrer].children.push(_referral);
        address _indirectReferrer = parent[_referrer];
        while (_indirectReferrer != address(0)) {
            referrerToIndirectChildren[_indirectReferrer].children.push(
                _referral
            );
            _indirectReferrer = parent[_indirectReferrer];
        }
    }

    function setLevelUsers(address _referral, address _referrer) private {
        uint256 userLevel = getUserLevel(_referrer);
        for (uint256 i = userLevel; i < 25; i++) {
            userLevels[_referral].levelUsers[i].push(_referrer);
            userLevels[_referral].levelCountUsers[i]++;
            _referrer = parent[_referrer];
            if (_referrer == address(0)) break;
        }
    }

    function getUserLevel(address _user) private view returns (uint256) {
        uint256 level = 0;
        address _parent = parent[_user];
        while (_parent != address(0)) {
            level++;
            _parent = parent[_parent];
        }
        return level;
    }

function buyWithUSDT(address _referrer, uint256 _USDTAmount) public {
    require(_USDTAmount >= MinBuyAmount, "USDT amount must be at least 100");

    address _buyer = msg.sender;

    // Set parent if not set already
    if (parent[_buyer] == address(0)) {
        require(!userValidation[_buyer], "User already exists");
        parent[_buyer] = _referrer;
        setDirectAndIndirectUsers(_buyer, _referrer);
        setLevelUsers(_buyer, _referrer);
        userValidation[_buyer] = true;

        // Initialize buyer information
        buyers[_buyer] = Buyer(_referrer, 0, 0);
    } else {
        require(_referrer == parent[_buyer], "Referrer must be the same");
    }

    // Calculate token amount based on tokensPerUSDT rate
    uint256 tokenAmount = _USDTAmount * tokensPerUSDT;

    // Transfer USDT from buyer to contract
    require(USDT.transferFrom(_buyer, address(this), _USDTAmount), "USDT transfer to contract failed");

    // Calculate referral rewards and update buyer's total referral rewards
    uint256 referralReward = (_USDTAmount * 20) / 100;

    // Update buyer's total purchased amount
    buyers[_buyer].totalPurchased += tokenAmount;

    // Transfer 80% of the USDT amount to the presale owner
    uint256 presaleAmount = (_USDTAmount * 80) / 100;
    require(USDT.transfer(preSaleOwner, presaleAmount), "USDT transfer to presale owner failed");

    // Distribute 20% of the USDT amount to parent users
    distributeToParentUsers(_buyer, referralReward);

    // Transfer tokens to the buyer
    require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient token balance in contract");
    require(token.transfer(_buyer, tokenAmount), "Token transfer failed");

    // Update total funds raised & total token sold
    totalTokenSold += tokenAmount;
    totalFundsRaised += _USDTAmount;

    // Emit event
    emit FundsRaised(_USDTAmount);
}


    function distributeToParentUsers(address _buyer, uint256 _referralReward)
        private
    {
        address _referrer = parent[_buyer];
        uint256 remainingReward = _referralReward;
        for (uint256 i = 0; i < 25; i++) {
            if (_referrer == address(0)) {
                break; // Stop if no referrer or reaches preSaleOwner
            }
            uint256 referrerReward = (remainingReward *
                getReferralRewardPercentage(i)) / 10000;
            require(
                USDT.transfer(_referrer, referrerReward),
                "USDT transfer to parent failed"
            );
            buyers[_referrer].totalReferralRewards +=referrerReward;
            _referrer = parent[_referrer];
        }
    }

function getReferralRewardPercentage(uint256 level)
    internal
    pure
    returns (uint256)
{
    if (level == 0) return 4000; // 40%
    if (level == 1) return 2000; // 20%
    if (level == 2) return 1000; // 10%
    if (level == 3) return 500; // 5%
    if (level == 4) return 250; // 2.5%
    if (level == 5 || level == 6 || level == 7 || level == 8 || level == 9 || level == 10 || level == 11 || level == 12 || level == 13 || level == 14 ) return 125; // 1.25%
    if (level == 15 || level == 16 || level == 17 || level == 18 || level == 19 || level == 20 || level == 21 || level == 22 || level == 23 || level == 24 || level == 25) return 100; // 1%
    return 0; // Default percentage, adjust as needed
}

    function getReferrer(address account) internal view returns (address) {
        return buyers[account].referrer;
    }

    function getReferralAddresses(address _referrer) external view returns (address[] memory) {
    uint256 referralCount = 0;

    // Count the number of referrals
    for (uint256 i = 0; i < totalFundsRaised; i++) {
        if (parent[_referrer] == msg.sender) {
            referralCount++;
        }
        _referrer = parent[_referrer];
        if (_referrer == address(0)) {
            break;
        }
    }

    address[] memory referrals = new address[](referralCount);
    _referrer = parent[_referrer]; // Reset the _referrer

    // Store the referral addresses
    for (uint256 i = 0; i < referralCount; i++) {
        referrals[i] = _referrer;
        _referrer = parent[_referrer];
        if (_referrer == address(0)) {
            break;
        }
    }

    return referrals;
}


    function recoverTokens(address tokenToRecover) public onlyOwner {
        IERC20 tokenContract = IERC20(tokenToRecover);
        uint256 contractTokenBalance = tokenContract.balanceOf(address(this));
        require(contractTokenBalance > 0, "No tokens to recover");

        bool sent = tokenContract.transfer(msg.sender, contractTokenBalance);
        require(sent, "Failed to recover tokens");
    }
}