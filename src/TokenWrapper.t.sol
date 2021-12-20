// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {TokenWrapper, OFHTokenLike} from "./TokenWrapper.sol";
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

    MockOFH internal token;
    TokenWrapper internal wrapper;
    address internal holder1;
    address internal holder2;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 internal constant CHEAT_CODE = bytes20(uint160(uint256(keccak256("hevm cheat code"))));

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        token = new MockOFH(400);
        wrapper = new TokenWrapper(OFHTokenLike(address(token)));
        holder1 = address(new ForwardProxy(address(wrapper)));
        holder2 = address(new ForwardProxy(address(wrapper)));

        wrapper.hope(address(this));
    }

    function invariantTotalSupply() public {
        assertLe(wrapper.totalSupply(), token.balanceOf(address(wrapper)));
    }

    /**
     * Since we are using WAD math, the safest number we can operate on is:
     *      (2**256 - 1) / 10**18
     * This number can be represented with:
     *       log2((2**256 - 1)/10**18) = 196.295 ~= 197 bits
     * So the max safe uint we can use is uint192.
     */
    function testWrap(
        uint192 total,
        uint192 transferred,
        uint192 wrapped
    ) public {
        token = new MockOFH(total);
        wrapper = new TokenWrapper(OFHTokenLike(address(token)));
        wrapper.hope(address(this));

        if (total < transferred || transferred < wrapped) {
            // Testing in these cases doesn't make sense, so we make it pass
            return;
        }

        token.transfer(address(wrapper), transferred);
        wrapper.wrap(holder1, wrapped);

        assertEq(wrapper.balanceOf(holder1), wrapped * WAD);
    }

    function testWrapOwnAddress(
        uint192 total,
        uint192 transferred,
        uint192 wrapped
    ) public {
        token = new MockOFH(total);
        wrapper = new TokenWrapper(OFHTokenLike(address(token)));
        holder1 = address(new ForwardProxy(address(wrapper)));
        holder2 = address(new ForwardProxy(address(wrapper)));
        wrapper.hope(holder1);

        if (total < transferred || transferred < wrapped) {
            // Testing in these cases doesn't make sense, so we make it pass
            return;
        }

        token.transfer(address(wrapper), transferred);
        TokenWrapper(holder1).wrap(wrapped);

        assertEq(wrapper.balanceOf(holder1), wrapped * WAD);
    }

    function testFailWrapInsufficientBalance(
        uint192 total,
        uint192 transferred,
        uint192 wrapped
    ) public {
        token = new MockOFH(total);
        wrapper = new TokenWrapper(OFHTokenLike(address(token)));
        wrapper.hope(address(this));

        if (total < transferred || transferred >= wrapped) {
            // Testing in these cases doesn't make sense, so we make it pass
            revert();
        }

        token.transfer(address(wrapper), transferred);
        wrapper.wrap(holder1, wrapped);
    }

    function testAnyoneCanUnwrap() public {
        token.transfer(address(wrapper), 100);
        wrapper.wrap(holder1, 100);

        TokenWrapper(holder1).unwrap(holder1, 100);
        assertEq(wrapper.balanceOf(holder1), 0);
    }

    function testAnyoneCanUnwrapToOwnAddress() public {
        token.transfer(address(wrapper), 100);
        wrapper.wrap(holder1, 100);

        TokenWrapper(holder1).unwrap(100);
        assertEq(wrapper.balanceOf(holder1), 0);
    }

    function testFailUnwrapMoreThanBalance() public {
        token.transfer(address(wrapper), 100);
        wrapper.wrap(holder1, 100);

        TokenWrapper(holder1).unwrap(holder1, 101);
    }
}
