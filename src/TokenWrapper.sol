// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSToken} from "ds-token/token.sol";
import {DSAuthority} from "ds-auth/auth.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";
import {ITokenWrapper} from "./ITokenWrapper.sol";

contract TokenWrapper is ITokenWrapper, DSToken {
    IHoldable public immutable token;

    constructor(IHoldable token_, DSAuthority authority_) public DSToken("wOFH") {
        token = token_;
        setAuthority(authority_);
    }

    function wrap(string calldata id, address gal) external override {
        (, , address notary, uint256 value, uint256 expiration, IHoldable.HoldStatusCode status) = token
            .retrieveHoldData(id);

        require(notary == address(this), "token-wrapper-is-not-notary");
        require(status == IHoldable.HoldStatusCode.Ordered, "hold-not-ordered");
        // TODO: Should we add a minimum expiration requirement here?
        require(expiration > block.timestamp, "hold-expired");

        mint(gal, value * WAD);
    }

    function unwrap(string calldata id) external override {
        (, , address notary, , , ) = token.retrieveHoldData(id);

        require(notary == address(this), "token-wrapper-is-not-notary");

        token.releaseHold(id);
    }
}
