// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {DSGuard} from "ds-guard/guard.sol";
import {TokenWrapper} from "./TokenWrapper.sol";
import {MockOFH} from "./mock/MockOFH.sol";

contract TokenWrapperTest is DSTest {
    DSGuard internal guardAuthority;
    TokenWrapper internal wrapper;

    function setUp() public {
        guardAuthority = new DSGuard();
        wrapper = new TokenWrapper(new MockOFH(400), guardAuthority);

        guardAuthority.permit(address(wrapper), address(wrapper), bytes4(keccak256("mint(address,uint256)")));
    }

    function test_wrap_can_mint() public {
        wrapper.wrap("Foo", address(1), 400);

        assertEq(wrapper.balanceOf(address(1)), 400);
    }

    function testFail_can_mint_directly() public {
        wrapper.mint(address(1), 400);
    }
}
