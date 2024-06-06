// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UniswapConnect {
    address usRouter1;
    address usRouter2;
    bytes32 usInitCodeHash;
    address usFactoryAddress;

    mapping(address => bool) usLPs;

    constructor(
        address uniswapFactoryAddress,
        address uniswapRouterAddress1,
        address uniswapRouterAddress2,
        bytes32 uniswapInitCodeHash
    ) {
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
        address selfAddress = address(this);
        (address token0, address token1) = selfAddress < tokenAddress
            ? (selfAddress, tokenAddress)
            : (tokenAddress, selfAddress);

        bytes32 hash = keccak256(
            abi.encodePacked(
                hex"ff",
                usFactoryAddress,
                keccak256(abi.encodePacked(token0, token1)),
                usInitCodeHash // init code hash excluding the bytecode metadata, sourced from the Uniswap V2 core repository
            )
        );
        return address(uint160(uint256(hash)));
    }

    function addLP(address tokenAddress) internal {
        usLPs[getLPAddress(tokenAddress)] = true;
    }

    function removeLP(address tokenAddress) internal {
        usLPs[getLPAddress(tokenAddress)] = false;
    }

    function isUniswap(address addr) internal view returns (bool) {
        return usLPs[addr] || addr == usRouter1 || addr == usRouter2;
    }

    function isUniswapLP(address addr) internal view returns (bool) {
        return usLPs[addr];
    }

    function isUniswapRouter(address addr) internal view returns (bool) {
        return addr == usRouter1 || addr == usRouter2;
    }
}

