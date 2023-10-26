// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "./interfaces/IPriceFeed.sol";

import "./libs/UniswapPathFinder.sol";

contract PriceFeed is IPriceFeed {

    using UniswapPathFinder for uint256;

    IUniswapV2Router02 public uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IQuoter public uniswapV3Quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    function testFindPathOneHop(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) external returns (IPriceFeed.FoundPath memory foundPath) {
        return amount._getPathWithPrice(tokenIn, tokenOut, exactIn);
    }

    function testV2(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) external view returns (uint) {
        return amount._getSingleAmountV2(tokenIn, tokenOut, exactIn);
    }

    function testV3(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        bool exactIn
    ) external returns (uint) {
        return amount._getSingleAmountV3(tokenIn, tokenOut, fee, exactIn);
    }

}