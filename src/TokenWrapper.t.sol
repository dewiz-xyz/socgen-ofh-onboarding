// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {DSGuard} from "ds-guard/guard.sol";
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

        guardAuthority.permit(address(wrapper), address(wrapper), bytes4(keccak256("mint(address,uint256)")));
    }

    function testOnlyExistingHoldCanBeWrapped() public {
        token.hold("Foo", address(1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Foo", address(1));

        assertEq(wrapper.balanceOf(address(1)), 400 * WAD);
    }

    function testFailAnyoneCanMint() public {
        // Changes the owner so the mint call fails.
        wrapper.setOwner(address(0));

        wrapper.mint(address(1), 400);
    }
}
