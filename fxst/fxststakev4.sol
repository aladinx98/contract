// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Staking is ReentrancyGuard {
    address public owner;
    ERC20 immutable fxstToken;

    uint256 public constant maxReferralLimit = 3;
    uint256 public constant MinimumStakingAmount = 100 * (10**6);
    uint256 public multiplier = 10 * 10**6;
    uint256[3] public referralLevelRewards = [5, 3, 2];
    uint256 public totalStaked;
    uint256 public totalWithdraw;
    uint256 public totalRewardDistribute;
    uint256[] public rewardPercentage = [9, 18, 27];
    uint256 public userCountInThePlatform;

    uint256 public constant INSTANT_RELEASE_PERCENTAGE = 40;
    uint256 public constant MONTHLY_RELEASE_PERCENTAGE = 10;

    struct UserStaking {
        uint256 stakedAmount;
        uint256 stakingDuration;
        uint256 stakingEndTime;
        uint256 startDate;
        uint256 rewardPercent;
        uint256 totalReward;
        uint256 claimed;
        uint256 lastClaimTime;
        uint256 nextClaimTime;
        bool instantRewardClaimed;
        uint256 remainingReward;
        bool completed;
    }

    struct Rewards {
        uint256 totalRewards;
    }

    struct User_children {
        address[] child;
    } //children of certain users

    mapping(address => uint256) public usertotalReward;

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
    event Claimed(address indexed user, uint256 amount, uint256 index);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }
    modifier notBlacklisted(address _user) {
        require(!blacklist[_user], "User is blacklisted");
        _;
    }

    constructor(address _tokenAddress) {
        fxstToken = ERC20(_tokenAddress);
        owner = msg.sender;
    }

    function stakeTokens(
        uint256 tokenAmount,
        uint256 stakingDuration,
        address referrer
    ) public nonReentrant notBlacklisted(msg.sender) {
        require(
            stakingDuration == 180 ||
                stakingDuration == 365 ||
                stakingDuration == 730,
            "Invalid staking duration"
        );
        require(referrer != address(0), "Invalid referrer address");
        require(
            tokenAmount % multiplier == 0,
            "Amount must be a multiple of $10"
        );
        require(
            tokenAmount >= MinimumStakingAmount,
            "Amount needs to be atleast 100"
        );
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

        uint256 rewardPer = getRewardPercent(stakingDuration);

        uint256 totalRewardAmount = (tokenAmount * rewardPer) / 100;

        uint256 instantReward = (totalRewardAmount *
            INSTANT_RELEASE_PERCENTAGE) / 100;
        uint256 remainingReward = totalRewardAmount - instantReward;

        UserStaking memory newStake = UserStaking({
            stakedAmount: tokenAmount,
            stakingDuration: stakingDuration,
            stakingEndTime: stakingEndTime,
            startDate: startDate,
            rewardPercent: rewardPer,
            totalReward: tokenAmount + totalRewardAmount,
            claimed: 0,
            lastClaimTime: 0,
            nextClaimTime: stakingEndTime,
            instantRewardClaimed: false,
            remainingReward: remainingReward,
            completed: false
        });

        userStaking[msg.sender].push(newStake);
        userStakingCount[msg.sender]++;
        totalInvestedAmount[msg.sender] += tokenAmount;
        totalStaked += tokenAmount;

        if (!userValidation[msg.sender]) {
            userCountInThePlatform++;
            userValidation[msg.sender] = true;
        }

        fxstToken.transferFrom(msg.sender, address(this), tokenAmount);

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
                fxstToken.balanceOf(address(this)) >= _rewardAmount,
                "Not enough tokens in the contract"
            );
            // ... Previous code ...

            require(
                fxstToken.transfer(parentAddress, _rewardAmount),
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

    function addToBlacklist(address user) public onlyOwner {
        blacklist[user] = true;
    }

    function removeFromBlacklist(address user) public onlyOwner {
        blacklist[user] = false;
    }

    function withdraw(uint256 _index)
        public
        nonReentrant
        notBlacklisted(msg.sender)
    {
        require(_index < userStakingCount[msg.sender], "Invalid index");
        UserStaking storage userStake = userStaking[msg.sender][_index];
        require(
            block.timestamp >= userStake.stakingEndTime,
            "Staking period not yet ended"
        );
        require(!userStake.completed, "Stake already completed");

        uint256 elapsed = block.timestamp - userStake.startDate;
        uint256 claimable = 0;

        // Calculate the total reward based on the staked amount and reward percentage
        uint256 reward = (userStake.stakedAmount * userStake.rewardPercent) /
            100;
        uint256 totalDistributable = userStake.stakedAmount + reward; // Total distributable (staked amount + reward)

        // Handle instant release of 40% after lockPeriod end
        if (
            !userStake.instantRewardClaimed &&
            elapsed >= userStake.stakingDuration
        ) {
            uint256 instantReward = (totalDistributable *
                INSTANT_RELEASE_PERCENTAGE) / 100;
            claimable += instantReward;
            userStake.instantRewardClaimed = true;

            // Update the remaining reward and timestamps after instant release
            userStake.remainingReward = totalDistributable - instantReward;
            userStake.lastClaimTime = block.timestamp;
            userStake.nextClaimTime = block.timestamp + 30 days; // Set next claim time for the 10% release

            // Mark the last claim time for the instant reward
            userStake.claimed += instantReward;
        }

        // Handle the release of 10% of the remaining reward every 30 days
        if (
            userStake.instantRewardClaimed &&
            block.timestamp >= userStake.nextClaimTime
        ) {
            uint256 monthlyReward = (totalDistributable *
                MONTHLY_RELEASE_PERCENTAGE) / 100;
            uint256 totalClaimable = monthlyReward;

            claimable += totalClaimable;
            userStake.nextClaimTime = block.timestamp + 30 days;
            userStake.claimed += totalClaimable;
        }

        // Ensure there is something to claim
        require(claimable > 0, "No rewards available to claim");

        // Transfer the claimable rewards to the user
        fxstToken.transfer(msg.sender, claimable);

        totalRewardDistribute += claimable;
        usertotalReward[msg.sender] += claimable;

        if (userStake.claimed == userStake.totalReward) {
            userStake.completed = true;
        }

        // Emit claim event
        emit Claimed(msg.sender, claimable, _index);
    }

    function getRewardPercent(uint256 duration) private pure returns (uint256) {
        if (duration == 30) return 9;
        if (duration == 45) return 18;
        if (duration == 60) return 27;
        if (duration == 75) return 36;
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

        function emergencyWithdraw(
        address _tokenAddress,
        address _walletAddress,
        uint256 _amount
    ) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient contract balance"
        );

        token.transfer(_walletAddress, _amount);
        totalWithdraw += _amount;
    }
}
