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
pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {ForwardProxy} from "forward-proxy/ForwardProxy.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {OFHTokenLike} from "./ITokenWrapper.sol";
import {TokenWrapper} from "./TokenWrapper.sol";
import {MockOFH} from "./mocks/MockOFH.sol";

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
    ForwardProxy internal holder1;
    ForwardProxy internal holder2;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 internal constant CHEAT_CODE = bytes20(uint160(uint256(keccak256("hevm cheat code"))));

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        token = new MockOFH(400);
        wrapper = new TokenWrapper(address(token));
        holder1 = new ForwardProxy();
        holder1._(address(wrapper));
        holder2 = new ForwardProxy();
        holder2._(address(wrapper));

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
        if (total < transferred || transferred < wrapped) {
            // Testing in these cases doesn't make sense, so we make it pass
            return;
        }

        token = new MockOFH(total);
        wrapper = new TokenWrapper(address(token));
        wrapper.hope(address(this));

        token.transfer(address(wrapper), transferred);
        wrapper.wrap(address(holder1), wrapped);

        assertEq(wrapper.balanceOf(address(holder1)), wrapped * WAD);
    }

    function testWrapOwnAddress(
        uint256 total,
        uint256 transferred,
        uint256 wrapped
    ) public {
        // Getting values that actually make sense
        total = (total % (type(uint192).max - 50)) + 50; // 50-(type(uint192).max - 1))
        transferred = (transferred % (total - 2)) + 2; // 2-(total - 1)
        wrapped = (wrapped % (transferred - 1)) + 1; // 1-(transferred - 1)

        token = new MockOFH(total);
        wrapper = new TokenWrapper(address(token));
        holder1 = new ForwardProxy();
        holder1._(address(wrapper));
        holder2 = new ForwardProxy();
        holder2._(address(wrapper));
        wrapper.hope(address(holder1));

        token.transfer(address(wrapper), transferred);
        TokenWrapper(address(holder1)).wrap(wrapped);

        assertEq(wrapper.balanceOf(address(holder1)), wrapped * WAD);
    }

    function testFailWrapInsufficientBalance(
        uint192 total,
        uint192 transferred,
        uint192 wrapped
    ) public {
        // Getting values that actually make sense
        total = (total % (type(uint192).max - 50)) + 50; // 50-(type(uint192).max - 1))
        transferred = (transferred % (total - 1)) + 1; // 1-(total - 1)
        wrapped = (wrapped % (total - transferred)) + transferred + 1; // (trasnferred+1)-total

        token = new MockOFH(total);
        wrapper = new TokenWrapper(address(token));
        wrapper.hope(address(this));

        token.transfer(address(wrapper), transferred);
        wrapper.wrap(address(holder1), wrapped);
    }

    function testAnyoneCanUnwrap() public {
        token.transfer(address(wrapper), 100);
        wrapper.wrap(address(holder1), 100);

        TokenWrapper(address(holder1)).unwrap(address(holder1), 100);
        assertEq(wrapper.balanceOf(address(holder1)), 0);
    }

    function testAnyoneCanUnwrapToOwnAddress() public {
        token.transfer(address(wrapper), 100);
        wrapper.wrap(address(holder1), 100);

        TokenWrapper(address(holder1)).unwrap(100);
        assertEq(wrapper.balanceOf(address(holder1)), 0);
    }

    function testFailUnwrapMoreThanBalance() public {
        token.transfer(address(wrapper), 100);
        wrapper.wrap(address(holder1), 100);

        TokenWrapper(address(holder1)).unwrap(address(holder1), 101);
    }
}
