// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
// CToken
import "compound-protocol/contracts/CErc20.sol";
import "compound-protocol/contracts/CErc20Delegate.sol";
import "compound-protocol/contracts/CErc20Delegator.sol";
// Comptroller
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {ComptrollerInterface} from "compound-protocol/contracts/ComptrollerInterface.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
// Interest rate model
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
// ERC-20
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CompoundSetUp is Test {
    address public admin;

    uint256 public closeFactorMantissa = 0.5e18;
    uint256 public liquidationIncentiveMantissa = 1.08e18;
    uint256 public initialExchangeRateMantissa = 1e18;

    Comptroller public comptrollerProxy;

    ERC20 public token1;
    ERC20 public token2;

    CErc20Delegator public cToken1;
    CErc20Delegator public cToken2;

    function setUp() public virtual {
        admin = makeAddr("Admin");

        // Deply underlying tokens
        token1 = new ERC20("Token 1", "T1");
        token2 = new ERC20("Token 2", "T2");

        // Deploy Comptroller implementation
        Comptroller comptroller = new Comptroller();
        Unitroller unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);

        // Deploy comptroller proxy
        comptrollerProxy = Comptroller(address(unitroller));

        SimplePriceOracle oracle = new SimplePriceOracle();

        // Set oracle
        comptrollerProxy._setPriceOracle(oracle);
        // Set close factor
        comptrollerProxy._setCloseFactor(closeFactorMantissa);
        // Set liquidation incentive
        comptrollerProxy._setLiquidationIncentive(liquidationIncentiveMantissa);

        // Deploy interest rate model
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(0, 0);

        // Deplot CErc20Delegate
        CErc20Delegate delegate = new CErc20Delegate();

        cToken1 = new CErc20Delegator(
            address(token1),
            comptrollerProxy,
            interestRateModel,
            initialExchangeRateMantissa,
            "Compound Token 1",
            "cT1",
            18,
            payable(admin),
            address(delegate),
            new bytes(0)
        );

        cToken2 = new CErc20Delegator(
            address(token2),
            comptrollerProxy,
            interestRateModel,
            initialExchangeRateMantissa,
            "Compound Token 2",
            "cT2",
            18,
            payable(admin),
            address(delegate),
            new bytes(0)
        );

        // Set support market
        comptrollerProxy._supportMarket(CToken(address(cToken1)));
        // Set underlying price
        oracle.setUnderlyingPrice(CToken(address(cToken1)), 1);

        vm.label(address(comptroller), "comptroller");
        vm.label(address(unitroller), "unitroller");
        vm.label(address(token1), "token1");
        vm.label(address(token2), "token2");
        vm.label(address(cToken1), "cToken1");
        vm.label(address(cToken2), "cToken2");
    }
}
