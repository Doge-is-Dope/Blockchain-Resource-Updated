// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {EIP20Interface} from "compound-protocol/contracts/EIP20Interface.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import "test/helper/CompoundPracticeSetUp.sol";

interface IBorrower {
    function borrow() external;
}

contract CompoundPracticeTest is CompoundPracticeSetUp {
    EIP20Interface public USDC = EIP20Interface(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    CErc20 public cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    address public user;

    IBorrower public borrower;

    uint256 mainnetFork;

    function setUp() public override {
        // Fork mainnet
        mainnetFork = vm.createFork("https://eth-mainnet.g.alchemy.com/v2/dwhCNmMVbzaUyIBpd6IhRppq_ZB01_JI");
        vm.selectFork(mainnetFork);

        super.setUp();

        // Deployed in CompoundPracticeSetUp helper
        borrower = IBorrower(borrowerAddress);

        user = makeAddr("User");

        uint256 initialBalance = 10000 * 10 ** USDC.decimals();
        deal(address(USDC), user, initialBalance);

        vm.label(address(cUSDC), "cUSDC");
        vm.label(borrowerAddress, "Borrower");
    }

    function test_compound_mint_interest() public {
        vm.startPrank(user);

        uint256 initialBalance = USDC.balanceOf(address(user));

        // Approve USDC to cUSDC (error code: 12)
        USDC.approve(address(cUSDC), initialBalance);

        // TODO: 1. Mint some cUSDC with USDC
        uint256 mintResult = cUSDC.mint(initialBalance);

        // Assert the mint is successful
        assertEq(mintResult, 0);

        // TODO: 2. Modify block state to generate interest
        vm.roll(block.number + 10000);

        // TODO: 3. Redeem and check the redeemed amount
        uint256 redeemResult = cUSDC.redeem(cUSDC.balanceOf(address(user)));

        // Assert the redeem is successful
        assertEq(redeemResult, 0);

        // Redeemed USDC is greater than the initial balance
        assertGt(USDC.balanceOf(address(user)), initialBalance);

        console.log("Initial balance: %s", initialBalance);
        console.log("Final balance:   %s", USDC.balanceOf(address(user)));
    }

    function test_compound_mint_interest_with_borrower() public {
        vm.startPrank(user);

        uint256 initialBalance = USDC.balanceOf(address(user));

        // Approve USDC to cUSDC (error code: 12)
        USDC.approve(address(cUSDC), initialBalance);

        // TODO: 1. Mint some cUSDC with USDC
        assertEq(cUSDC.mint(initialBalance), 0);

        // TODO: 2. Borrower.borrow() will borrow some USDC
        borrower.borrow();

        // TODO: 3. Modify block state to generate interest
        vm.roll(block.number + 1000);

        // TODO: 4. Redeem and check the redeemed amount
        assertEq(cUSDC.redeem(cUSDC.balanceOf(address(user))), 0);

        // Redeemed USDC is greater than the initial balance
        assertGt(USDC.balanceOf(address(user)), initialBalance);

        console.log("Initial balance: %s", initialBalance);
        console.log("Final balance:   %s", USDC.balanceOf(address(user)));
    }
}
