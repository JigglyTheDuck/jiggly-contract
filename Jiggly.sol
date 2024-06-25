// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import "./TokenComposer.sol";
import "./ITokenComposer.sol";
import "./DAO.sol";

contract Jiggly is ERC20, ERC20Permit {
    enum Proposals {
        CHANGE_DAO,
        CHANGE_COMPOSER
    }

    address public dao;

    address public tokenComposer;

    constructor() ERC20("Jiggly", "GLY") ERC20Permit("Jiggly") {
        dao = address(new DAO());

        tokenComposer = address(new TokenComposer());

        _mint(tokenComposer, 1000000 gwei);
        _mint(msg.sender, 1000000 gwei);
    }

    function decimals() public view override returns (uint8) {
        return ITokenComposer(tokenComposer).decimals();
    }

    function passProposal(uint8 _proposal, address target) external {
        require(msg.sender == dao);
        uint8 max = uint8(type(Proposals).max);

        if (_proposal > max) {
            ITokenComposer(tokenComposer).passProposal(
                _proposal - max - 1,
                target
            );
            return;
        }

        Proposals proposal = Proposals(_proposal);

        if (proposal == Proposals.CHANGE_DAO) {
            dao = target;
        } else if (proposal == Proposals.CHANGE_COMPOSER) {
            _transfer(tokenComposer, target, balanceOf(tokenComposer));
            tokenComposer = target;
        }
    }

    function composeAndTransfer(
        address from,
        address to,
        uint256 value
    ) internal {
        if (from == tokenComposer || to == dao) {
            // rewards and votes are not taxed or compose
            _transfer(from, to, value);
            return;
        }

        uint256 toRewardPool = ITokenComposer(tokenComposer)
            .compose(from, to, value);

        _transfer(from, to, value - toRewardPool);

        if (toRewardPool > 0) _transfer(from, tokenComposer, toRewardPool);
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

