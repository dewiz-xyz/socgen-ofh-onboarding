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
pragma solidity 0.6.12;

import {DSTest} from "ds-test/test.sol";
import {DSToken, DSAuthority} from "ds-token/token.sol";
import {DSMath} from "ds-math/math.sol";
import {ForwardProxy} from "forward-proxy/ForwardProxy.sol";

import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Spotter} from "dss/spot.sol";

import {DaiJoin} from "dss/join.sol";
import {AuthGemJoin} from "dss-gem-joins/join-auth.sol";

import {RwaToken} from "mip21-toolkit/tokens/RwaToken.sol";
import {RwaInputConduit2} from "mip21-toolkit/conduits/RwaInputConduit2.sol";
import {RwaOutputConduit2} from "mip21-toolkit/conduits/RwaOutputConduit2.sol";
import {RwaLiquidationOracle} from "mip21-toolkit/oracles/RwaLiquidationOracle.sol";
import {RwaUrn} from "mip21-toolkit/urns/RwaUrn.sol";
import {RwaUrnProxyView} from "./RwaUrnProxyView.sol";

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
    function wad(uint256 rad_) internal pure returns (uint256 z) {
        return rad_ / RAY;
    }

    function rad(uint256 wad_) internal pure returns (uint256 z) {
        return mul(wad_, RAY);
    }

    function rmulup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY - 1) / RAY;
    }
}

contract RwaUrnProxyViewTest is DSTest, M {
    bytes20 internal constant CHEAT_CODE = bytes20(uint160(uint256(keccak256("hevm cheat code"))));

    Hevm internal hevm;

    DSToken internal dai;
    RwaToken internal rwaToken;

    Vat internal vat;
    Jug internal jug;
    Spotter internal spotter;
    address internal constant VOW = address(123);

    DaiJoin internal daiJoin;
    AuthGemJoin internal gemJoin;

    RwaLiquidationOracle internal oracle;
    RwaUrn internal urn;

    RwaOutputConduit2 internal outConduit;
    RwaInputConduit2 internal inConduit;

    ForwardProxy internal op;
    ForwardProxy internal mate;
    ForwardProxy internal rec;
    ForwardProxy internal gov;

    RwaUrnProxyView internal urnProxyView;

    // Debt ceiling of 1000 DAI
    string internal constant DOC = "Please sign this";
    uint256 internal constant CEILING = 400 ether;
    uint256 internal constant EIGHT_PCT = 1000000002440418608258400030;

    uint48 internal constant TAU = 2 weeks;

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));
        hevm.warp(104411200);

        vat = new Vat();

        jug = new Jug(address(vat));
        jug.file("vow", VOW);
        vat.rely(address(jug));

        dai = new DSToken("Dai");
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));
        dai.setAuthority(new NullAuthority());
        dai.setOwner(address(daiJoin));

        vat.init("RWA008-A");
        vat.file("Line", 100 * rad(CEILING));
        vat.file("RWA008-A", "line", rad(CEILING));

        jug.init("RWA008-A");
        jug.file("RWA008-A", "duty", EIGHT_PCT);

        oracle = new RwaLiquidationOracle(address(vat), VOW);
        oracle.init("RWA008-A", wmul(CEILING, 1.1 ether), DOC, TAU);
        vat.rely(address(oracle));
        (, address pip, , ) = oracle.ilks("RWA008-A");

        spotter = new Spotter(address(vat));
        vat.rely(address(spotter));
        spotter.file("RWA008-A", "mat", RAY);
        spotter.file("RWA008-A", "pip", pip);
        spotter.poke("RWA008-A");

        rwaToken = new RwaToken("RWA008", "RWA-008");

        gemJoin = new AuthGemJoin(address(vat), "RWA008-A", address(rwaToken));
        vat.rely(address(gemJoin));

        outConduit = new RwaOutputConduit2(address(dai));

        urn = new RwaUrn(address(vat), address(jug), address(gemJoin), address(daiJoin), address(outConduit));
        gemJoin.rely(address(urn));
        inConduit = new RwaInputConduit2(address(dai), address(urn));

        op = new ForwardProxy();
        mate = new ForwardProxy();
        rec = new ForwardProxy();
        gov = new ForwardProxy();

        urnProxyView = new RwaUrnProxyView();

        urn.hope(address(op));
        urn.hope(address(urnProxyView));
        urn.rely(address(gov));

        outConduit.hope(address(op));
        outConduit.mate(address(mate));

        inConduit.mate(address(mate));
        inConduit.mate(address(urnProxyView));

        RwaToken(op._(address(rwaToken))).approve(address(urn), type(uint256).max);

        rwaToken.transfer(address(op), 1 ether);
    }

    function testFuzzRepayment(uint32 estimateDelay, uint32 repaymentDelay) public {
        // Between 1 and 2^32-1 seconds
        estimateDelay = (estimateDelay % (type(uint32).max - 1)) + 1;
        // Between estimateDelay and 2^32-1 seconds
        repaymentDelay = (repaymentDelay % (type(uint32).max - estimateDelay)) + estimateDelay;

        RwaUrn(op._(address(urn))).lock(1 ether);
        RwaUrn(op._(address(urn))).draw(400 ether);

        RwaOutputConduit2(op._(address(outConduit))).pick(address(rec));

        RwaOutputConduit2(mate._(address(outConduit))).push();

        uint256 estimatedAmount = urnProxyView.estimateWipeAllWad(address(urn), block.timestamp + estimateDelay);
        uint256 actualAmount = urnProxyView.estimateWipeAllWad(address(urn), block.timestamp + repaymentDelay);

        hevm.warp(block.timestamp + repaymentDelay);

        // Mints some additional Dai into the receiver's balance to cope with accrued fees
        mintDai(address(op), estimatedAmount);
        uint256 opBalanceBefore = dai.balanceOf(address(op));

        DSToken(op._(address(dai))).transfer(address(inConduit), estimatedAmount);
        RwaInputConduit2(mate._(address(inConduit))).push();

        RwaUrn(op._(address(urn))).wipe(estimatedAmount);

        uint256 opBalanceAfter = dai.balanceOf(address(op));

        // Get the remaining debt in the urn
        (, uint256 art) = vat.urns("RWA008-A", address(urn));

        assertLe(art, actualAmount - estimatedAmount);
        assertEq(opBalanceBefore - opBalanceAfter, estimatedAmount);
    }

    function testFailFullRepaymentIfTooEarly(uint32 estimateDelay, uint32 repaymentDelay) public {
        // Between 1 and 2^32-1 seconds
        estimateDelay = (estimateDelay % (type(uint32).max - 1)) + 1;
        // Between 0 and estimateDelay - 1
        repaymentDelay = repaymentDelay % estimateDelay;

        RwaUrn(op._(address(urn))).lock(1 ether);
        RwaUrn(op._(address(urn))).draw(400 ether);

        RwaOutputConduit2(op._(address(outConduit))).pick(address(rec));

        RwaOutputConduit2(mate._(address(outConduit))).push();

        uint256 estimatedAmount = urnProxyView.estimateWipeAllWad(address(urn), block.timestamp + estimateDelay);

        hevm.warp(block.timestamp + repaymentDelay);
        // Mints some additional Dai into the receiver's balance to cope with accrued fees
        mintDai(address(op), estimatedAmount);

        DSToken(op._(address(dai))).transfer(address(inConduit), estimatedAmount);
        RwaInputConduit2(mate._(address(inConduit))).push();

        RwaUrn(op._(address(urn))).wipe(estimatedAmount);
    }

    function mintDai(address who, uint256 wad) internal {
        // Mint unbacked Dai.
        vat.suck(VOW, address(this), rad(wad));
        // Allow `daiJoin` to manipulate this contract's dai.
        hevm.store(
            address(vat),
            keccak256(abi.encode(address(daiJoin), keccak256(abi.encode(address(this), 1)))),
            bytes32(uint256(1))
        );
        // Converts the minted Dai into ERC-20 Dai and sends it to `who`.
        daiJoin.exit(who, wad);
    }
}
