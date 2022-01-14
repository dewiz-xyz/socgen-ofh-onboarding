// Copyright (C) 2022 Clio Finance LLC <ops@clio.finance>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

/**
 * @title The OFH token minimum interface required to work with this wrapper.
 */
interface OFHTokenLike {
    function getBalance(address) external view returns (uint256);

    function transfer(address, uint256) external returns (bool);
}

/**
 * @author Henrique Barcelos <henrique@clio.finance>
 */
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
