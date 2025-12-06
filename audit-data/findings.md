[H-1] TITLE (Root Cause -> Impact) The `ThunderLoan::updateExchangeRate` in the function `ThunderLoan::deposit` blocks redemption of the liquidator and incorrectly sets the exchange rate.

Description: In the function `ThunderLoan::deposit`, the `updateExchangeRate` function is called whose responsible for updating the exchange rate between asset token and the underlying token and keeping track of how much fees to give to the liquidity providers. However, its updating the rate without getting the fees.

```javascript
function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
@>      uint256 calculatedFee = getCalculatedFee(token, amount);
@>      assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```

Impact: The liquidity providers will get less amount of tokens they deposited or they deserve.

Proof of Concept: 
1. Liquidity provider deposits tokens.
2. User flashloans some amount and pays fees
3. Liquidity provider do not get the reward and even gets less amount than they expected or deposited.

<details>

<summary>Proof of Code</summary>
Consider adding the below code to `ThunderLoanTest.t.sol`

```javascript
function testRedeemAferLoad() public setAllowedToken{
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider,10e18);
        uint256 startingBal = tokenA.balanceOf(liquidityProvider);
        tokenA.approve(address(thunderLoan), 10e18);
        thunderLoan.deposit(tokenA, 2e18);
        vm.stopPrank();
        vm.startPrank(user);
        tokenA.mint(address(mockFlashLoanReceiver),10e18);
        thunderLoan.flashloan(address(mockFlashLoanReceiver), tokenA, 1e18, "");
        vm.stopPrank();
        vm.startPrank(liquidityProvider);
        thunderLoan.redeem(tokenA, 2e18);
        vm.stopPrank();
        uint256 endingBal = tokenA.balanceOf(liquidityProvider);
        assert(startingBal < endingBal);
    }
```

</details>

Recommended Mitigation: Just remove the incorrectly updated exchange rate from `ThunderLoan::deposit`

```diff
function deposit(IERC20 token, uint256 amount) external revertIfZero(amount) revertIfNotAllowedToken(token) {
        AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 exchangeRate = assetToken.getExchangeRate();
        uint256 mintAmount = (amount * assetToken.EXCHANGE_RATE_PRECISION()) / exchangeRate;
        emit Deposit(msg.sender, token, amount);
        assetToken.mint(msg.sender, mintAmount);
-       uint256 calculatedFee = getCalculatedFee(token, amount);
-       assetToken.updateExchangeRate(calculatedFee);
        token.safeTransferFrom(msg.sender, address(assetToken), amount);
    }
```



[H-1] TITLE (Root Cause -> Impact) There is storage collision happening between `ThunderLoan::s_flashLoanFee` and `ThunderLoanUpgraded::s_flashLoanFee`.

Description: The order of storage variables in the `ThunderLoan` is different from `ThunderLoanUpgraded`.

In the contract `ThunderLoan` the order is: 

```javascript
    uint256 private s_feePrecision;
    uint256 private s_flashLoanFee;
```

And in the contract `ThunderLoanUpgraded` the order is: 
```javascript
    uint256 private s_flashLoanFee;
    uint256 public constant FEE_PRECISION = 1e18;
```

Due to how the concept of storage works in solidity the `s_flashLoanFee` will get its value over writen by `s_feePrecision`. This can totally break the protocol as wrong values will get assigned.


Impact: Due to this the `s_flashLoanFee` will get its value over writen by `s_feePrecision`. And due to this many errors can happen like user will get wrong fee charged.

Proof of Concept: Consider adding the below test in your `ThunderLoanTest.t.sol`.

<details>
<summary>Proof of Code</summary>

```javascript
    function testStorageCollisionBreaks() public {
        uint256 feeBeforeUpgrade = thunderLoan.getFee();
        ThunderLoanUpgraded upgrade = new ThunderLoanUpgraded();
        thunderLoan.upgradeToAndCall(address(upgrade), "");
        uint256 feeAfterUpgrade = upgrade.getFee();
        console.log("feeBeforeUpgrade",feeBeforeUpgrade);
        console.log("feeAfterUpgrade",feeAfterUpgrade);
        assert(feeBeforeUpgrade != feeAfterUpgrade);
    }
```

</details>

Recommended Mitigation: Consider using same order of storage variables in your `ThunderLoanUpgraded` as its used in `ThunderLoan`.

Receommended to add the following changes in your `ThunderLoanUpgraded` contract.

```diff
-    uint256 private s_flashLoanFee;
-    uint256 public constant FEE_PRECISION = 1e18;
+    uint256 public FEE_PRECISION = 1e18;
+    uint256 private s_flashLoanFee;
    
```




[H-3] TITLE (Root Cause -> Impact) 

Description:

Impact:

Proof of Concept:

Recommended Mitigation: