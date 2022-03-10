// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.12;

/**
 * Extracted the relevant functions from ../RwaUrnUtils.sol to be able to run fuzz tests for `rmulup`
 */
contract Rmulup {
    uint256 internal constant RAY = 10**27;

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "DSMath/add-overflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "DSMath/mul-overflow");
    }

    /**
     * @dev Multiplies a WAD `x` by a `RAY` `y` and returns the WAD `z`.
     * Rounds up if the rad precision dust >0.5 or down if <=0.5.
     * Rounds to zero if `x`*`y` < WAD / 2.
     */
    function rmul(uint256 x, uint256 y) public pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    /**
     * @dev Multiplies a WAD `x` by a `RAY` `y` and returns the WAD `z`.
     * Rounds up if the rad precision has some dust.
     */
    function rmulup(uint256 x, uint256 y) public pure returns (uint256 z) {
        z = add(mul(x, y), RAY - 1) / RAY;
    }
}
