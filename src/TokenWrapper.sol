// Copyright (C) 2022 Dai Foundation
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

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ITokenWrapper, OFHTokenLike} from "./ITokenWrapper.sol";

/**
 * @author Henrique Barcelos <henrique@clio.finance>
 * @title Wraps the underlying OFH token and mints equivalent wOFH.
 * @dev Assumes OFH has `0` decimals (integer/non-fractional token) and normalizes `mint()/burn()` to have `18` decimals.
 */
contract TokenWrapper is ITokenWrapper, ERC20 {
    /// @notice OFH token contract address
    OFHTokenLike public immutable token;

    /// @notice Addresses with admin access on this contract. `wards[usr]`
    mapping(address => uint256) public wards;
    /// @notice Addresses with push access on this contract. `can[usr]`
    mapping(address => uint256) public can;

    /**
     * @notice `usr` was granted admin access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` admin access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);
    /**
     * @notice `usr` was granted operator access.
     * @param usr The user address.
     */
    event Hope(address indexed usr);
    /**
     * @notice `usr` operator access was revoked.
     * @param usr The user address.
     */
    event Nope(address indexed usr);

    modifier auth() {
        require(wards[msg.sender] == 1, "TokenWrapper/not-authorized");
        _;
    }

    modifier operator() {
        require(can[msg.sender] == 1, "TokenWrapper/not-operator");
        _;
    }

    /**
     * @notice Creates a token wrapper for a OFH token logic implementation.
     * @param token_ The OFH token deployed address.
     */
    constructor(address token_) public ERC20("Wrapped OFH", "wOFH") {
        token = OFHTokenLike(token_);

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    /**
     * @notice Grants `usr` admin access to this contract.
     * @param usr The user address.
     */
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    /**
     * @notice Revokes `usr` admin access from this contract.
     * @param usr The user address.
     */
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    /**
     * @notice Grants `usr` operator access to this contract.
     * @param usr The user address.
     */
    function hope(address usr) external auth {
        can[usr] = 1;
        emit Hope(usr);
    }

    /**
     * @notice Revokes `usr` operator access from this contract.
     * @param usr The user address.
     */
    function nope(address usr) external auth {
        can[usr] = 0;
        emit Nope(usr);
    }

    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `gal`'s balance.
     * @param gal The address to receive the minted wrapped tokens.
     * @param value The integer token value to be wrapped.
     */
    function wrap(address gal, uint256 value) external override operator {
        doWrap(gal, value);
    }

    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `msg.sender`'s balance.
     * @param value The integer token value to be wrapped.
     */
    function wrap(uint256 value) external override operator {
        doWrap(msg.sender, value);
    }

    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `msg.sender`'s balance.
     * @dev The `totalSupply` of the wrapped token MUST be less than or equal to the underlying token balance of the current contract at all times.
     * @param gal The address to receive the minted wrapped tokens.
     * @param value The integer token value to be wrapped.
     */
    function doWrap(address gal, uint256 value) private {
        // Normalizes the amount to have 18 decimals. Assumes that `token` has 0 decimals.
        uint256 wad = DSMathCustom.wad(value);
        require(
            totalSupply().add(wad) <= DSMathCustom.wad(token.getBalance(address(this))),
            "TokenWrapper/insufficient-balance"
        );
        _mint(gal, wad);
    }

    /**
     * @notice Unwraps the tokens by burning the due amount.
     * @param gal The address to receive the underlying tokens.
     * @param value The integer token value to be unwrapped.
     * @dev Contract expects "value" amount to be a whole/non-fractional WOFH token. Fractional balances cannot be unwrapped.
     */
    function unwrap(address gal, uint256 value) public override {
        // Normalizes the amount to have 18 decimals. Assumes that `token` has 0 decimals.
        uint256 wad = DSMathCustom.wad(value);
        _burn(msg.sender, wad);
        require(token.transfer(gal, value), "TokenWrapper/transfer-failed");
    }

    /**
     * @notice Unwraps the tokens by burning the due amount. Sends the underlying tokens to `msg.sender`.
     * @param value The integer token value to be unwrapped.
     */
    function unwrap(uint256 value) external override {
        unwrap(msg.sender, value);
    }
}

/**
 * @title An extension/subset of `DSMath` containing only the methods required in this file.
 * @dev TokenWrapper contract directly uses 'wad' method for unit conversion.
 */
library DSMathCustom {
    uint256 internal constant WAD = 10**18;

    /**
     * @dev Safe multiplication function to avoid uint256 overflows
     */
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "DSMath/mul-overflow");
    }

    /**
     * @dev Converts a uint256 value `val` into a `wad` (10^18) by multiplying it by WAD (10^18).
     *  - wad: used for token balances
     *  - ray: used for interest rates
     *  - rad: used for Dai balances inside the Vat
     */
    function wad(uint256 val_) internal pure returns (uint256 z) {
        return mul(val_, WAD);
    }
}
