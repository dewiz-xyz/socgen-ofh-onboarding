// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {TokenWrapper} from "./TokenWrapper.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";
import {MockOFH} from "./mock/MockOFH.sol";

interface Hevm {
    function warp(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;

    function load(address, bytes32) external view returns (bytes32);
}

contract TokenWrapperTest is DSTest {
    uint256 internal constant WAD = 10**18;

    Hevm hevm;

    DSGuard internal guardAuthority;
    TokenWrapper internal wrapper;
    IHoldable internal token;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 internal constant CHEAT_CODE = bytes20(uint160(uint256(keccak256("hevm cheat code"))));

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        guardAuthority = new DSGuard();
        token = new MockOFH(400);
        wrapper = new TokenWrapper(token, guardAuthority);
    }

    function testExistingHoldCanBeWrapped() public {
        wrapper.setOwner(address(0));

        token.hold("Foo", address(1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Foo", address(1));

        assertEq(wrapper.balanceOf(address(1)), 400 * WAD);
    }

    function testWrappedHoldCanBeUnwrapped() public {
        token.hold("Foo", address(1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Foo", address(1));

        wrapper.unwrap("Foo");

        assertEq(wrapper.balanceOf(address(1)), 0);
    }

    function testFailOnlyExistingHoldCanBeWrapped() public {
        token.hold("Foo", address(1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Bar", address(1));
    }
}
