// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./IWrappedToken.sol";

contract WrappedToken is ERC20, ERC20Permit, IWrappedToken {
    struct LockedTokens {
        uint160 value;
        uint64 unlocksAt;
    }

    mapping(address => LockedTokens) public lockedTokens;

    address tokenComposerAddress;

    constructor(string memory symbol, string memory name)
        ERC20(name, symbol)
        ERC20Permit(name)
    {
        tokenComposerAddress = msg.sender;
    }

    function lockTokens(
        address addr,
        uint160 value,
        uint64 unlocksAt
    ) external {
        require(msg.sender == tokenComposerAddress);

        LockedTokens storage _lockedTokens = lockedTokens[addr];

        if (_lockedTokens.value > 0 && _lockedTokens.unlocksAt == unlocksAt) {
            _lockedTokens.value += value;
        } else {
            _lockedTokens.value = value;
            _lockedTokens.unlocksAt = unlocksAt;
        }
    }

    function isTransferAllowed(address addr, uint256 value)
        internal
        view
        returns (bool)
    {
        return
            balanceOf(addr) >=
            (value +
                (
                    lockedTokens[addr].unlocksAt > block.timestamp
                        ? lockedTokens[addr].value
                        : 0
                ));
    }

    function _wrap(address addr, uint256 value) internal virtual {
        _mint(addr, value);

        // how the tokens are transferred is up the implementing contract
    }

    function _unwrap(address addr, uint256 value) internal virtual {
        require(isTransferAllowed(addr, value));

        _burn(addr, value);

        // how the tokens are transferred is up the implementing contract
    }

    function wrap(uint256 value) public {
        _wrap(_msgSender(), value);
    }

    function unwrap(uint256 value) external {
        _unwrap(_msgSender(), value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        require(isTransferAllowed(from, value));
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint256 value)
        public
        override
        returns (bool)
    {
        address owner = _msgSender();
        require(isTransferAllowed(owner, value));
        _transfer(owner, to, value);
        return true;
    }
}

