// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {ITokenWrapper} from "./ITokenWrapper.sol";

interface OFHTokenLike {
    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (uint256);
}

/**
 */
contract TokenWrapper is ITokenWrapper, ERC20 {
    uint256 internal constant WAD = 10**18;

    OFHTokenLike public immutable token;

    mapping(address => uint256) public wards;
    mapping(address => uint256) public can;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Hope(address indexed usr);
    event Nope(address indexed usr);

    /**
     * @notice Creates a token wrapper for a OFH token implementation.
     * @param token_ The OFH token implementation.
     */
    constructor(OFHTokenLike token_) public ERC20("Wrapped OFH", "wOFH") {
        token = token_;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "TokenWrapper/not-authorized");
        _;
    }

    modifier operator() {
        require(can[msg.sender] == 1, "TokenWrapper/not-operator");
        _;
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function hope(address usr) external auth {
        can[usr] = 1;
        emit Hope(usr);
    }

    function nope(address usr) external auth {
        can[usr] = 0;
        emit Nope(usr);
    }

    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `gal`'s balance.
     * @dev The `totalSupply` of the wrapped token MUST be less than or equal to the underlying token balance of the current contract.
     * @param gal The address to receive the minted wrapped tokens.
     * @param value The value to be wrapped.
     */
    function wrap(address gal, uint256 value) external override operator {
        doWrap(gal, value);
    }

    /**
     * @notice Wraps the underlying token `value` and mints wrapper tokens into `msg.sender`'s balance.
     * @dev The `totalSupply` of the wrapped token MUST be less than or equal to the underlying token balance of the current contract.
     * @param value The value to be wrapped.
     */
    function wrap(uint256 value) external override operator {
        doWrap(msg.sender, value);
    }

    /**
     * @dev Wraps the underlying token `value` and mints wrapper tokens into `msg.sender`'s balance.
     * @param value The value to be wrapped.
     */
    function doWrap(address gal, uint256 value) private {
        // Normalize the amount to have 18 decimals. We assume that `token` has 0 decimals.
        uint256 wad = value.mul(WAD);
        require(totalSupply().add(wad) <= token.balanceOf(address(this)).mul(WAD), "TokenWrapper/insufficient-balance");
        _mint(gal, wad);
    }

    /**
     * TODO: what should be done when users will end up with only fractions of the token?
     * (ES is one example, but there could be others.)
     * In this case the `_burn` balance check will fail and the tokens will be stuck in the contract
     * until the user can get a hold of a full token.
     * This could potentially lead to a griefing attack where a single party can deny the unwraping of
     * tokens simply by refusing to collaborate in a token aggregation.
     *
     * @notice Unwraps the tokens by burning the due amount.
     * @param gal The address to receive the underlying tokens.
     * @param value The value to be unwrapped.
     */
    function unwrap(address gal, uint256 value) public override {
        // Normalize the amount to have 18 decimals. We assume that `token` has 0 decimals.
        uint256 wad = value.mul(WAD);
        _burn(msg.sender, wad);
        token.transfer(gal, value);
    }

    /**
     * @notice Unwraps the tokens by burning the due amount. Sends the underlying tokens to `msg.sender`.
     * @param value The value to be unwrapped.
     */
    function unwrap(uint256 value) external override {
        unwrap(msg.sender, value);
    }
}
