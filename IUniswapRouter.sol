// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUniswapRouter {
    function getAmountsOut(uint amountIn, address[] memory path) public view returns (uint[] memory amounts);
}
