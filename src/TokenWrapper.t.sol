// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {TokenWrapper} from "./TokenWrapper.sol";
import {IHoldable} from "./eip-1996/IHoldable.sol";
import {MockOFH} from "./mock/MockOFH.sol";
import {ForwardProxy} from "./util/ForwardProxy.sol";

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

    Hevm internal hevm;

    IHoldable internal token;
    TokenWrapper internal wrapper;
    address internal holder1;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 internal constant CHEAT_CODE = bytes20(uint160(uint256(keccak256("hevm cheat code"))));

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        token = new MockOFH(400);
        wrapper = new TokenWrapper(token);
        holder1 = address(new ForwardProxy(address(wrapper)));
    }

    function testExistingHoldCanBeWrapped() public {
        token.hold("Foo", address(holder1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Foo", address(holder1));

        assertEq(wrapper.balanceOf(address(holder1)), 400 * WAD);
    }

    function testWrappedHoldCanBeUnwrapped() public {
        token.hold("Foo", address(holder1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Foo", address(holder1));

        TokenWrapper(holder1).unwrap("Foo");

        assertEq(wrapper.balanceOf(address(holder1)), 0);
    }

    function testFailUnwrapUnexistentToken() public {
        token.hold("Foo", address(holder1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Bar", address(holder1));
    }

    function testFailUnwrapAfterTransfer() public {
        token.hold("Foo", address(holder1), address(wrapper), 400, block.timestamp + 365 days);
        wrapper.wrap("Foo", address(holder1));

        TokenWrapper(holder1).transfer(address(0), 1);

        TokenWrapper(holder1).unwrap("Foo");
    }
}
