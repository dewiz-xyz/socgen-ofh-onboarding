// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSToken} from "ds-token/token.sol";
import {DSAuthority} from "ds-auth/auth.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";
import {ITokenWrapper} from "./ITokenWrapper.sol";

/**
 */
contract TokenWrapper is ITokenWrapper, DSToken {
    IHoldable public immutable token;

    struct WrapInfo {
        address gal;
        uint256 wad;
    }

    mapping(string => WrapInfo) public wrapInfo;

    /**
     * @notice Creates a token wrapper for a holdable token implementation.
     * @param token_ The holdable token implementation.
     * @param authority_ A DSAuthority implementation.
     */
    constructor(IHoldable token_, DSAuthority authority_) public DSToken("wOFH") {
        token = token_;
        setAuthority(authority_);
    }

    /**
     * @notice Wraps the value under hold identified by `id` and mints wrapper tokens into `gal`'s balance.
     * @dev We assume `token` has `0` decimals.
     * @param id The id of the hold operation.
     * @param gal The address to receive the minted wrapped tokens.
     */
    function wrap(string calldata id, address gal) external override {
        (, , address notary, uint256 value, uint256 expiration, IHoldable.HoldStatusCode status) = token
            .retrieveHoldData(id);
        require(notary == address(this), "token-wrapper-is-not-notary");
        require(status == IHoldable.HoldStatusCode.Ordered, "hold-not-ordered");
        // TODO: Should we add a minimum expiration requirement here?
        require(expiration > block.timestamp, "hold-expired");

        wrapInfo[id].gal = gal;
        wrapInfo[id].wad = value * WAD;

        allowance[address(this)][gal] = value * WAD;

        mint(gal, value * WAD);
    }

    function unwrap(string calldata id) external override {
        (, , address notary, , , ) = token.retrieveHoldData(id);
        require(notary == address(this), "token-wrapper-is-not-notary");

        address gal = wrapInfo[id].gal;
        burn(gal, wrapInfo[id].wad);

        token.releaseHold(id);
    }
}
