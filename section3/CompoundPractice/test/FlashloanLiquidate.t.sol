// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/helper/FlashloanLiquidateSetUp.sol";
import "../src/AaveFlashLoan.sol";

// forge test --match-path test/FlashloanLiquidate.t.sol
contract FlashloanLiquidateTest is FlashloanLiquidateSetUp {
    address _user1;
    address _user2;

    function setUp() public override {
        super.setUp();

        // Supply 6000 USDC to cUSDC
        deal(address(USDC), address(cUSDC), 6000 * 10 ** USDC.decimals());

        // Create user1 and fund 1000 UNIs
        _user1 = makeAddr("user1");
        deal(address(UNI), _user1, 1_000 * 10 ** UNI.decimals());
        assertEq(UNI.balanceOf(_user1), 1_000 * 10 ** UNI.decimals());

        // Create user2
        _user2 = makeAddr("user2");
    }

    function test_flashloan_liquidate() public {
        vm.startPrank(_user1);

        // Mint cUNI
        UNI.approve(address(cUNI), UNI.balanceOf(_user1));
        uint256 mintedAmount = 1000 * 10 ** UNI.decimals();
        assertEq(cUNI.mint(mintedAmount), 0); // success
        assertEq(cUNI.balanceOf(_user1), mintedAmount); // user1 receives 1000 cUNI
        assertEq(UNI.balanceOf(_user1), 0); // user1 has no UNI

        // Make cUNI as collateral
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        comptrollerProxy.enterMarkets(cTokens);

        // Borrow 2500 USDC
        uint256 borrowedAmount = 2_500 * 10 ** USDC.decimals();
        assertEq(cUSDC.borrow(borrowedAmount), 0); // success
        assertEq(USDC.balanceOf(_user1), borrowedAmount); // user1 has 2500 USDC
        assertEq(cUSDC.borrowBalanceStored(_user1), borrowedAmount); // user1 has borrowed 2500 USDC
        vm.stopPrank();

        // ====================================================
        // Modify the price of UNI from 5 to 4.
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4e18);
        // ====================================================

        // user1 now has short fall
        (, uint256 _liquidity, uint256 _shortfallBeforeLiquidate) = comptrollerProxy.getAccountLiquidity(_user1);
        assertEq(_shortfallBeforeLiquidate, 0.5e21); // 4 * 50% - 5 * 50% = 2 - 2.5 = -0.5 (0.5 * 10^3 * 10^18)

        // Start prank user 2
        vm.startPrank(_user2);

        // Get the borrowed amount of user1.
        uint256 user1BorrowedUSDC = cUSDC.borrowBalanceCurrent(_user1);
        assertEq(user1BorrowedUSDC, 2500 * 10 ** USDC.decimals()); // 2500 USDC

        // Get the close factor.
        uint256 closeFactorMinMantissa = comptrollerProxy.closeFactorMantissa();
        assertEq(closeFactorMinMantissa, 0.5e18); // 50%

        // Calculate the amount can be liquidated
        uint256 liauidatedAmount = user1BorrowedUSDC * closeFactorMinMantissa / 1e18;
        assertEq(liauidatedAmount, 1250 * 10 ** USDC.decimals()); // 1250 USDC

        // Set up callback data for liquidation in flashloan
        bytes memory callbackData = abi.encode(address(_user1), address(cUSDC), address(cUNI), address(UNI));
        AaveFlashLoan receiver = new AaveFlashLoan();
        receiver.execute(liauidatedAmount, callbackData);

        // Check the profit
        console.log("user2 usdc balance: %s", USDC.balanceOf(address(_user2)));
        assertGe(USDC.balanceOf(address(_user2)), 63 * 10 ** USDC.decimals());
    }
}
