// Copyright (C) 2022 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.12;

import {VatAbstract, JugAbstract, DaiJoinAbstract, GemJoinAbstract, DaiAbstract} from "dss-interfaces/Interfaces.sol";

interface RwaUrnLike {
    function vat() external view returns (VatAbstract);

    function jug() external view returns (JugAbstract);

    function daiJoin() external view returns (DaiJoinAbstract);

    function gemJoin() external view returns (GemJoinAbstract);

    function wipe(uint256 wad) external;
}

interface RwaInputConduitLike {
    function push() external;

    function to() external view returns (address);
}

/**
 * @author Henrique Barcelos <henrique@clio.finance>
 * @title Simplifies the interaction with vaults for Real-World Assets.
 */
contract RwaUrnProxyView {
    /**
     * @notice Estimates the amount of Dai required to fully repay a loan at `when` given time.
     * @dev It assumes there will be no changes in the base fee or the ilk stability fee between now and `when`.
     * @param urn The RwaUrn vault targeted by the repayment.
     * @param when The unix timestamp by which the repayment will be made. It must NOT be in the past.
     * @return wad The amount of Dai required to make a full repayment.
     */
    function estimateWipeAllWad(address urn, uint256 when) public view returns (uint256 wad) {
        require(when >= block.timestamp, "RwaUrnProxyView/invalid-date");

        // Law of Demeter anybody? https://en.wikipedia.org/wiki/Law_of_Demeter
        bytes32 ilk = RwaUrnLike(urn).gemJoin().ilk();
        VatAbstract vat = RwaUrnLike(urn).vat();
        JugAbstract jug = RwaUrnLike(urn).jug();

        (uint256 duty, uint256 rho) = jug.ilks(ilk);
        (, uint256 curr, , , ) = vat.ilks(ilk);
        // This was adapted from how the Jug calculates the rate on drip().
        // https://github.com/makerdao/dss/blob/master/src/jug.sol#L125
        uint256 rate = rmul(rpow(add(jug.base(), duty), when - rho), curr);

        (, uint256 art) = vat.urns(ilk, urn);

        wad = rmulup(art, rate);
    }

    /*//////////////////////////////////
                    Math
    //////////////////////////////////*/

    uint256 internal constant WAD = 10**18;
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
    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    /**
     * @dev Multiplies a WAD `x` by a `RAY` `y` and returns the WAD `z`.
     * Rounds up if the rad precision has some dust.
     */
    function rmulup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY - 1) / RAY;
    }

    /**
     * @dev This famous algorithm is called "exponentiation by squaring"
     * and calculates x^n with x as fixed-point and n as regular unsigned.
     *
     * It's O(log n), instead of O(n) for naive repeated multiplication.
     *
     * These facts are why it works:
     *
     *  If n is even, then x^n = (x^2)^(n/2).
     *  If n is odd,  then x^n = x * x^(n-1),
     *   and applying the equation for even x gives
     *    x^n = x * (x^2)^((n-1) / 2).
     *
     *  Also, EVM division is flooring and
     *    floor[(n-1) / 2] = floor[n / 2].
     */
    function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}
