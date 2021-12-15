// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface ITokenWrapper is IERC20 {
    function wrap(string calldata id, address gal) external;

    function unwrap(string calldata id) external;
}
