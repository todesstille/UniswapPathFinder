// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IPriceFeed.sol";
import "../PriceFeed.sol";

library UniswapPathFinder {

    using EnumerableSet for EnumerableSet.AddressSet;

    function _getPathWithPrice(
        EnumerableSet.AddressSet storage pathTokens,
        uint256 amount, 
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) internal returns (IPriceFeed.FoundPath memory foundPath) {
        if (amount == 0) {
            return foundPath;
        }

        bool isFoundAtLeastOnePath = false;

        address[] memory path2 = new address[](2);
        path2[0] = tokenIn;
        path2[1] = tokenOut;

        IPriceFeed.FoundPath memory foundPath2 = _findPath(amount, path2, exactIn);
        
        if (foundPath2.poolTypes[0] != IPriceFeed.PoolType.None) {
            foundPath = foundPath2;
            isFoundAtLeastOnePath = true; 
        }

        uint256 length = pathTokens.length();

        for (uint256 i = 0; i < length; i++) {
            address[] memory path3 = new address[](3);
            path3[0] = tokenIn;
            path3[1] = pathTokens.at(i);
            path3[2] = tokenOut;

            IPriceFeed.FoundPath memory foundPath3 = _findPath(amount, path3, exactIn);

            if (foundPath3.poolTypes[0] != IPriceFeed.PoolType.None) {
                if (!isFoundAtLeastOnePath) {
                    isFoundAtLeastOnePath = true;
                    foundPath = foundPath3;
                } else {
                    uint256 previousResult = exactIn ? foundPath.amounts[foundPath.amounts.length - 1] : foundPath.amounts[0];
                    uint256 currentResult= exactIn ? foundPath3.amounts[foundPath3.amounts.length - 1] : foundPath3.amounts[0];
                    if (exactIn ? previousResult < currentResult : previousResult > currentResult) {
                        foundPath = foundPath3;
                    }
                }
            }

        }

    }

    function _findPath(
            uint256 amount, 
            address[] memory path, 
            bool exactIn
        ) internal returns (IPriceFeed.FoundPath memory foundPath) {
            uint256 len = path.length;
            assert(len >= 2);

            foundPath.amounts = new uint256[](len);
            foundPath.poolTypes = new IPriceFeed.PoolType[](len - 1);
            foundPath.path = path;

            if (exactIn) {
                foundPath.amounts[0] = amount;
                for (uint i = 0; i < len - 1; i++) {
                    (foundPath.amounts[i + 1], foundPath.poolTypes[i]) = _findBestHop(
                        foundPath.amounts[i],
                        path[i],
                        path[i + 1],
                        exactIn
                    );
                    if (foundPath.poolTypes[i] == IPriceFeed.PoolType.None) {
                        foundPath.poolTypes = new IPriceFeed.PoolType[](1);
                        return foundPath;
                    }
                }
            } else {
                foundPath.amounts[len - 1] = amount;
                for (uint i = len - 1; i > 0; i--) {
                    (foundPath.amounts[i - 1], foundPath.poolTypes[i - 1]) = _findBestHop(
                        foundPath.amounts[i],
                        path[i - 1],
                        path[i],
                        exactIn
                    );
                    if (foundPath.poolTypes[i - 1] == IPriceFeed.PoolType.None) {
                        foundPath.poolTypes = new IPriceFeed.PoolType[](1);
                        return foundPath;
                    }
                }
            }
    }

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