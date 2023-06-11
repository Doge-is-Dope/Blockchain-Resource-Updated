// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/helper/CompoundSetUp.sol";

// forge test --match-path test/Compound.t.sol
contract CompoundTest is CompoundSetUp {
    address _user1;

    uint256 _initialBalance = 500e18; // 500 token1

    function setUp() public override {
        super.setUp();

        _user1 = makeAddr("user1");
        deal(address(token1), _user1, _initialBalance);
        assertEq(token1.balanceOf(_user1), 500 * 10 ** token1.decimals());
    }

    /// @dev User1 supplies token1 and redeem cToken1
    function test_supply_and_redeem() public {
        vm.startPrank(_user1);

        // In mintAllowed, comptroller checks require(markets[cToken].isListed)
        address[] memory addr = new address[](1);
        addr[0] = address(cToken1);
        comptrollerProxy.enterMarkets(addr);

        token1.approve(address(cToken1), _initialBalance);

        // Mint 100 cToken1
        uint256 mintedAmount = 100 * 10 ** cToken1.decimals();
        cToken1.mint(mintedAmount);
        assertEq(cToken1.balanceOf(_user1), mintedAmount); // 100
        assertEq(token1.balanceOf(_user1), _initialBalance - mintedAmount); // 400

        // Redeem 100 cToken1
        cToken1.redeem(mintedAmount);
        assertEq(cToken1.balanceOf(_user1), 0); // 0
        assertEq(token1.balanceOf(_user1), _initialBalance); // 500
    }
}
