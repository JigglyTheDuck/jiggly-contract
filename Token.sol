// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Composer.sol";
import "./TokenComposer.sol";
import "./ITokenComposer.sol";
import "./DAO.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Jiggly is ERC20, ERC20Permit {
    enum Proposals {
        EMPTY,
        CHANGE_DAO,
        CHANGE_COMPOSER,
        ADJUST_DECIMALS
    }

    address public dao;

    address public tokenComposer;

    uint8 _decimals;

    constructor() ERC20("Jiggly", "GLY") ERC20Permit("Jiggly") {
        _decimals = 9; // initially using gwei units for simplicity

        dao = address(new DAO());

        tokenComposer = address(new TokenComposer());

        _mint(tokenComposer, 41000000 gwei);

        _mint(msg.sender, 1000000 gwei);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function passProposal(Proposals proposal, address target) external {
        require(msg.sender == dao);

        // we only need to pass proposals of DAO or TokenComposer change here or decimals

        if (proposal == Proposals.CHANGE_DAO) {
            dao = target;
        } else if (proposal == Proposals.CHANGE_COMPOSER) {
            tokenComposer = target;
        } else if (proposal == Proposals.ADJUST_DECIMALS) {
            _decimals = target == address(1) && _decimals > 3
                ? _decimals - 1
                : _decimals + 1;
        } else {
            ITokenComposer(tokenComposer).passProposal(
                uint8(proposal) - uint8(type(Proposals).max),
                target
            );
        }
    }

    function composeAndTransfer(
        address from,
        address to,
        uint256 value
    ) internal {
        (address payer, uint256 toRewardPool) = ITokenComposer(tokenComposer)
            .composeAndGetRewardContribution(from, to, value);

        _transfer(from, to, value - toRewardPool);

        if (toRewardPool > 0) _transfer(payer, tokenComposer, toRewardPool);
    }

    // -- ERC 20 function overrides --

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        composeAndTransfer(from, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value)
        public
        override
        returns (bool)
    {
        address owner = _msgSender();
        composeAndTransfer(owner, to, value);
        return true;
    }
}

