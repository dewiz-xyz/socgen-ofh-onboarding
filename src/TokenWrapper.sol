// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ITokenWrapper} from "./ITokenWrapper.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";

/**
 */
contract TokenWrapper is ITokenWrapper, ERC20 {
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
    constructor(IHoldable token_) public ERC20("Wrapped OFH", "wOFH") {
        token = token_;
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

        _mint(gal, value * WAD);
    }

    function unwrap(string calldata id) external override {
        (, , address notary, , , ) = token.retrieveHoldData(id);
        require(notary == address(this), "token-wrapper-is-not-notary");

        address gal = wrapInfo[id].gal;
        _burn(gal, wrapInfo[id].wad);

        token.releaseHold(id);
    }
}
