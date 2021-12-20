// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockOFH is ERC20 {
    constructor(uint256 amount_) public ERC20("SGF OFH Token", "OFH") {
        _mint(msg.sender, amount_);
        _setupDecimals(0);
    }
}
