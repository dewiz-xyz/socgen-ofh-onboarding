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

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {OFHTokenLike} from "../ITokenWrapper.sol";

/**
 * @author Henrique Barcelos <henrique@clio.finance>
 */
contract MockOFH is ERC20, OFHTokenLike {
    constructor(uint256 amount_) public ERC20("SGF OFH Token", "OFH") {
        _mint(msg.sender, amount_);
        _setupDecimals(0);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override(OFHTokenLike, ERC20) returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function getBalance(address who) public view override returns (uint256) {
        return balanceOf(who);
    }
}
