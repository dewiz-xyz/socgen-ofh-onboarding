// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ITokenWrapper} from "./ITokenWrapper.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";

/**
 */
contract TokenWrapper is ITokenWrapper, ERC20 {
    uint256 internal constant WAD = 10**18;

    IHoldable public immutable token;

    /**
     * @notice Creates a token wrapper for a holdable token implementation.
     * @param token_ The holdable token implementation.
     */
    constructor(IHoldable token_) public ERC20("Wrapped OFH", "wOFH") {
        token = token_;
    }

    /**
     * @notice Wraps the value under hold identified by `id` and mints wrapper tokens into `gal`'s balance.
     * @dev We assume `value` from `retrieveHoldData` cannot be changed.
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

        // Normalize the amount
        _mint(gal, value.mul(WAD));
    }

    /**
     * @notice Unwraps the tokens by burning the due amount
     * @dev We require only that the sender's balance to be equal the value of the hold. This improves fungibility.
     * @param id The id of the hold operation.
     */
    function unwrap(string calldata id) external override {
        (, , address notary, uint256 value, , ) = token.retrieveHoldData(id);
        require(notary == address(this), "token-wrapper-is-not-notary");

        _burn(msg.sender, value.mul(WAD));
        token.releaseHold(id);
    }
}
