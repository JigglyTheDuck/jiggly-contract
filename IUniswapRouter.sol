// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapRouter {
    function getAmountsOut(uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts);
}

