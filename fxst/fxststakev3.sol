// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FxstStakingV3 is ReentrancyGuard {
    IERC20 public fxstToken;
    address public owner;

    struct StakeInfo {
        uint256 amount;
        uint256 lockPeriod;
        uint256 rewardPercentage;
        uint256 totalReward;
        uint256 startTime;
        uint256 claimed;
        uint256 lastClaimTime;
        uint256 nextClaimTime;
        bool instantRewardClaimed;
        uint256 remainingReward;
        bool completed;
    }

    mapping(address => StakeInfo[]) public stakes;

    uint256 public constant LOCK_PERIOD_6_MONTHS = 6 * 60; // 18 minutes in seconds
    uint256 public constant LOCK_PERIOD_1_YEAR = 10 * 60; // 36 minutes in seconds
    uint256 public constant LOCK_PERIOD_2_YEARS = 20 * 60; // 73 minutes in seconds

    // Reward percentages
    uint256 public constant REWARD_6_MONTHS = 50;
    uint256 public constant REWARD_1_YEAR = 90;
    uint256 public constant REWARD_2_YEARS = 250;

    uint256 public constant INSTANT_RELEASE_PERCENTAGE = 40;
    uint256 public constant MONTHLY_RELEASE_PERCENTAGE = 10;

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockPeriod,
        uint256 index
    );
    event Claimed(address indexed user, uint256 amount, uint256 index);

    constructor(IERC20 _fxstToken) {
        fxstToken = _fxstToken;
        owner = msg.sender;
    }

    function stake(uint256 _amount, uint256 _lockPeriod) external nonReentrant {
        require(
            _lockPeriod == LOCK_PERIOD_6_MONTHS ||
                _lockPeriod == LOCK_PERIOD_1_YEAR ||
                _lockPeriod == LOCK_PERIOD_2_YEARS,
            "Invalid lock period"
        );
        require(_amount > 0, "Amount should be greater than 0");

        // Transfer tokens to the contract
        fxstToken.transferFrom(msg.sender, address(this), _amount);

        uint256 rewardPercentage;
        if (_lockPeriod == LOCK_PERIOD_6_MONTHS) {
            rewardPercentage = REWARD_6_MONTHS;
        } else if (_lockPeriod == LOCK_PERIOD_1_YEAR) {
            rewardPercentage = REWARD_1_YEAR;
        } else {
            rewardPercentage = REWARD_2_YEARS;
        }

        uint256 totalReward = (_amount * rewardPercentage) / 100;
        uint256 instantReward = (totalReward * INSTANT_RELEASE_PERCENTAGE) /
            100;
        uint256 remainingReward = totalReward - instantReward;

        uint256 tReward = _amount + totalReward;

        // Create a new stake in memory
        StakeInfo memory newStake = StakeInfo({
            amount: _amount,
            lockPeriod: _lockPeriod,
            rewardPercentage: rewardPercentage,
            totalReward: tReward,
            startTime: block.timestamp,
            claimed: 0,
            lastClaimTime: 0,
            nextClaimTime: block.timestamp + _lockPeriod,
            instantRewardClaimed: false,
            remainingReward: remainingReward,
            completed: false
        });

        // Push the newStake from memory to storage (to the blockchain)
        stakes[msg.sender].push(newStake);

        uint256 stakeIndex = stakes[msg.sender].length - 1;
        emit Staked(msg.sender, _amount, _lockPeriod, stakeIndex);
    }

    function claimReward(uint256 index) external nonReentrant {
        require(index < stakes[msg.sender].length, "Invalid stake index");

        StakeInfo storage userStake = stakes[msg.sender][index];
        require(userStake.amount > 0, "No stake found at this index");
        require(!userStake.completed, "Stake already completed");

        uint256 elapsed = block.timestamp - userStake.startTime;
        uint256 claimable = 0;

        // Calculate the total reward based on the staked amount and reward percentage
        uint256 reward = (userStake.amount * userStake.rewardPercentage) / 100;
        uint256 totalDistributable = userStake.amount + reward; // Total distributable (staked amount + reward)

        // Handle instant release of 40% after lockPeriod end
        if (!userStake.instantRewardClaimed && elapsed >= userStake.lockPeriod) {
            uint256 instantReward = (totalDistributable *
                INSTANT_RELEASE_PERCENTAGE) / 100;
            claimable += instantReward;
            userStake.instantRewardClaimed = true;

            // Update the remaining reward and timestamps after instant release
            userStake.remainingReward = totalDistributable - instantReward;
            userStake.lastClaimTime = block.timestamp;
            userStake.nextClaimTime = block.timestamp + 2 minutes; // Set next claim time for the 10% release

            // Mark the last claim time for the instant reward
            userStake.claimed += instantReward;
        }

        // Handle the release of 10% of the remaining reward every 2 minutes
        if (
            userStake.instantRewardClaimed &&
            block.timestamp >= userStake.nextClaimTime
        ) {
            uint256 monthlyReward = (totalDistributable *
                MONTHLY_RELEASE_PERCENTAGE) / 100;
            uint256 totalClaimable = monthlyReward;

            claimable += totalClaimable;
            userStake.nextClaimTime = block.timestamp + 2 minutes;
            userStake.claimed += totalClaimable;
        }

        // Ensure there is something to claim
        require(claimable > 0, "No rewards available to claim");

        // Transfer the claimable rewards to the user
        fxstToken.transfer(msg.sender, claimable);

        if (userStake.claimed == userStake.totalReward) {
            userStake.completed = true;
        }

        // Emit claim event
        emit Claimed(msg.sender, claimable, index);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 contractBalance = fxstToken.balanceOf(address(this));
        fxstToken.transfer(owner, contractBalance);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }
}
