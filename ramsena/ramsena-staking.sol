// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RamsenaStake is ReentrancyGuard {
    address public owner;
    ERC20 immutable token;

    uint256 public constant maxReferralLimit = 3;
    // uint256 public constant MinimumStakingAmount = 100 * (10**18);
    uint256 public multiplier = 10 * (10**18);
    uint256[3] public referralLevelRewards = [3, 2, 1];
    uint256 public totalStaked;
    uint256[] public rewardPercentage = [18, 40, 80, 160];
    uint256 public userCountInThePlatform;

    struct UserStaking {
        uint256 stakedAmount;
        uint256 stakingDuration;
        uint256 stakingEndTime;
        uint256 startDate;
    }

    struct Rewards {
        uint256 totalRewards;
    }

    struct User_children {
        address[] child;
    } //children of certain users

    mapping(address => UserStaking[]) public userStaking;
    mapping(address => uint256) public totalInvestedAmount;
    mapping(address => uint256) public userStakingCount;
    mapping(address => Rewards) public userReferralRewards;
    mapping(address => address) public parent;
    mapping(address => mapping(uint256 => bool)) public withdrawalCompleted;
    mapping(address => User_children) private referrerToDirectChildren;
    mapping(address => User_children) private referrerToIndirectChildren;
    mapping(uint256 => mapping(address => address[])) public levelUsers;
    mapping(uint256 => mapping(address => uint256)) public levelCountUsers;
    mapping(address => uint256) public maxTierReferralCounts;
    mapping(address => uint256) public rewardAmount;
    mapping(address => bool) public userValidation;
    mapping(address => bool) public blacklist;

    event TokensStaked(address indexed user, uint256 amount, uint256 endTime);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }
    modifier notBlacklisted(address _user) {
        require(!blacklist[_user], "User is blacklisted");
        _;
    }

    constructor(address _tokenAddress) {
        token = ERC20(_tokenAddress);
        owner = msg.sender;
    }

    function stakeTokens(
        uint256 tokenAmount,
        uint256 stakingDuration,
        address referrer
    ) public nonReentrant notBlacklisted(msg.sender) {
        require(
            stakingDuration == 360 ||
                stakingDuration == 720 ||
                stakingDuration == 1080 ||
                stakingDuration == 1440,
            "Invalid staking duration"
        );
        require(referrer != address(0), "Invalid referrer address");
        require(
            tokenAmount % multiplier == 0,
            "Amount must be a multiple of $10"
        );
        // require(
        //     tokenAmount >= MinimumStakingAmount,
        //     "Amount needs to be atleast 100"
        // );
        require(msg.sender != owner, "owner cannot stake");

        if (parent[msg.sender] == address(0)) {
            parent[msg.sender] = referrer;
            setDirectAndIndirectUsers(msg.sender, referrer);
            setLevelUsers(msg.sender, referrer);
        } else {
            require(
                referrer == parent[msg.sender],
                "Referrer must be the same"
            );
        }

        uint256 stakingEndTime = block.timestamp + stakingDuration * 1 days;
        uint256 startDate = block.timestamp;

        UserStaking memory newStake = UserStaking({
            stakedAmount: tokenAmount,
            stakingDuration: stakingDuration,
            stakingEndTime: stakingEndTime,
            startDate: startDate
        });

        userStaking[msg.sender].push(newStake);
        userStakingCount[msg.sender]++;
        totalInvestedAmount[msg.sender] += tokenAmount;
        totalStaked += tokenAmount;

        if (!userValidation[msg.sender]) {
            userCountInThePlatform++;
            userValidation[msg.sender] = true;
        }

        token.transferFrom(msg.sender, address(this), tokenAmount);

        address newReferral = msg.sender;
        for (uint256 i = 0; i < 3; i++) {
            if (newReferral == owner) {
                break;
            }
            address parentAddress = parent[newReferral];
            uint256 _rewardAmount = (referralLevelRewards[i] * tokenAmount) /
                100;
            userReferralRewards[parentAddress].totalRewards += _rewardAmount;

            require(
                token.balanceOf(address(this)) >= _rewardAmount,
                "Not enough tokens in the contract"
            );

            require(
                token.transfer(parentAddress, _rewardAmount),
                "Reward transfer failed"
            );
            newReferral = parentAddress;
        }

        emit TokensStaked(msg.sender, tokenAmount, stakingEndTime);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner address");
        owner = newOwner;
    }

    function addToBlacklist(address[] memory users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            blacklist[users[i]] = true;
        }
    }

    function removeFromBlacklist(address[] memory users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            blacklist[users[i]] = false;
        }
    }

    function withdraw(uint256 _index)
        public
        nonReentrant
        notBlacklisted(msg.sender)
    {
        require(_index < userStakingCount[msg.sender], "Invalid index");
        UserStaking storage staking = userStaking[msg.sender][_index];
        require(
            block.timestamp >= staking.stakingEndTime,
            "Staking period not yet ended"
        );
        require(!withdrawalCompleted[msg.sender][_index], "Already withdrawn");

        uint256 rewardPercent = getRewardPercent(staking.stakingDuration);
        uint256 reward = (staking.stakedAmount * rewardPercent) / 100;
        uint256 totalAmount = staking.stakedAmount + reward;

        require(
            token.balanceOf(address(this)) >= totalAmount,
            "Insufficient contract balance"
        );

        token.transfer(msg.sender, totalAmount);
        rewardAmount[msg.sender] += reward;
        withdrawalCompleted[msg.sender][_index] = true;
    }

    function getRewardPercent(uint256 duration) private pure returns (uint256) {
        if (duration == 360) return 18;
        if (duration == 720) return 40;
        if (duration == 1080) return 80;
        if (duration == 1440) return 160;
        return 0;
    }

    function totalReferralRewards(address user) public view returns (uint256) {
        return userReferralRewards[user].totalRewards;
    }

    function setDirectAndIndirectUsers(address _user, address _referrer)
        internal
    {
        referrerToDirectChildren[_referrer].child.push(_user);
        setIndirectUsersRecursive(_user, _referrer);
    }

    function setIndirectUsersRecursive(address _user, address _referrer)
        internal
    {
        if (_referrer != owner) {
            address presentReferrer = parent[_referrer];
            referrerToIndirectChildren[presentReferrer].child.push(_user);
            setIndirectUsersRecursive(_user, presentReferrer);
        }
    }

    function setLevelUsers(address _user, address _referrer) internal {
        address currentReferrer = _referrer;
        for (uint256 i = 1; i <= 3; i++) {
            levelUsers[i][currentReferrer].push(_user);
            levelCountUsers[i][currentReferrer]++;
            if (currentReferrer == owner) {
                break;
            } else {
                currentReferrer = parent[currentReferrer];
            }
        }
    }

    function showAllDirectChild(address user)
        external
        view
        returns (address[] memory)
    {
        address[] memory children = referrerToDirectChildren[user].child;

        return children;
    }

    function showAllInDirectChild(address user)
        external
        view
        returns (address[] memory)
    {
        address[] memory children = referrerToIndirectChildren[user].child;

        return children;
    }

    function totalRewardsReceived(address userAddress)
        public
        view
        returns (uint256)
    {
        require(userAddress != address(0), "Invalid address");

        uint256 totalRewards = rewardAmount[userAddress] +
            userReferralRewards[userAddress].totalRewards;
        return totalRewards;
    }

    function withdrawRemainingTokens() external onlyOwner {
        uint256 remainingBalance = token.balanceOf(address(this));
        require(remainingBalance > 0, "No tokens to withdraw");

        token.transfer(owner, remainingBalance);
    }
}