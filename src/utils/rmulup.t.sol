// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.12;

import {DSTest} from "ds-test/test.sol";
import {Rmulup} from "./rmulup.sol";

contract RmulupTest is DSTest {
    Rmulup internal instance;

    function setUp() public {
        instance = new Rmulup();
    }

    function testRmulupFuzz(uint128 a, uint128 b) public {
        // The result of rmulup is always greater than or equal the rmul result.
        assertGe(instance.rmulup(a, b), instance.rmul(a, b));
        // The difference between the results of rmulup and rmul is never greater than 1.
        assertLe(instance.rmulup(a, b) - instance.rmul(a, b), 1);
    }
}
