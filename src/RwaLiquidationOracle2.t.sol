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
import {DSToken} from "ds-token/token.sol";
import {DSMath} from "ds-math/math.sol";
import {DSValue} from "ds-value/value.sol";

import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Spotter} from "dss/spot.sol";

import {DaiJoin} from "dss/join.sol";
import {AuthGemJoin} from "dss-gem-joins/join-auth.sol";

import {OFHTokenLike} from "./tokens/ITokenWrapper.sol";
import {TokenWrapper} from "./tokens/TokenWrapper.sol";
import {MockOFH} from "./tokens/mocks/MockOFH.sol";
import {RwaInputConduit2} from "./RwaInputConduit2.sol";
import {RwaOutputConduit2} from "./RwaOutputConduit2.sol";
import {RwaUrn2} from "./RwaUrn2.sol";
import {RwaLiquidationOracle2} from "./RwaLiquidationOracle2.sol";

interface Hevm {
    function warp(uint256) external;

    function store(
        address,
        bytes32,
        bytes32
    ) external;
}

contract TokenUser {
    DSToken internal immutable dai;

    constructor(DSToken dai_) public {
        dai = dai_;
    }

    function transfer(address who, uint256 wad) external {
        dai.transfer(who, wad);
    }
}

contract TryCaller {
    function doCall(address addr, bytes memory data) external returns (bool) {
        assembly {
            let ok := call(gas(), addr, 0, add(data, 0x20), mload(data), 0, 0)
            let free := mload(0x40)
            mstore(free, ok)
            mstore(0x40, add(free, 32))
            revert(free, 32)
        }
    }

    function tryCall(address addr, bytes calldata data) external returns (bool ok) {
        (, bytes memory returned) = address(this).call(abi.encodeWithSignature("doCall(address,bytes)", addr, data));
        ok = abi.decode(returned, (bool));
    }
}

contract RwaOperator is TryCaller {
    RwaUrn2 internal urn;
    RwaOutputConduit2 internal outC;
    RwaInputConduit2 internal inC;

    constructor(
        RwaUrn2 urn_,
        RwaOutputConduit2 outC_,
        RwaInputConduit2 inC_
    ) public {
        urn = urn_;
        outC = outC_;
        inC = inC_;
    }

    function approve(
        TokenWrapper tok,
        address who,
        uint256 wad
    ) public {
        tok.approve(who, wad);
    }

    function pick(address who) public {
        outC.pick(who);
    }

    function lock(uint256 wad) public {
        urn.lock(wad);
    }

    function free(uint256 wad) public {
        urn.free(wad);
    }

    function draw(uint256 wad) public {
        urn.draw(wad);
    }

    function wipe(uint256 wad) public {
        urn.wipe(wad);
    }

    function canPick(address who) public returns (bool) {
        return this.tryCall(address(outC), abi.encodeWithSignature("pick(address)", who));
    }

    function canDraw(uint256 wad) public returns (bool) {
        return this.tryCall(address(urn), abi.encodeWithSignature("draw(uint256)", wad));
    }

    function canFree(uint256 wad) public returns (bool) {
        return this.tryCall(address(urn), abi.encodeWithSignature("free(uint256)", wad));
    }
}

contract RwaMate is TryCaller {
    RwaOutputConduit2 internal outC;
    RwaInputConduit2 internal inC;

    constructor(RwaOutputConduit2 outC_, RwaInputConduit2 inC_) public {
        outC = outC_;
        inC = inC_;
    }

    function pushOut() public {
        return outC.push();
    }

    function pushIn() public {
        return inC.push();
    }

    function canPushOut() public returns (bool) {
        return this.tryCall(address(outC), abi.encodeWithSignature("push()"));
    }

    function canPushIn() public returns (bool) {
        return this.tryCall(address(inC), abi.encodeWithSignature("push()"));
    }
}

contract RwaLiquidationOracle2Test is DSTest, DSMath {
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

    RwaLiquidationOracle2 internal oracle;
    RwaUrn2 internal urn;

    RwaOutputConduit2 internal outConduit;
    RwaInputConduit2 internal inConduit;

    RwaOperator internal op;
    RwaMate internal mate;
    TokenUser internal rec;

    // Debt ceiling of 1000 DAI
    string internal constant DOC = "Please sign this";
    uint256 internal constant CEILING = 400 ether;
    uint256 internal constant EIGHT_PCT = 1000000002440418608258400030;

    uint48 internal constant TAU = 2 weeks;

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * RAY;
    }

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        hevm.warp(104411200);

        token = new MockOFH(400);
        wrapper = new TokenWrapper(address(token));
        wrapper.hope(address(this));

        vat = new Vat();

        jug = new Jug(address(vat));
        jug.file("vow", VOW);
        vat.rely(address(jug));

        dai = new DSToken("Dai");
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));
        dai.setOwner(address(daiJoin));

        vat.init("RWA007");
        vat.file("Line", 100 * rad(CEILING));
        vat.file("RWA007", "line", rad(CEILING));

        jug.init("RWA007");
        jug.file("RWA007", "duty", EIGHT_PCT);

        oracle = new RwaLiquidationOracle2(address(vat), VOW);
        oracle.init("RWA007", 1.1 ether, DOC, TAU);
        vat.rely(address(oracle));
        (, address pip, , ) = oracle.ilks("RWA007");

        spotter = new Spotter(address(vat));
        vat.rely(address(spotter));
        spotter.file("RWA007", "mat", RAY);
        spotter.file("RWA007", "pip", pip);
        spotter.poke("RWA007");

        gemJoin = new AuthGemJoin(address(vat), "RWA007", address(wrapper));
        vat.rely(address(gemJoin));

        outConduit = new RwaOutputConduit2(address(dai));

        urn = new RwaUrn2(
            address(vat),
            address(jug),
            address(gemJoin),
            address(daiJoin),
            address(outConduit),
            400 ether
        );
        gemJoin.rely(address(urn));
        inConduit = new RwaInputConduit2(address(dai), address(urn));

        op = new RwaOperator(urn, outConduit, inConduit);
        mate = new RwaMate(outConduit, inConduit);
        rec = new TokenUser(dai);

        // Wraps all tokens into `op` balance
        token.transfer(address(wrapper), 400);
        wrapper.wrap(address(op), 400);

        urn.hope(address(op));

        inConduit.mate(address(mate));
        outConduit.mate(address(mate));
        outConduit.hope(address(op));
        outConduit.kiss(address(rec));

        op.approve(wrapper, address(urn), type(uint256).max);
    }

    function testCure() public {
        op.lock(400 ether);
        assertTrue(op.canDraw(1 ether));

        // Flashes the liquidation beacon
        vat.file("RWA007", "line", 0);

        oracle.tell("RWA007");

        assertTrue(!op.canDraw(10 ether));

        // Advances time before the remediation period expires
        hevm.warp(block.timestamp + TAU / 2);
        oracle.cure("RWA007");
        vat.file("RWA007", "line", rad(CEILING));

        assertTrue(oracle.good("RWA007"));

        assertEq(dai.balanceOf(address(rec)), 0);
        op.draw(100 ether);
        op.pick(address(rec));
        mate.pushOut();
        assertEq(dai.balanceOf(address(rec)), 100 ether);
    }

    function testFailCureUnknownIlk() public {
        oracle.cure("ecma");
    }

    function testFailCureNotInRemediation() public {
        oracle.cure("RWA007");
    }

    function testFailCureLiquidationCancelled() public {
        op.lock(400 ether);
        assertTrue(op.canDraw(1 ether));

        // Flashes the liquidation beacon
        vat.file("RWA007", "line", 0);
        oracle.tell("RWA007");

        // Borrowing not possible anymore
        assertTrue(!op.canDraw(1 ether));

        // Still in remediation period
        hevm.warp(block.timestamp + TAU / 2);
        assertTrue(oracle.good("RWA007"));

        // Cancels liquidation
        oracle.cure("RWA007");
        vat.file("RWA007", "line", rad(CEILING));
        assertTrue(oracle.good("RWA007"));

        oracle.cure("RWA007");
    }

    function testCull() public {
        // Lock the gem
        op.lock(400 ether);
        op.draw(200 ether);

        // Flashes the liquidation beacon
        vat.file("RWA007", "line", 0);
        oracle.tell("RWA007");

        hevm.warp(block.timestamp + TAU + 1 days);

        assertEq(vat.gem("RWA007", address(oracle)), 0);
        assertTrue(!oracle.good("RWA007"));

        oracle.cull("RWA007", address(urn));

        assertTrue(!op.canDraw(1 ether));

        spotter.poke("RWA007");
        (, , uint256 spot, , ) = vat.ilks("RWA007");
        assertEq(spot, 0);

        (uint256 ink, uint256 art) = vat.urns("RWA007", address(urn));
        assertEq(ink, 0);
        assertEq(art, 0);

        // The system debt is equal to the drawn amount
        assertEq(vat.sin(VOW), rad(200 ether));

        // After the write-off, the gem goes to the oracle
        assertEq(vat.gem("RWA007", address(oracle)), 400 ether);
    }

    function testUnremediedLoanIsNotGood() public {
        op.lock(400 ether);
        op.draw(100 ether);

        vat.file("RWA007", "line", 0);
        oracle.tell("RWA007");
        assertTrue(oracle.good("RWA007"));

        hevm.warp(block.timestamp + TAU + 1 days);
        assertTrue(!oracle.good("RWA007"));
    }

    function testCullMultipleUrns() public {
        RwaUrn2 urn2 = new RwaUrn2(
            address(vat),
            address(jug),
            address(gemJoin),
            address(daiJoin),
            address(outConduit),
            400 ether
        );
        gemJoin.rely(address(urn2));

        RwaOperator op2 = new RwaOperator(urn2, outConduit, inConduit);
        op.approve(wrapper, address(this), type(uint256).max);
        wrapper.transferFrom(address(op), address(op2), 200 ether);
        op2.approve(wrapper, address(urn2), type(uint256).max);
        urn2.hope(address(op2));

        op.lock(200 ether);
        op.draw(50 ether);

        op2.lock(200 ether);
        op2.draw(80 ether);

        assertTrue(op.canDraw(1 ether));
        assertTrue(op2.canDraw(1 ether));

        vat.file("RWA007", "line", 0);
        oracle.tell("RWA007");

        assertTrue(!op.canDraw(1 ether));
        assertTrue(!op2.canDraw(1 ether));

        hevm.warp(block.timestamp + TAU + 1 days);

        oracle.cull("RWA007", address(urn));
        assertEq(vat.sin(VOW), rad(50 ether));
        oracle.cull("RWA007", address(urn2));
        assertEq(vat.sin(VOW), rad(50 ether + 80 ether));
    }

    function testBumpCanIncreasePrice() public {
        // Bump the price of RWA007
        oracle.bump("RWA007", wmul(2 ether, 1.1 ether));
        spotter.poke("RWA007");

        (, address pip, , ) = oracle.ilks("RWA007");
        (bytes32 value, bool exists) = DSValue(pip).peek();

        assertEq(uint256(value), wmul(2 ether, 1.1 ether));
        assertTrue(exists);
    }

    function testPriceIncreaseExtendsDrawingLimit() public {
        op.lock(400 ether);
        op.draw(CEILING);

        op.pick(address(rec));
        mate.pushOut();

        // Debt ceiling was reached
        assertTrue(!op.canDraw(1 ether));

        // Increase the debt ceiling
        vat.file("RWA007", "line", rad(CEILING + 200 ether));

        // Still can't borrow much more because vault is unsafe
        assertTrue(op.canDraw(1 ether));
        assertTrue(!op.canDraw(200 ether));

        // Bump the price of RWA007
        oracle.bump("RWA007", wmul(2 ether, 1.1 ether));
        spotter.poke("RWA007");

        op.draw(200 ether);
        op.pick(address(rec));
        mate.pushOut();

        assertEq(dai.balanceOf(address(rec)), CEILING + 200 ether);
    }

    function testBumpCanDecreasePrice() public {
        // Bump the price of RWA007
        oracle.bump("RWA007", wmul(0.5 ether, 1.1 ether));
        spotter.poke("RWA007");

        (, address pip, , ) = oracle.ilks("RWA007");
        (bytes32 value, bool exists) = DSValue(pip).peek();

        assertEq(uint256(value), wmul(0.5 ether, 1.1 ether));
        assertTrue(exists);
    }

    function testPriceDecreaseReducesDrawingLimit() public {
        op.lock(400 ether);
        op.draw(200 ether);

        op.pick(address(rec));
        mate.pushOut();

        // Still can borrow up to the ceiling
        assertTrue(op.canDraw(200));

        // Bump the price of RWA007
        oracle.bump("RWA007", wmul(0.5 ether, 1.1 ether));
        spotter.poke("RWA007");

        // Cannot draw anymore because the decrease on the price
        assertTrue(!op.canDraw(100 ether));
    }

    function testFailBumpUnknownIlk() public {
        oracle.bump("ecma", wmul(2 ether, 1.1 ether));
    }

    function testFailBumpDuringLiquidation() public {
        vat.file("RWA007", "line", 0);
        oracle.tell("RWA007");
        oracle.bump("RWA007", wmul(2 ether, 1.1 ether));
    }
}
