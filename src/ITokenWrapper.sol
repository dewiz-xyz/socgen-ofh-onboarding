// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {IHoldable} from "./eip-1996/IHoldable.sol";

interface ITokenWrapper {
    function wrap(
        string calldata id,
        address gal,
        uint256 wad
    ) external;

    function unwrap(string calldata id) external;
}
