// Copyright (C) 2020, 2021 Lev Livnev <lev@liv.nev.org.uk>
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
pragma solidity >=0.6.8 <0.7.0;

import {DSTest} from "ds-test/test.sol";
import {DSToken, DSAuthority} from "ds-token/token.sol";
import {DSMath} from "ds-math/math.sol";

import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Spotter} from "dss/spot.sol";

import {DaiJoin} from "dss/join.sol";
import {AuthGemJoin} from "dss-gem-joins/join-auth.sol";

import {OFHTokenLike} from "./tokens/ITokenWrapper.sol";
import {TokenWrapper} from "./tokens/TokenWrapper.sol";
import {MockOFH} from "./tokens/mocks/MockOFH.sol";
import {ForwardProxy} from "./utils/ForwardProxy.sol";
import {RwaInputConduit2} from "./RwaInputConduit2.sol";
import {RwaOutputConduit2} from "./RwaOutputConduit2.sol";
import {RwaLiquidationOracle} from "./RwaLiquidationOracle.sol";
import {RwaUrn2} from "./RwaUrn2.sol";
import {RwaUrnUtils} from "./RwaUrnUtils.sol";

interface Hevm {
    function warp(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;

    function load(address, bytes32) external returns (bytes32);
}

contract NullAuthority is DSAuthority {
    function canCall(
        address,
        address,
        bytes4
    ) external view override returns (bool) {
        return true;
    }
}

contract M is DSMath {
    function wad(uint256 rad) internal pure returns (uint256 z) {
        return rad / RAY;
    }

    function rad(uint256 wad) internal pure returns (uint256 z) {
        return mul(wad, RAY);
    }

    function rmulup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY - 1) / RAY;
    }
}

contract RwaUrnUtilsTest is DSTest, M {
    bytes20 internal constant CHEAT_CODE = bytes20(uint160(uint256(keccak256("hevm cheat code"))));

    Hevm internal hevm;

    DSToken internal dai;
    TokenWrapper internal wrapper;
    MockOFH internal token;

    Vat internal vat;
    Jug internal jug;
    Spotter internal spotter;
    address internal constant VOW = address(123);

    DaiJoin internal daiJoin;
    AuthGemJoin internal gemJoin;

    RwaLiquidationOracle internal oracle;
    RwaUrn2 internal urn;

    RwaOutputConduit2 internal outConduit;
    RwaInputConduit2 internal inConduit;

    address payable internal op;
    address payable internal mate;
    address payable internal rec;
    address payable internal gov;

    RwaUrnUtils internal urnUtils;

    // Debt ceiling of 1000 DAI
    string internal constant DOC = "Please sign this";
    uint256 internal constant CEILING = 400 ether;
    uint256 internal constant EIGHT_PCT = 1000000002440418608258400030;
    uint256 internal constant URN_GEM_CAP = 400 ether;

    uint48 internal constant TAU = 2 weeks;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        hevm.warp(104411200);

        token = new MockOFH(500);
        wrapper = new TokenWrapper(address(token));
        wrapper.hope(address(this));

        vat = new Vat();

        jug = new Jug(address(vat));
        jug.file("vow", VOW);
        vat.rely(address(jug));

        dai = new DSToken("Dai");
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));
        dai.setAuthority(new NullAuthority());
        dai.setOwner(address(daiJoin));

        vat.init("RWA008AT1-A");
        vat.file("Line", 100 * rad(CEILING));
        vat.file("RWA008AT1-A", "line", rad(CEILING));

        jug.init("RWA008AT1-A");
        jug.file("RWA008AT1-A", "duty", EIGHT_PCT);

        oracle = new RwaLiquidationOracle(address(vat), VOW);
        oracle.init("RWA008AT1-A", wmul(CEILING, 1.1 ether), DOC, TAU);
        vat.rely(address(oracle));
        (, address pip, , ) = oracle.ilks("RWA008AT1-A");

        spotter = new Spotter(address(vat));
        vat.rely(address(spotter));
        spotter.file("RWA008AT1-A", "mat", RAY);
        spotter.file("RWA008AT1-A", "pip", pip);
        spotter.poke("RWA008AT1-A");

        gemJoin = new AuthGemJoin(address(vat), "RWA008AT1-A", address(wrapper));
        vat.rely(address(gemJoin));

        outConduit = new RwaOutputConduit2(address(dai));

        urn = new RwaUrn2(
            address(vat),
            address(jug),
            address(gemJoin),
            address(daiJoin),
            address(outConduit),
            URN_GEM_CAP
        );
        gemJoin.rely(address(urn));
        inConduit = new RwaInputConduit2(address(dai), address(urn));

        op = payable(new ForwardProxy(address(0)));
        mate = payable(new ForwardProxy(address(0)));
        rec = payable(new ForwardProxy(address(0)));
        gov = payable(new ForwardProxy(address(0)));

        urnUtils = new RwaUrnUtils();

        // Wraps all tokens into `op` balance
        token.transfer(address(wrapper), 500);
        wrapper.wrap(op, 500);

        urn.hope(op);
        urn.hope(address(urnUtils));
        urn.rely(gov);

        outConduit.hope(op);
        outConduit.mate(mate);

        inConduit.mate(mate);
        inConduit.mate(address(urnUtils));

        ForwardProxy(op).updateForwardTo(address(wrapper));
        TokenWrapper(op).approve(address(urn), type(uint256).max);

        ForwardProxy(rec).updateForwardTo(address(dai));
        TokenWrapper(rec).approve(address(urnUtils), type(uint256).max);
    }

    function testFullRepayment() public {
        ForwardProxy(op).updateForwardTo(address(urn));
        RwaUrn2(op).lock(1 ether);
        RwaUrn2(op).draw(400 ether);

        ForwardProxy(op).updateForwardTo(address(outConduit));
        RwaOutputConduit2(op).pick(rec);

        ForwardProxy(mate).updateForwardTo(address(outConduit));
        RwaOutputConduit2(mate).push();

        // Fast-forward 30 day
        hevm.warp(block.timestamp + 30 days);
        // Mints some additional Dai into the receiver's balance to cope with accrued fees
        mintDai(rec, 10 ether);

        // Makes sure daiJoin has enought Dai available
        mintDai(address(daiJoin), 100 ether);

        uint256 expectedAmount = urnUtils.estimateWipeAllWad(address(urn), block.timestamp);
        uint256 recBalanceBefore = dai.balanceOf(rec);

        urnUtils.pushAndWipeAll(address(urn), address(inConduit), rec);

        uint256 recBalanceAfter = dai.balanceOf(rec);

        // Get the remaining debt in the urn
        (, uint256 art) = vat.urns("RWA008AT1-A", address(urn));
        // If the value is >0, it must revert
        assertEq(art, 0);
        assertEq(recBalanceBefore - recBalanceAfter, expectedAmount);
    }

    function testFullRepaymentWhenUrnHasOutstandingDai() public {
        ForwardProxy(op).updateForwardTo(address(urn));
        RwaUrn2(op).lock(1 ether);
        RwaUrn2(op).draw(400 ether);

        ForwardProxy(op).updateForwardTo(address(outConduit));
        RwaOutputConduit2(op).pick(rec);

        ForwardProxy(mate).updateForwardTo(address(outConduit));
        RwaOutputConduit2(mate).push();

        // Fast-forward 30 day
        hevm.warp(block.timestamp + 30 days);

        // Mints some additional Dai into the receiver's balance to cope with accrued fees
        mintDai(rec, 10 ether);
        // Mints some additional Dai into the urn
        mintDai(address(urn), 50 ether);

        // Makes sure daiJoin has enought Dai available
        mintDai(address(daiJoin), 100 ether);

        uint256 recBalanceBefore = dai.balanceOf(rec);
        uint256 urnBalanceBefore = dai.balanceOf(address(urn));
        uint256 expectedAmount = urnUtils.estimateWipeAllWad(address(urn), block.timestamp);

        urnUtils.pushAndWipeAll(address(urn), address(inConduit), rec);

        uint256 recBalanceAfter = dai.balanceOf(rec);

        assertEq(recBalanceBefore - recBalanceAfter, expectedAmount - urnBalanceBefore);
    }

    function testFailFullRepaymentWhenPayerHasNotEnoughDai() public {
        ForwardProxy(op).updateForwardTo(address(urn));
        RwaUrn2(op).lock(1 ether);
        RwaUrn2(op).draw(400 ether);

        ForwardProxy(op).updateForwardTo(address(outConduit));
        RwaOutputConduit2(op).pick(rec);

        ForwardProxy(mate).updateForwardTo(address(outConduit));
        RwaOutputConduit2(mate).push();

        // Fast-forward 30 day
        hevm.warp(block.timestamp + 30 days);

        // Makes sure daiJoin has enought Dai available
        mintDai(address(daiJoin), rad(10 ether));

        urnUtils.pushAndWipeAll(address(urn), address(inConduit), rec);
    }

    function mintDai(address who, uint256 wad) internal {
        dai.mint(who, wad);
        vat.suck(VOW, who, rad(wad));
    }
}
