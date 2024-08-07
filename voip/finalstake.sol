// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title StakingContract
 * @dev This contract represents a staking system with different plans, incorporating ReentrancyGuard.
 */
contract Staking is ReentrancyGuard {
    address public owner;
    ERC20 immutable token;

    uint256 public constant MinimumStakingAmount = 100 * (10**18);
    uint256 public multiplier = 10 * 10**18;
    uint256 public totalStaked;
    uint256[] public rewardPercentage = [36, 72, 108, 144];
    uint public userCountInThePlatform;

    struct UserStaking {
        uint256 stakedAmount;
        uint256 stakingDuration;
        uint256 stakingEndTime;
        uint256 startDate;
    }

    mapping(address => UserStaking[]) public userStaking;
    mapping(address => uint) public totalInvestedAmount;
    mapping(address => uint256) public userStakingCount;
    mapping(address => mapping(uint => bool)) public withdrawalCompleted;
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

    function stakeTokens(uint256 tokenAmount, uint256 stakingDuration) public nonReentrant notBlacklisted(msg.sender) {
         require(stakingDuration == 56 || stakingDuration == 100 || stakingDuration == 180 || stakingDuration == 360, "Invalid staking duration");
        require(tokenAmount % multiplier == 0, "Amount must be a multiple of $10");
        require(tokenAmount >= MinimumStakingAmount, "Amount needs to be at least 100");
        require(msg.sender != owner, "Owner cannot stake");

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
        uint256 reward = (staking.stakedAmount * rewardPercent * staking.stakingDuration) / (100 * 365);
        uint256 totalAmount = staking.stakedAmount + reward;

        require(token.balanceOf(address(this)) >= totalAmount, "Insufficient contract balance");

        token.transfer(msg.sender, totalAmount);
        rewardAmount[msg.sender] += reward;
        withdrawalCompleted[msg.sender][_index] = true;
    }

    function getRewardPercent(uint256 duration) private pure returns (uint256) {
        if (duration == 56) return 36;
        if (duration == 100) return 72;
        if (duration == 180) return 108;
        if (duration == 360) return 144;
        return 0;
    }

    /**
     * @dev Calculate the total rewards received by a user including staking rewards.
     * @param userAddress The address of the user.
     * @return Total rewards received by the user.
     */
    function totalRewardsReceived(address userAddress) public view returns (uint256) {
        require(userAddress != address(0), "Invalid address");

        uint256 totalRewards = rewardAmount[userAddress];
        return totalRewards;
    }
}