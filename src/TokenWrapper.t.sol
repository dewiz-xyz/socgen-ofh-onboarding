// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import { DSTest } from "ds-test/test.sol";
import { TokenWrapper } from "./TokenWrapper.sol";

contract TokenWrapperTest is DSTest {
    TokenWrapper wrapper;

    function setUp() public {
        wrapper = new TokenWrapper();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
