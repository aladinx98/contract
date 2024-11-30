// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiTokenLockAndVesting is Ownable {
    struct Lock {
        uint256 amount; // Amount of tokens locked
        uint256 lockEnd; // Lock end timestamp
        uint256 vestingPeriod; // Vesting period in seconds
        uint256 vestingPercent; // Percent released per interval (0-100)
        uint256 claimedAmount; // Amount already claimed
        uint256 nextClaimDate;
    }

    // Mapping: token address => user address => list of locks
    mapping(address => Lock[]) public locks;

    event TokensLocked(
        address indexed token,
        address indexed user,
        uint256 indexed lockId,
        uint256 amount,
        uint256 lockEnd,
        uint256 vestingPeriod,
        uint256 vestingPercent
    );
    event TokensClaimed(
        address indexed token,
        address indexed user,
        uint256 indexed lockId,
        uint256 claimedAmount,
        uint256 nextClaimDate
    );

    /**
     * @dev Constructor to initialize the contract.
     * Pass the `initialOwner` address to the `Ownable` constructor.
     */
    constructor(address initialOwner) Ownable(initialOwner) {}

    /**
     * @dev Lock tokens with vesting schedule.
     */
    function lockTokens(
        address _token,
        uint256 _amount,
        uint256 _lockEnd,
        uint256 _vestingPeriod,
        uint256 _vestingPercent
    ) external {
        require(_amount > 0, "Amount must be greater than zero");
        require(_lockEnd > block.timestamp, "Lock end must be in the future");
        require(
            _vestingPercent > 0 && _vestingPercent <= 100,
            "Vesting percent must be between 1 and 100"
        );
        require(_vestingPeriod > 0, "Vesting period must be greater than zero");

        IERC20 token = IERC20(_token);

        uint256 userBalance = token.balanceOf(msg.sender);
        uint256 allowance = token.allowance(msg.sender, address(this));

        require(userBalance >= _amount, "Insufficient token balance");
        require(allowance >= _amount, "Insufficient allowance");

        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );

        uint256 nextClaimDate = _lockEnd + _vestingPeriod;

        locks[msg.sender].push(
            Lock({
                amount: _amount,
                lockEnd: _lockEnd,
                vestingPeriod: _vestingPeriod,
                vestingPercent: _vestingPercent,
                claimedAmount: 0,
                nextClaimDate: nextClaimDate
            })
        );

        emit TokensLocked(
            _token,
            msg.sender,
            locks[msg.sender].length - 1,
            _amount,
            _lockEnd,
            _vestingPeriod,
            _vestingPercent
        );
    }

    /**
     * @dev Withdraw available tokens for a specific lock by ID.
     */
    function withdrawTokens(address _token, uint256 _lockId) external {
        require(_lockId < locks[msg.sender].length, "Invalid lock ID");

        Lock storage userLock = locks[msg.sender][_lockId];

        uint256 claimable = _calculateClaimable(userLock);
        require(claimable > 0, "No tokens available to claim");

        userLock.claimedAmount += claimable;

        // Update the next claim date
        if (userLock.claimedAmount < userLock.amount) {
            userLock.nextClaimDate += userLock.vestingPeriod;
        } else {
            userLock.nextClaimDate = 0; // No further claims
        }

        IERC20 token = IERC20(_token);
        require(token.transfer(msg.sender, claimable), "Token transfer failed");

        emit TokensClaimed(_token, msg.sender, _lockId, claimable, userLock.nextClaimDate);
    }

    /**
     * @dev Get the total claimable tokens for a specific lock.
     */
    function _calculateClaimable(Lock memory userLock)
        internal
        view
        returns (uint256)
    {
        if (block.timestamp < userLock.lockEnd) {
            return 0;
        }

        uint256 totalElapsedTime = block.timestamp - userLock.lockEnd;
        uint256 totalVestingIntervals = totalElapsedTime /
            userLock.vestingPeriod;
        uint256 totalClaimablePercent = totalVestingIntervals *
            userLock.vestingPercent;

        if (totalClaimablePercent > 100) {
            totalClaimablePercent = 100;
        }

        uint256 totalClaimableAmount = (userLock.amount *
            totalClaimablePercent) / 100;
        uint256 claimable = totalClaimableAmount - userLock.claimedAmount;

        return claimable;
    }

    /**
     * @dev Get all locks for a specific user and token.
     */
    function getLocks(address _user)
        external
        view
        returns (Lock[] memory)
    {
        return locks[_user];
    }

    function getNextClaimDate(address _user, uint256 _lockId)
        external
        view
        returns (uint256)
    {
        require(_lockId < locks[_user].length, "Invalid lock ID");
        return locks[_user][_lockId].nextClaimDate;
    }
}
