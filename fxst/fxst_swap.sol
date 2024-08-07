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

contract FXST_Swap {

    IERC20 public token;
    uint256 public tokensPerOLDFXST;
    uint256 public totalOldTokenCollect;
    uint256 public totalNewTokenSwap;
    address public swapOwner;

    IERC20 OLDFXST = IERC20(0xFF702E389ca1bC4A6D103e245956cFb0521Ae9c5);

    constructor(
        address _tokenAddress,
        address _owner,
        uint256 _tokensPerOLDFXST
    ) {
        token = IERC20(_tokenAddress);
        swapOwner = _owner;
        tokensPerOLDFXST = _tokensPerOLDFXST;
        totalOldTokenCollect = 0;
        totalNewTokenSwap = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == swapOwner, "ONLY_OWNER_CAN_ACCESS_THIS_FUNCTION");
        _;
    }

    function updateRate(uint256 newTokensPerOLDFXST)
        public
        onlyOwner
    {
        tokensPerOLDFXST = newTokensPerOLDFXST;
    }

    function endSwap() public onlyOwner {
        uint256 contractTokenBalance = token.balanceOf(address(this));
        token.transfer(msg.sender, contractTokenBalance);
    }

    function swapWithOLDFXST(uint256 _OLDFXSTAmount) public {
        require(
            OLDFXST.balanceOf(msg.sender) >= _OLDFXSTAmount,
            "Insufficient OLDFXST balance"
        );

        uint256 tokenAmount = _OLDFXSTAmount / tokensPerOLDFXST;
        require(
            token.balanceOf(address(this)) >= tokenAmount,
            "Insufficient balance in contract"
        );

        require(
            OLDFXST.transferFrom(msg.sender, swapOwner, _OLDFXSTAmount),
            "Failed to transfer OLDFXST tokens to swapOwner"
        );

        require(
            token.transfer(msg.sender, tokenAmount),
            "Failed to transfer new tokens to the user"
        );

        totalNewTokenSwap += tokenAmount;
        totalOldTokenCollect += _OLDFXSTAmount;
    }

    function recoverTokens(address tokenToRecover) public onlyOwner {
        IERC20 tokenContract = IERC20(tokenToRecover);
        uint256 contractTokenBalance = tokenContract.balanceOf(address(this));
        require(contractTokenBalance > 0, "No tokens to recover");

        bool sent = tokenContract.transfer(msg.sender, contractTokenBalance);
        require(sent, "Failed to recover tokens");
    }
}