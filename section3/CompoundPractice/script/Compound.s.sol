// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "compound-protocol/contracts/CErc20Delegator.sol";
import "compound-protocol/contracts/CErc20Delegate.sol";
import "compound-protocol/contracts/Comptroller.sol";
import "compound-protocol/contracts/ComptrollerInterface.sol";
import "compound-protocol/contracts/SimplePriceOracle.sol";
import "compound-protocol/contracts/Unitroller.sol";
import "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";

contract CompoundScript is Script {
    string private constant cTokenName = "Compound ERC20 Token";
    string private constant cTokenSymbol = "cERC20";
    uint8 private constant cTokenDecimals = 18;

    uint256 initialExchangeRateMantissa = 1;

    function setUp() public {}

    function deployUnitroller() public {
        // Deploy Unitroller
        Unitroller unitroller = new Unitroller();

        // Deploy Comptroller
        Comptroller comptroller = new Comptroller();

        // Set Comptroller as implementation of Unitroller
        unitroller._setPendingImplementation(address(comptroller));

        SimplePriceOracle oracle = new SimplePriceOracle();
        comptroller._setPriceOracle(oracle);
        comptroller._become(unitroller);
    }

    function run() public {
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
        vm.startBroadcast(deployer);

        // Deply underlying token
        ERC20 underlyingToken = new ERC20("Underlying", "UND");

        // Deploy SimplePriceOracle
        SimplePriceOracle oracle = new SimplePriceOracle();

        Comptroller comptroller = new Comptroller();
        comptroller._setPriceOracle(oracle);
        ComptrollerInterface comptrollerInterface = ComptrollerInterface(address(comptroller));

        // Deploy CErc20Delegate
        CErc20Delegate delegate = new CErc20Delegate();

        // Deploy WhitePaperInterestRateModel
        WhitePaperInterestRateModel interestRateModel = new WhitePaperInterestRateModel(0, 0);

        new CErc20Delegator(
            address(underlyingToken),    // The address of the underlying asset
            comptrollerInterface,        // The address of the Comptroller
            interestRateModel,           // The address of the interest rate model
            initialExchangeRateMantissa, // The initial exchange rate
            cTokenName,                  // ERC-20 name of this token
            cTokenSymbol,                // ERC-20 symbol of this token
            cTokenDecimals,              // ERC-20 decimal precision of this token
            payable(deployer),           // The address of the administrator of this token
            address(delegate),           // The address of the implementation the contract delegates to
            new bytes(0)                 // The encoded args for becomeImplementation
        );

        deployUnitroller();

        vm.stopBroadcast();
    }
}
