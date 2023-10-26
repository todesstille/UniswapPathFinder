// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPriceFeed {
    enum PoolType {
        None,
        UniswapV2,
        UniswapV3Fee500,
        UniswapV3Fee3000,
        UniswapV3Fee10000
    }

    struct FoundPath {
        address[] path;
        PoolType[] poolTypes;
        uint256[] amounts;
    }
}
