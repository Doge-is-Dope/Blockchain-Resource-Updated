// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/helper/CompoundSetUp.sol";

// forge test --match-path test/Compound.t.sol
contract CompoundTest is CompoundSetUp {
    address _user1;
    address _user2;

    uint256 constant _MAX_UINT = 2 ** 256 - 1; // For maximum approve amount
    uint256 _initialBalance = 500e18; // 500 tokenA
    uint256 _result = 0;

    function setUp() public override {
        super.setUp();

        _user1 = makeAddr("user1");
        _user2 = makeAddr("user2");

        deal(address(tokenA), _user1, _initialBalance);
        assertEq(tokenA.balanceOf(_user1), 500 * 10 ** tokenA.decimals());
        deal(address(tokenB), _user1, _initialBalance);
        assertEq(tokenB.balanceOf(_user1), 500 * 10 ** tokenA.decimals());

        deal(address(tokenA), _user2, _initialBalance);
        assertEq(tokenA.balanceOf(_user2), 500 * 10 ** tokenA.decimals());
        deal(address(tokenB), _user2, _initialBalance);
        assertEq(tokenB.balanceOf(_user2), 500 * 10 ** tokenA.decimals());
    }

    /// @dev User1 supplies tokenA and redeem cTokenA
    function test_mint_and_redeem() public {
        vm.startPrank(_user1);

        tokenA.approve(address(cTokenA), _initialBalance);

        // Mint 100 cTokenA
        uint256 mintedAmount = 100 * 10 ** cTokenA.decimals();
        _result = cTokenA.mint(mintedAmount);
        assertEq(_result, 0);
        assertEq(cTokenA.balanceOf(_user1), mintedAmount); // 100
        assertEq(tokenA.balanceOf(_user1), _initialBalance - mintedAmount); // 400

        // Redeem 100 cTokenA
        _result = cTokenA.redeem(mintedAmount);
        assertEq(_result, 0);
        assertEq(cTokenA.balanceOf(_user1), 0); // 0
        assertEq(tokenA.balanceOf(_user1), _initialBalance); // 500
        vm.stopPrank();
    }

    /// @dev Admin supplies tokenA so that user1 can borrow. Same as test_mint_and_redeem().
    function _supplyTokenA() private {
        vm.startPrank(admin);
        deal(address(tokenA), admin, _initialBalance); // 500 tokenA to admin
        tokenA.approve(address(cTokenA), _initialBalance);
        _result = cTokenA.mint(tokenA.balanceOf(admin)); // 500 cTokenA to admin
        assertEq(_result, 0);
        assertEq(cTokenA.balanceOf(admin), _initialBalance);
        assertEq(tokenA.balanceOf(admin), 0);
        vm.stopPrank();
    }

    function test_borrow_and_repay() public {
        _supplyTokenA(); // Admin supplies 500 tokenA

        vm.startPrank(_user1);

        tokenA.approve(address(cTokenA), _MAX_UINT);
        tokenB.approve(address(cTokenB), _MAX_UINT);

        // Mint 1 cTokenB
        uint256 mintedAmount = 1 * 10 ** cTokenB.decimals();
        _result = cTokenB.mint(mintedAmount);
        assertEq(_result, 0);
        assertEq(cTokenB.balanceOf(_user1), mintedAmount); // 1
        assertEq(tokenB.balanceOf(_user1), _initialBalance - mintedAmount); // 499

        // The liquidity of user1 is 0 before entering market meaning that user1 cannot borrow
        (uint256 _resultBefore, uint256 _liquidityBefore, uint256 _shortfallBefore) =
            comptrollerProxy.getAccountLiquidity(_user1);
        assertEq(_resultBefore, 0);
        assertEq(_shortfallBefore, 0);
        assertEq(_liquidityBefore, 0);

        // Make cTokenB as collateral
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        (uint256[] memory _results) = comptrollerProxy.enterMarkets(cTokens);
        assertEq(_results[0], 0);

        // The liquidity of user1 should be greater than 0 after entering market
        (uint256 _resultAfter, uint256 _liquidityAfter, uint256 _shortfallAfter) =
            comptrollerProxy.getAccountLiquidity(_user1);
        assertEq(_resultAfter, 0);
        assertEq(_shortfallAfter, 0);
        assertGt(_liquidityAfter, 0);

        // Borrow 50 tokenA
        uint256 borrowedAmount = 50 * 10 ** cTokenA.decimals();
        _result = cTokenA.borrow(borrowedAmount);
        assertEq(_result, 0);
        assertEq(cTokenA.borrowBalanceStored(_user1), borrowedAmount); // 50
        assertEq(tokenA.balanceOf(_user1), _initialBalance + borrowedAmount); // 550

        // Repay 50 tokenA
        _result = cTokenA.repayBorrow(borrowedAmount);
        assertEq(_result, 0);
        assertEq(cTokenA.borrowBalanceStored(_user1), 0);
        assertEq(tokenA.balanceOf(_user1), _initialBalance); // 500

        vm.stopPrank();
    }

    function test_liquidation() public {
        _supplyTokenA(); // Admin supplies 500 tokenA

        vm.startPrank(_user1);
        tokenB.approve(address(cTokenB), _MAX_UINT);

        // Mint 1 cTokenB.
        uint256 mintedAmount = 1 * 10 ** cTokenB.decimals();
        assertEq(cTokenB.mint(mintedAmount), 0); // success

        // Make cTokenB as collateral.
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        comptrollerProxy.enterMarkets(cTokens);

        // Borrow 50 tokenA.
        uint256 borrowedAmount = 50 * 10 ** cTokenA.decimals();
        assertEq(cTokenA.borrow(borrowedAmount), 0); // success
        assertEq(tokenA.balanceOf(_user1), _initialBalance + borrowedAmount); // 500 + 50 = 550
        vm.stopPrank();

        // Modify the colleceral factor of cTokenB to 30%.
        comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 0.3e18);
        (,, uint256 _shortfallBeforeLiquidate) = comptrollerProxy.getAccountLiquidity(_user1);
        assertEq(_shortfallBeforeLiquidate, 20); // 50 - 100 * 30% = -20

        vm.startPrank(_user2);
        // Get the borrowed amount of user1.
        uint256 user1BorrowedTokenA = cTokenA.borrowBalanceStored(_user1);
        assertEq(user1BorrowedTokenA, 50 * 10 ** tokenA.decimals()); // 50

        // Get the close factor.
        uint256 closeFactorMinMantissa = comptrollerProxy.closeFactorMantissa();
        assertEq(closeFactorMinMantissa, 0.5e18); // 50%

        // Calculate the amount of tokenA to be liquidated. Only 50%, 25 tokenA, can be liquidated.
        uint256 liauidatedAmount = user1BorrowedTokenA * closeFactorMinMantissa / 1e18;
        assertEq(liauidatedAmount, 25 * 10 ** tokenA.decimals()); // 25

        // Liquidate 25 tokenA of user1 by user2.
        tokenA.approve(address(cTokenA), liauidatedAmount);
        assertEq(cTokenA.liquidateBorrow(_user1, liauidatedAmount, cTokenB), 0); // success

        // Now the borrowed amount of user1 should be 25.
        assertEq(cTokenA.borrowBalanceStored(_user1), 25e18); // borrowedAmount - liauidatedAmount

        // Since userA didn't repay the borrowed amount, the tokenA balance of user1 remains the same.
        assertEq(tokenA.balanceOf(_user1), 550e18); // _initialBalance + borrowedAmount

        // Check the tokenA balance of user2.
        assertEq(tokenA.balanceOf(_user2), 475e18); // _initialBalance - liauidatedAmount

        // The cTokenB balance of user2.
        // 2.8% is added to the cToken’s reserves.
        assertEq(cTokenB.balanceOf(_user2), 24.3e16); // 25 * (100% - 2.8%) / 100 = 0.243

        // First of all, the liquidate incentive is deducted by 25 * 1.08 = 27
        // so user1's tokenB value is now $100 - $27 = $73
        // Since the collectoral factor of cTokenB is 30%, it's acually $73 * 30% = $21.9 ~= $22
        // The shortfall of user1 is borrowed amount - actual balance: $25 - $22 = $3
        (,, uint256 _shortfallAfterLiquidate) = comptrollerProxy.getAccountLiquidity(_user1);
        assertEq(_shortfallAfterLiquidate, 3); // 25 - 100 * 30% = 3
        vm.stopPrank();
    }
}
