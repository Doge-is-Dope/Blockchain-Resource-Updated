// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {CErc20} from "compound-protocol/contracts/CErc20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/interfaces/ISwapRouter.sol";
import {
    IFlashLoanSimpleReceiver,
    IPoolAddressesProvider,
    IPool
} from "aave-v3-core/contracts/flashloan/interfaces/IFlashLoanSimpleReceiver.sol";

contract AaveFlashLoan is IFlashLoanSimpleReceiver {
    address constant _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant _POOL_ADDRESSES_PROVIDER = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address constant _SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @notice execute flashloan
    /// @param liquidateAmount amount of USDC to liquidate
    function execute(uint256 liquidateAmount, bytes memory callbackData) external {
        POOL().flashLoanSimple(address(this), _USDC_ADDRESS, liquidateAmount, callbackData, 0);

        // Transfer profit to liquidator
        IERC20(_USDC_ADDRESS).transfer(msg.sender, IERC20(_USDC_ADDRESS).balanceOf(address(this)));
    }

    /// @notice callback function
    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        // Decode params - Borrower, cUSDC, cUNI, UNI
        (address _borrower, address _cUSDC, address _cUNI, address _UNI) =
            abi.decode(params, (address, address, address, address));

        // Liquidate borrower (repay USDC)
        IERC20(_USDC_ADDRESS).approve(_cUSDC, amount);
        require(CErc20(_cUSDC).liquidateBorrow(_borrower, amount, CErc20(_cUNI)) == 0, "unsuccessful");

        // Redeem collateral (cUNI to UNI)
        require(CErc20(_cUNI).redeem(CErc20(_cUNI).balanceOf(address(this))) == 0, "unsuccessful");

        // Swap UNI to USDC
        _swap(address(_UNI), address(_USDC_ADDRESS), IERC20(_UNI).balanceOf(address(this)));

        // Repay flashloan (USDC)
        IERC20(_USDC_ADDRESS).approve(address(POOL()), amount + premium);
        return true;
    }

    function ADDRESSES_PROVIDER() public view returns (IPoolAddressesProvider) {
        return IPoolAddressesProvider(_POOL_ADDRESSES_PROVIDER);
    }

    function POOL() public view returns (IPool) {
        return IPool(ADDRESSES_PROVIDER().getPool());
    }

    /// @notice swap token
    /// @param _tokenIn token to swap. i.e. UNI
    /// @param _tokenOut token to receive. i.e. USDC
    /// @param _amountIn amount of token to swap. i.e. amount of UNI
    function _swap(address _tokenIn, address _tokenOut, uint256 _amountIn) internal returns (uint256) {
        // Approve token to swap router
        IERC20(_tokenIn).approve(_SWAP_ROUTER, IERC20(_tokenIn).balanceOf(address(this)));

        // Set up token swap params
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        // Swap token
        uint256 amountOut = ISwapRouter(_SWAP_ROUTER).exactInputSingle(swapParams);
        return amountOut;
    }
}
