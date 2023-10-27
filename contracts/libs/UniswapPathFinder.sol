// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../interfaces/IPriceFeed.sol";
import "../PriceFeed.sol";

library UniswapPathFinder {

    using EnumerableSet for EnumerableSet.AddressSet;

    // TODO: Switch provided path memory to calldata
    function _getPathWithPrice(
        EnumerableSet.AddressSet storage pathTokens,
        uint256 amount, 
        address tokenIn,
        address tokenOut,
        bool exactIn,
        IPriceFeed.ProvidedPath memory providedPath
    ) internal returns (IPriceFeed.FoundPath memory foundPath) {
        if (amount == 0) {
            return foundPath;
        }

        address[] memory path2 = new address[](2);
        path2[0] = tokenIn;
        path2[1] = tokenOut;

        (IPriceFeed.FoundPath memory foundPath2, bool isFoundAtLeastOnePath) = _calculatePath(amount, path2, exactIn);
        
        if (isFoundAtLeastOnePath) {
            foundPath = foundPath2;             
        }

        uint256 length = pathTokens.length();

        for (uint256 i = 0; i < length; i++) {
            address[] memory path3 = new address[](3);
            path3[0] = tokenIn;
            path3[1] = pathTokens.at(i);
            path3[2] = tokenOut;

            (IPriceFeed.FoundPath memory foundPath3, bool isPathValid) = _calculatePath(amount, path3, exactIn);

            if (isPathValid) {
                if (!isFoundAtLeastOnePath) {
                    isFoundAtLeastOnePath = true;
                    foundPath = foundPath3;
                } else {
                    uint256 previousResult = 
                        exactIn ? 
                            foundPath.amounts[foundPath.amounts.length - 1] 
                            : foundPath.amounts[0];
                    uint256 currentResult = 
                        exactIn ? 
                            foundPath3.amounts[foundPath3.amounts.length - 1] 
                            : foundPath3.amounts[0];
                    if (exactIn ? previousResult < currentResult : previousResult > currentResult) {
                        foundPath = foundPath3;
                    }
                }
            }
        }

        if (_verifyPredefinedPath(tokenIn, tokenOut, providedPath)) {
            (IPriceFeed.FoundPath memory customPath, bool isPathValid) = 
                _calculatePredefinedPath(providedPath, amount, exactIn);
            if (isPathValid) {
                if (!isFoundAtLeastOnePath) {
                    isFoundAtLeastOnePath = true;
                    foundPath = customPath;
                } else {
                    uint256 previousResult = 
                        exactIn ? 
                            foundPath.amounts[foundPath.amounts.length - 1] 
                            : foundPath.amounts[0];
                    uint256 currentResult = 
                        exactIn ? 
                            customPath.amounts[customPath.amounts.length - 1] 
                            : customPath.amounts[0];
                    if (exactIn ? previousResult < currentResult : previousResult > currentResult) {
                        foundPath = customPath;
                    }
                }
            }
        }
    }

    // TODO: Switch provided path memory to calldata
    function _verifyPredefinedPath(
        address tokenIn,
        address tokenOut,
        IPriceFeed.ProvidedPath memory providedPath
    ) internal pure returns (bool verified) {
        verified = providedPath.path.length < 3 ? false
            : providedPath.path.length != providedPath.poolTypes.length + 1 ? false
            : providedPath.path[0] != tokenIn ? false
            : providedPath.path[providedPath.path.length - 1] != tokenOut ? false
            : true;
        
        for (uint i = 0; i < providedPath.poolTypes.length; i++) {
            if (providedPath.poolTypes[i] == IPriceFeed.PoolType.None) {
                verified = false;
            }
        }
    }

    // TODO: Switch provided path memory to calldata
    function _calculatePredefinedPath(
        IPriceFeed.ProvidedPath memory providedPath,
        uint256 amount,
        bool exactIn
    ) internal returns (IPriceFeed.FoundPath memory foundPath, bool isPathValid) {
        isPathValid = true;
        uint256 len = providedPath.path.length;
        uint256[] memory amounts = new uint256[](len);
        foundPath.path = providedPath.path;
        foundPath.poolTypes = providedPath.poolTypes;
        foundPath.amounts = amounts;

        if (exactIn) {
            amounts[0] = amount;
            for (uint i = 0; i < len - 1; i++) {
                amounts[i + 1] = _calculateSingleSwap(
                            amounts[i], 
                            foundPath.path[i], 
                            foundPath.path[i + 1],
                            foundPath.poolTypes[i],
                            exactIn
                        );
                if (amounts[i + 1] == 0) {
                    return (foundPath, false);
                }
            }
        } else {
            amounts[len - 1] = amount;
            for (uint i = len - 1; i > 0; i--) {
                amounts[i - 1] = _calculateSingleSwap(
                            amounts[i], 
                            foundPath.path[i - 1], 
                            foundPath.path[i],
                            foundPath.poolTypes[i - 1],
                            exactIn
                        );
                if (amounts[i - 1] == type(uint256).max) {
                    return (foundPath, false);
                }
            }
        }
    }

    function _calculatePath(
            uint256 amount, 
            address[] memory path, 
            bool exactIn
        ) internal returns (IPriceFeed.FoundPath memory foundPath, bool isPathValid) {
            isPathValid = true;
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
                        return (foundPath, false);
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
                        return (foundPath, false);
                    }
                }
            }
    }

    function _findBestHop(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        bool exactIn
    ) internal returns (uint256 amountAfterHop, IPriceFeed.PoolType poolType) {
        (amountAfterHop, poolType) = (
            exactIn ? 0 : type(uint256).max, 
            IPriceFeed.PoolType.None
        );
        uint256 swappedAmount = _calculateSingleSwapV2(amount, tokenIn, tokenOut, exactIn);
        if (exactIn ? swappedAmount > amountAfterHop : swappedAmount < amountAfterHop) {
            (amountAfterHop, poolType) = (swappedAmount, IPriceFeed.PoolType.UniswapV2);
        }
        for (uint i = 2; i < 5; i++) {
            IPriceFeed.PoolType v3PoolType = IPriceFeed.PoolType(i);
            swappedAmount = _calculateSingleSwapV3(amount, tokenIn, tokenOut, _feeByPoolType(v3PoolType), exactIn);
            if (exactIn ? swappedAmount > amountAfterHop : swappedAmount < amountAfterHop) {
                (amountAfterHop, poolType) = (swappedAmount, v3PoolType);
            }
        }
    }

    function _calculateSingleSwap(
        uint256 amount,
        address tokenIn,
        address tokenOut,
        IPriceFeed.PoolType poolType,
        bool exactIn
    ) internal returns (uint256) {
        return poolType == IPriceFeed.PoolType.UniswapV2 ?
            _calculateSingleSwapV2(
                amount, 
                tokenIn,
                tokenOut,
                exactIn
            )
        :
            _calculateSingleSwapV3(
                amount, 
                tokenIn,
                tokenOut,
                _feeByPoolType(poolType),
                exactIn
            );
    }

    function _feeByPoolType(IPriceFeed.PoolType poolType) internal pure returns (uint24 fee) {
        poolType == IPriceFeed.PoolType.UniswapV3Fee10000 ? fee = 10000 
            : poolType == IPriceFeed.PoolType.UniswapV3Fee3000 ? fee = 3000 
            : poolType == IPriceFeed.PoolType.UniswapV3Fee500 ? fee = 500 
            : fee = 0;
    }

    function _calculateSingleSwapV2(
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

    function _calculateSingleSwapV3(
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