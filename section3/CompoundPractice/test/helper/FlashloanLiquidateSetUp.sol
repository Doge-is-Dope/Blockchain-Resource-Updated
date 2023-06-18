// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
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

contract FlashloanLiquidateSetUp is Test {
    address public admin;

    uint256 public closeFactorMantissa = 0.5e18;
    uint256 public liquidationIncentiveMantissa = 1.08e18;

    Comptroller public comptrollerProxy;
    SimplePriceOracle public priceOracle;

    ERC20 public USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 public UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    CErc20Delegator public cUSDC;
    CErc20Delegator public cUNI;

    function setUp() public virtual {
        // Fork mainnet
        string memory rpc = vm.envString("MAINNET_RPC_URL");
        vm.createSelectFork(rpc);
        vm.rollFork(17_465_000);

        admin = makeAddr("Admin");

        // Deploy Comptroller implementation
        Comptroller comptroller = new Comptroller();
        Unitroller unitroller = new Unitroller();
        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);

        // Deploy comptroller proxy
        comptrollerProxy = Comptroller(address(unitroller));

        // Deploy price oracle
        priceOracle = new SimplePriceOracle();

        // Set oracle
        comptrollerProxy._setPriceOracle(priceOracle);
        // Set close factor
        comptrollerProxy._setCloseFactor(closeFactorMantissa);
        // Set liquidation incentive
        comptrollerProxy._setLiquidationIncentive(liquidationIncentiveMantissa);

        // Deploy interest rate model
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(0, 0);

        // Deplot CErc20Delegate
        CErc20Delegate delegate = new CErc20Delegate();

        cUSDC = new CErc20Delegator(
            address(USDC),
            comptrollerProxy,
            interestRateModel,
            1e6, // 1:1 exchange rate
            "Compound USDC",
            "cUSDC",
            18,
            payable(admin),
            address(delegate),
            new bytes(0)
        );

        cUNI = new CErc20Delegator(
            address(UNI),
            comptrollerProxy,
            interestRateModel,
            1e18, // 1:1 exchange rate
            "Compound UNI",
            "cUNI",
            18,
            payable(admin),
            address(delegate),
            new bytes(0)
        );

        // Set support market
        comptrollerProxy._supportMarket(CToken(address(cUSDC)));
        comptrollerProxy._supportMarket(CToken(address(cUNI)));
        // Set underlying price
        priceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1e30); // 10 ^ (36 - underlying decimals)
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5e18);

        // Set collateral factor for UNI
        comptrollerProxy._setCollateralFactor(CToken(address(cUNI)), 0.5e18);

        vm.label(address(comptroller), "comptroller");
        vm.label(address(unitroller), "unitroller");
        vm.label(address(USDC), "usdc");
        vm.label(address(UNI), "uni");
        vm.label(address(cUSDC), "cUsdc");
        vm.label(address(cUNI), "cUni");
    }
}
