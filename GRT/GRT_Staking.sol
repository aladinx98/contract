// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GRT_Staking is ReentrancyGuard {
    address public owner;
    ERC20 immutable token;

    uint256 public constant maxReferralLimit = 1;
    uint256 public constant MinimumStakingAmount = 10 * (10**18);
    uint[1] public referralLevelRewards = [5];
    uint256 public totalStaked;
    uint256[] public rewardPercentage = [9, 18, 27, 36];
    uint public userCountInThePlatform;

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
    }//children of certain users 

    mapping(address => UserStaking[]) public userStaking;
    mapping(address => uint) public totalInvestedAmount;
    mapping(address => uint256) public userStakingCount;
    mapping(address => Rewards) public userReferralRewards;
    mapping(address => address) public parent;
    mapping(address=>mapping (uint => bool)) public withdrawalCompleted;
    mapping(address => User_children) private referrerToDirectChildren;
    mapping(address => User_children) private referrerToIndirectChildren;
    mapping(uint => mapping(address => address[])) public levelUsers;
    mapping(uint => mapping(address => uint)) public levelCountUsers;
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
    

    function stakeTokens(uint256 tokenAmount, uint256 stakingDuration, address referrer) public nonReentrant notBlacklisted(msg.sender) {
        require(stakingDuration == 30 || stakingDuration == 90 || stakingDuration == 180 || stakingDuration == 365, "Invalid staking duration");
        require(referrer != address(0), "Invalid referrer address");
        require(tokenAmount >= MinimumStakingAmount,"Amount needs to be atleast 100");
        require(msg.sender != owner,"owner cannot stake");

        if (parent[msg.sender] == address(0)) {
            parent[msg.sender] = referrer;
             setDirectAndIndirectUsers(msg.sender, referrer);
            setLevelUsers(msg.sender, referrer);

        } else {
            require(referrer == parent[msg.sender], "Referrer must be the same");
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
        for (uint256 i = 0; i < 1; i++) {
            if (newReferral == owner) {
                break;
            }
            address parentAddress = parent[newReferral];
            uint256 _rewardAmount = (referralLevelRewards[i] * tokenAmount) / 100;
            userReferralRewards[parentAddress].totalRewards += _rewardAmount;

            require(token.balanceOf(address(this)) >= _rewardAmount, "Not enough tokens in the contract");
                       // ... Previous code ...

            require(token.transfer(parentAddress, _rewardAmount), "Reward transfer failed");
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

    function withdraw(uint256 _index) public nonReentrant notBlacklisted(msg.sender) {
        require(_index < userStakingCount[msg.sender], "Invalid index");
        UserStaking storage staking = userStaking[msg.sender][_index];
        require(block.timestamp >= staking.stakingEndTime, "Staking period not yet ended");
        require(!withdrawalCompleted[msg.sender][_index], "Already withdrawn");

        uint256 rewardPercent = getRewardPercent(staking.stakingDuration);
        uint256 reward = (staking.stakedAmount * rewardPercent) / 100;
        uint256 totalAmount = staking.stakedAmount + reward;

        require(token.balanceOf(address(this)) >= totalAmount, "Insufficient contract balance");

        token.transfer(msg.sender, totalAmount);
        rewardAmount[msg.sender] += reward;
        withdrawalCompleted[msg.sender][_index] = true;
    }
      function getRewardPercent(uint256 duration) private pure returns (uint256) {
        if (duration == 30) return 9;
        if (duration == 90) return 18;
        if (duration == 180) return 27;
        if (duration == 365) return 36;
        return 0;
    }


    function totalReferralRewards(address user) public view returns (uint256) {
        return userReferralRewards[user].totalRewards;
    }

    function setDirectAndIndirectUsers(address _user, address _referrer) internal {
        referrerToDirectChildren[_referrer].child.push(_user);
        setIndirectUsersRecursive(_user, _referrer);
    }

    function setIndirectUsersRecursive(address _user, address _referrer) internal {
        if (_referrer != owner) {
            address presentReferrer = parent[_referrer];
            referrerToIndirectChildren[presentReferrer].child.push(_user);
            setIndirectUsersRecursive(_user, presentReferrer);
        }
    }

    function setLevelUsers(address _user, address _referrer) internal {
        address currentReferrer = _referrer;
        for (uint i = 1; i <= 1; i++) {
            levelUsers[i][currentReferrer].push(_user);
            levelCountUsers[i][currentReferrer]++;
            if (currentReferrer == owner) {
                break;
            } else {
                currentReferrer = parent[currentReferrer];
            }
        }
    }

    function showAllDirectChild(
        address user
    ) external view returns (address[] memory) {
        address[] memory children = referrerToDirectChildren[user].child;

        return children;
    }

   function showAllInDirectChild(
        address user
    ) external view returns (address[] memory) {
        address[] memory children = referrerToIndirectChildren[user].child;

        return children;
    }
    
    function totalRewardsReceived(address userAddress) public view returns (uint256) {
        require(userAddress != address(0), "Invalid address");

        uint256 totalRewards = rewardAmount[userAddress] + userReferralRewards[userAddress].totalRewards;
        return totalRewards;
    }

}