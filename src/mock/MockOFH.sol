// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {Holdable} from "../eip-1996/Holdable.sol";

contract MockOFH is Holdable {
    constructor(uint256 amount_) public Holdable("SGF OFH Token", "OFH") {
        _mint(msg.sender, amount_);
        _setupDecimals(0);
    }
}
