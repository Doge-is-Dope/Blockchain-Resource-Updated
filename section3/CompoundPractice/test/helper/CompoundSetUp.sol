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

    ERC20 public tokenA;
    ERC20 public tokenB;

    CErc20Delegator public cTokenA;
    CErc20Delegator public cTokenB;

    function setUp() public virtual {
        admin = makeAddr("Admin");

        // Deply underlying tokens
        tokenA = new ERC20("Token A", "TA");
        tokenB = new ERC20("Token B", "TB");

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

        cTokenA = new CErc20Delegator(
            address(tokenA),
            comptrollerProxy,
            interestRateModel,
            initialExchangeRateMantissa,
            "Compound Token A",
            "cTA",
            18,
            payable(admin),
            address(delegate),
            new bytes(0)
        );

        cTokenB = new CErc20Delegator(
            address(tokenB),
            comptrollerProxy,
            interestRateModel,
            initialExchangeRateMantissa,
            "Compound Token B",
            "cTB",
            18,
            payable(admin),
            address(delegate),
            new bytes(0)
        );

        // Set support market
        comptrollerProxy._supportMarket(CToken(address(cTokenA)));
        comptrollerProxy._supportMarket(CToken(address(cTokenB)));
        // Set underlying price
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), 1);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), 100);

        // Set collateral factor for token B
        comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 0.5e18);

        vm.label(address(comptroller), "comptroller");
        vm.label(address(unitroller), "unitroller");
        vm.label(address(tokenA), "tokenA");
        vm.label(address(tokenB), "tokenB");
        vm.label(address(cTokenA), "cTokenA");
        vm.label(address(cTokenB), "cTokenB");
    }
}
