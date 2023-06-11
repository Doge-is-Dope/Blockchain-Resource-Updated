// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "test/helper/CompoundSetUp.sol";

// forge test --match-path test/Compound.t.sol
contract CompoundTest is CompoundSetUp {
    address _user1;

    uint256 _initialBalance = 500e18; // 500 tokenA

    function setUp() public override {
        super.setUp();

        _user1 = makeAddr("user1");
        deal(address(tokenA), _user1, _initialBalance);
        assertEq(tokenA.balanceOf(_user1), 500 * 10 ** tokenA.decimals());
    }

    /// @dev User1 supplies tokenA and redeem cTokenA
    function test_mint_and_redeem() public {
        vm.startPrank(_user1);

        // In mintAllowed, comptroller checks require(markets[cToken].isListed)
        address[] memory addr = new address[](1);
        addr[0] = address(cTokenA);
        comptrollerProxy.enterMarkets(addr);

        tokenA.approve(address(cTokenA), _initialBalance);

        // Mint 100 cTokenA
        uint256 mintedAmount = 100 * 10 ** cTokenA.decimals();
        cTokenA.mint(mintedAmount);
        assertEq(cTokenA.balanceOf(_user1), mintedAmount); // 100
        assertEq(tokenA.balanceOf(_user1), _initialBalance - mintedAmount); // 400

        // Redeem 100 cTokenA
        cTokenA.redeem(mintedAmount);
        assertEq(cTokenA.balanceOf(_user1), 0); // 0
        assertEq(tokenA.balanceOf(_user1), _initialBalance); // 500
    }
}
