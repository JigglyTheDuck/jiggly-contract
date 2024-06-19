// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IUniswapRouter.sol";

contract UniswapConnect {
    address usRouter1;
    address usRouter2;
    bytes32 usInitCodeHash;
    address usFactoryAddress;
    address mainTokenAddress;

    mapping(address => address) usLPs;

    event NewLP(address token, address lp);
    event LPRemoved(address token, address lp);

    constructor(
        address tokenAddress,
        address uniswapFactoryAddress,
        address uniswapRouterAddress1,
        address uniswapRouterAddress2,
        bytes32 uniswapInitCodeHash
    ) {
        mainTokenAddress = tokenAddress;
        usRouter1 = uniswapRouterAddress1;
        usRouter2 = uniswapRouterAddress2;
        usFactoryAddress = uniswapFactoryAddress;
        usInitCodeHash = uniswapInitCodeHash;
    }

    function getLPAddress(address tokenAddress)
        internal
        view
        returns (address)
    {
        if (usLPs[tokenAddress] != address(0)) return usLPs[tokenAddress];

        (address token0, address token1) = mainTokenAddress < tokenAddress
            ? (mainTokenAddress, tokenAddress)
            : (tokenAddress, mainTokenAddress);

        bytes32 hash = keccak256(
            abi.encodePacked(
                hex"ff",
                usFactoryAddress,
                keccak256(abi.encodePacked(token0, token1)),
                usInitCodeHash
            )
        );
        return address(uint160(uint256(hash)));
    }

    function addLP(address tokenAddress) internal returns (address lpAddress) {
        lpAddress = getLPAddress(tokenAddress);

        usLPs[lpAddress] = tokenAddress;
        usLPs[tokenAddress] = lpAddress;

        emit NewLP(tokenAddress, lpAddress);

        return lpAddress;
    }

    function getAmountsOut(uint256 amountsIn, address lpAddress)
        internal view
        returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = mainTokenAddress;
        path[1] = usLPs[lpAddress];

        return IUniswapRouter(usRouter1).getAmountsOut(amountsIn, path)[1];
    }

    function removeLP(address tokenAddress)
        internal
        returns (address lpAddress)
    {
        lpAddress = getLPAddress(tokenAddress);

        usLPs[lpAddress] = address(0);
        usLPs[tokenAddress] = address(0);

        emit LPRemoved(tokenAddress, lpAddress);

        return lpAddress;
    }

    function isUniswap(address addr) internal view returns (bool) {
        return isUniswapLP(addr) || isUniswapRouter(addr);
    }

    function isUniswapLP(address addr) internal view returns (bool) {
        return usLPs[addr] != address(0);
    }

    function isUniswapRouter(address addr) internal view returns (bool) {
        return addr == usRouter1 || addr == usRouter2;
    }
}

