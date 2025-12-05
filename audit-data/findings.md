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

