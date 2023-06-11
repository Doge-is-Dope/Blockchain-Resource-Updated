// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/helper/CompoundSetUp.sol";

// forge test --match-path test/Compound.t.sol
contract CompoundTest is CompoundSetUp {
    address _admin;
    address _user1;
    address _user2;

    uint256 constant _MAX_UINT = 2 ** 256 - 1; // For maximum approve amount
    uint256 _initialBalance = 500e18; // 500 tokenA
    uint256 _result = 0;

    function setUp() public override {
        super.setUp();

        _admin = makeAddr("admin");
        _user1 = makeAddr("user1");
        _user2 = makeAddr("user2");

        deal(address(tokenA), _user1, _initialBalance);
        assertEq(tokenA.balanceOf(_user1), 500 * 10 ** tokenA.decimals());
        deal(address(tokenB), _user1, _initialBalance);
        assertEq(tokenB.balanceOf(_user1), 500 * 10 ** tokenA.decimals());
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

    /// @dev Admin supplies tokenA so that user1 can borrow
    function _supplyTokenA() private {
        vm.startPrank(_admin);
        deal(address(tokenA), _admin, _initialBalance); // 500 tokenA to admin
        tokenA.approve(address(cTokenA), _initialBalance);
        _result = cTokenA.mint(tokenA.balanceOf(_admin)); // 500 cTokenA to admin
        assertEq(_result, 0);
        assertEq(cTokenA.balanceOf(_admin), _initialBalance);
        assertEq(tokenA.balanceOf(_admin), 0);
        vm.stopPrank();
    }

    function test_borrow_and_repay() public {
        // Admin supplies 500 tokenA
        _supplyTokenA();

        vm.startPrank(_user1);

        tokenA.approve(address(cTokenA), _MAX_UINT);
        tokenB.approve(address(cTokenB), _MAX_UINT);

        // Mint 1 cTokenB
        uint256 mintedAmount = 1 * 10 ** cTokenB.decimals();
        _result = cTokenB.mint(mintedAmount);
        assertEq(_result, 0);
        assertEq(cTokenB.balanceOf(_user1), mintedAmount); // 1
        assertEq(tokenB.balanceOf(_user1), _initialBalance - mintedAmount); // 499

        // The liquidity of user1 is 0 before entering market
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
}
