// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "ds-test/test.sol";

import "./SocgenOfhOnboardingPrototype.sol";

contract SocgenOfhOnboardingPrototypeTest is DSTest {
    SocgenOfhOnboardingPrototype prototype;

    function setUp() public {
        prototype = new SocgenOfhOnboardingPrototype();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
