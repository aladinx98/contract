// SPDX-License-Identifier: MIT

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

contract BattleKoin_Presale {
    IERC20 public token;
    IERC20 public USDT = IERC20(0x1e7F9B86658dCfE82F8194F8F983566132C5C6A7);
    IERC20 public MNT = IERC20(0xAa5A191Aa8EF046744E1Fc3bD0E0b19dAA60A408);

    uint256 public totalTokensSold;
    uint256 public totalUSDTCollected;
    uint256 public tokensPerUSDT;
    uint256 public totalMNTCollected;
    uint256 public tokensPerMNT;
    address public presaleOwner;

    struct Purchase {
        uint256 amount;
        uint256 purchaseTimestamp;
        uint256 claimDate;
        uint256 withdrawn;
        uint256 withdrawCount;
        uint256 withdrawableBalance;
        uint256 nextClaimDate;
        bool isWithdrawCompleted;
    }

    mapping(address => Purchase[]) public purchases;
    mapping(address => uint256) public purchasesCount;
    mapping(address => mapping(uint => bool)) public withdrawalCompleted;

    constructor(
        address _tokenAddress,
        address _owner,
        uint256 _tokensPerUSDT,
        uint256 _tokensPerMNT
    ) {
        token = IERC20(_tokenAddress);
        presaleOwner = _owner;
        tokensPerUSDT = _tokensPerUSDT;
        tokensPerMNT = _tokensPerMNT;
    }

    modifier onlyOwner() {
        require(
            msg.sender == presaleOwner,
            "ONLY_OWNER_CAN_ACCESS_THIS_FUNCTION"
        );
        _;
    }

    function updateRate(uint256 newTokensPerUSDT, uint256 newTokensPerMNT) public onlyOwner {
        tokensPerUSDT = newTokensPerUSDT;
        tokensPerMNT = newTokensPerMNT;
    }

    function endPreSale() public onlyOwner {
        uint256 contractTokenBalance = token.balanceOf(address(this));
        token.transfer(msg.sender, contractTokenBalance);
    }

    function buyWithMNT(uint256 _MNTAmount) public {
        uint256 tokenAmount = (_MNTAmount * tokensPerMNT) / 10000;

        require(
            token.balanceOf(address(this)) >= tokenAmount,
            "INSUFFICIENT_BALANCE_IN_CONTRACT"
        );

        // Transfer MNT from buyer to owner
        MNT.transferFrom(msg.sender, presaleOwner, _MNTAmount);

        // Record the purchase
        purchases[msg.sender].push(
            Purchase({
                amount: tokenAmount,
                purchaseTimestamp: block.timestamp,
                claimDate: block.timestamp + 2 minutes,
                withdrawn: 0,
                withdrawCount: 0,
                withdrawableBalance: tokenAmount,
                nextClaimDate: block.timestamp + 5 minutes,
                isWithdrawCompleted: false
            })
        );

        purchasesCount[msg.sender]++;
        // Update totals
        totalTokensSold += tokenAmount;
        totalMNTCollected += _MNTAmount;
    }

    function buyWithUSDT(uint256 _USDTAmount) public {
        uint256 tokenAmount = (_USDTAmount * tokensPerUSDT) / 10000;

        require(
            token.balanceOf(address(this)) >= tokenAmount,
            "INSUFFICIENT_BALANCE_IN_CONTRACT"
        );

        // Transfer USDT from buyer to owner
        USDT.transferFrom(msg.sender, presaleOwner, _USDTAmount);

        // Record the purchase
        purchases[msg.sender].push(
            Purchase({
                amount: tokenAmount,
                purchaseTimestamp: block.timestamp,
                claimDate: block.timestamp + 2 minutes,
                withdrawn: 0,
                withdrawCount: 0,
                withdrawableBalance: tokenAmount,
                nextClaimDate: block.timestamp + 5 minutes,
                isWithdrawCompleted: false
            })
        );

        purchasesCount[msg.sender]++;
        // Update totals
        totalTokensSold += tokenAmount;
        totalUSDTCollected += _USDTAmount;
    }

    function withdrawTokens(uint256 index) public {
        require(index < purchases[msg.sender].length, "INVALID_PURCHASE_INDEX");

        Purchase storage purchase = purchases[msg.sender][index];

        // Ensure tokens are not withdrawn before the claim date
        require(block.timestamp >= purchase.claimDate, "TOKENS_LOCKED");

        // Check if all tokens have already been claimed
        require(
            purchase.withdrawn < purchase.amount,
            "ALL_TOKENS_ALREADY_CLAIMED"
        );

        uint256 elapsedIntervals = (block.timestamp - purchase.claimDate) /
            3 minutes;

        uint256 maxMonths = 40;

        uint256 totalEligible;
        if (elapsedIntervals >= maxMonths) {
            totalEligible = purchase.amount;
        } else {
            totalEligible = (purchase.amount * elapsedIntervals) / maxMonths;
        }

        totalEligible -= purchase.withdrawn;

        uint256 amountToWithdraw = totalEligible;

        require(amountToWithdraw > 0, "NO_TOKENS_AVAILABLE_FOR_WITHDRAWAL");
        require(
            token.balanceOf(address(this)) >= amountToWithdraw,
            "INSUFFICIENT_BALANCE_IN_CONTRACT"
        );

        purchase.withdrawn += amountToWithdraw;

        purchase.withdrawableBalance = purchase.amount - purchase.withdrawn;

        if (purchase.withdrawn < purchase.amount) {
            uint256 intervalsProcessed = (block.timestamp -
                purchase.claimDate) / 3 minutes;

            purchase.withdrawCount = intervalsProcessed;

            purchase.nextClaimDate =
                purchase.claimDate +
                ((intervalsProcessed + 1) * 3 minutes);
        } else {
            purchase.nextClaimDate = 0;
        }

        token.transfer(msg.sender, amountToWithdraw);

        if(purchase.amount == purchase.withdrawn){
            purchase.isWithdrawCompleted = true ;
        }
    }

    function recoverTokens(address tokenToRecover) public onlyOwner {
        IERC20 tokenContract = IERC20(tokenToRecover);
        uint256 contractTokenBalance = tokenContract.balanceOf(address(this));
        require(contractTokenBalance > 0, "NO_TOKENS_TO_RECOVER");

        bool sent = tokenContract.transfer(msg.sender, contractTokenBalance);
        require(sent, "FAILED_TO_RECOVER_TOKENS");
    }

}
