// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface ITokenWrapper is IERC20 {
    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `gal`'s balance.
     * @dev The `totalSupply` of the wrapped token MUST be less than or equal to the underlying token balance of the current contract.
     * @param gal The address to receive the minted wrapped tokens.
     * @param value The value to be wrapped.
     */
    function wrap(address gal, uint256 value) external;

    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `msg.sender`'s balance.
     * @dev The `totalSupply` of the wrapped token MUST be less than or equal to the underlying token balance of the current contract.
     * @param value The value to be wrapped.
     */
    function wrap(uint256 value) external;

    /**
     * @notice Unwraps the tokens by burning the due amount.
     * @param gal The address to receive the underlying tokens.
     * @param value The value to be unwrapped.
     */
    function unwrap(address gal, uint256 value) external;

    /**
     * @notice Unwraps the tokens by burning the due amount. Sends the underlying tokens to `msg.sender`.
     * @param value The value to be unwrapped.
     */
    function unwrap(uint256 value) external;
}
