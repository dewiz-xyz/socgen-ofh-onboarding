// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSToken} from "ds-token/token.sol";
import {DSAuthority} from "ds-auth/auth.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";
import {ITokenWrapper} from "./ITokenWrapper.sol";

contract TokenWrapper is ITokenWrapper, DSToken {
    IHoldable public token;

    constructor(IHoldable token_, DSAuthority authority_) public DSToken("wOFH") {
        token = token_;
        setAuthority(authority_);
    }

    function wrap(
        string calldata id,
        address gal,
        uint256 wad
    ) external override {
        mint(gal, wad);
    }

    function unwrap(string calldata id) external override {}
}
