// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "../interfaces/IPriceFeed.sol";
import "../PriceFeed.sol";

library UniswapPathFinder {

    function _getPathWithPrice(
        uint256 amount, 
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) internal returns (IPriceFeed.FoundPath memory foundPath) {
        if (amount == 0) {
            return foundPath;
        }

        (uint256 bestAmount, IPriceFeed.PoolType poolType) = _findBestHop(
            amount,
            tokenIn,
            tokenOut,
            exactIn
        );
        if (poolType != IPriceFeed.PoolType.None) {
            address[] memory path2 = new address[](2);
            uint256[] memory amounts2 = new uint256[](2);
            IPriceFeed.PoolType[] memory poolTypes2 = new IPriceFeed.PoolType[](1);
            path2[0] = tokenIn;
            path2[1] = tokenOut;
            poolTypes2[0] = poolType;
            amounts2[0] = exactIn ? amount : bestAmount;
            amounts2[1] = exactIn ? bestAmount : amount;

            foundPath.path = path2;
            foundPath.poolTypes = poolTypes2;
            foundPath.amounts = amounts2;
        }
    }

    function _tryPath() internal {}

    function _findBestHop(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) internal returns (uint256 nextAmount, IPriceFeed.PoolType poolType) {
        (nextAmount, poolType) = (exactIn ? 0 : type(uint256).max, IPriceFeed.PoolType.None);
        uint256 hopAmount = _getSingleAmountV2(amount, tokenIn, tokenOut, exactIn);
        if (exactIn ? hopAmount > nextAmount : hopAmount < nextAmount) {
            (nextAmount, poolType) = (hopAmount, IPriceFeed.PoolType.UniswapV2);
        }
        for (uint i = 2; i < 5; i++) {
            IPriceFeed.PoolType v3PoolType = IPriceFeed.PoolType(i);
            hopAmount = _getSingleAmountV3(amount, tokenIn, tokenOut, _feeByPoolType(v3PoolType), exactIn);
            if (exactIn ? hopAmount > nextAmount : hopAmount < nextAmount) {
                (nextAmount, poolType) = (hopAmount, v3PoolType);
            }
        }
    }

    function _feeByPoolType(IPriceFeed.PoolType poolType) internal pure returns (uint24 fee) {
        poolType == IPriceFeed.PoolType.UniswapV3Fee10000 ?
            fee = 10000 : poolType == IPriceFeed.PoolType.UniswapV3Fee3000 ?
            fee = 3000 : poolType == IPriceFeed.PoolType.UniswapV3Fee500 ?
            fee = 500 : fee = 0;
    }

    function _getSingleAmountV2(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) internal view returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(PriceFeed(address(this)).uniswapV2Router());
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        if (exactIn) {
            try router.getAmountsOut(amount, path) returns (uint256[] memory amounts) {
                return amounts[1];
            } catch {
                return 0;
            }
        } else {
            try router.getAmountsIn(amount, path) returns (uint256[] memory amounts) {
                return amounts[0];
            } catch {
                return type(uint256).max;
            }
        }
    }

    function _getSingleAmountV3(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        uint24 fee,
        bool exactIn
    ) internal returns (uint256) {
        IQuoter quoter = IQuoter(PriceFeed(address(this)).uniswapV3Quoter());

        if (exactIn) {
            try quoter.quoteExactInputSingle(tokenIn, tokenOut, fee, amount, 0) returns (uint256 newAmount) {
                return newAmount;
            } catch {
                return 0;
            }
        } else {
            try quoter.quoteExactOutputSingle(tokenIn, tokenOut, fee, amount, 0) returns (uint256 newAmount) {
                return newAmount;
            } catch {
                return type(uint256).max;
            }
        }
    }

}