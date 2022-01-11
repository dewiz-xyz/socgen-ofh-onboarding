pragma solidity ^0.6.12;

import {DSTest} from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import {DSMath} from "ds-math/math.sol";

import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Spotter} from "dss/spot.sol";

import {DaiJoin} from "dss/join.sol";
import {AuthGemJoin} from "dss-gem-joins/join-auth.sol";

import {MockOFH} from "./mock/MockOFH.sol";
import {TokenWrapper, OFHTokenLike} from "./TokenWrapper.sol";
import {RwaInputConduit, RwaOutputConduit} from "./RwaConduit.sol";
import {RwaUrn} from "./RwaUrn.sol";
import {RwaLiquidationOracle} from "./RwaLiquidationOracle.sol";

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
    RwaUrn internal urn;
    RwaOutputConduit internal outC;
    RwaInputConduit internal inC;

    constructor(
        RwaUrn urn_,
        RwaOutputConduit outC_,
        RwaInputConduit inC_
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
    RwaOutputConduit internal outC;
    RwaInputConduit internal inC;

    constructor(RwaOutputConduit outC_, RwaInputConduit inC_) public {
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

contract RwaLiquidationOracleTest is DSTest, DSMath {
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
    RwaUrn internal urn;

    RwaOutputConduit internal outConduit;
    RwaInputConduit internal inConduit;

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
        wrapper = new TokenWrapper(OFHTokenLike(address(token)));
        wrapper.hope(address(this));

        vat = new Vat();

        jug = new Jug(address(vat));
        jug.file("vow", VOW);
        vat.rely(address(jug));

        dai = new DSToken("Dai");
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));
        dai.setOwner(address(daiJoin));

        vat.init("RWA008-SGFWOFH");
        vat.file("Line", 100 * rad(CEILING));
        vat.file("RWA008-SGFWOFH", "line", rad(CEILING));

        jug.init("RWA008-SGFWOFH");
        jug.file("RWA008-SGFWOFH", "duty", EIGHT_PCT);

        oracle = new RwaLiquidationOracle(address(vat), VOW);
        oracle.init("RWA008-SGFWOFH", 1.1 ether, DOC, TAU);
        vat.rely(address(oracle));
        (, address pip, , ) = oracle.ilks("RWA008-SGFWOFH");

        spotter = new Spotter(address(vat));
        vat.rely(address(spotter));
        spotter.file("RWA008-SGFWOFH", "mat", RAY);
        spotter.file("RWA008-SGFWOFH", "pip", pip);
        spotter.poke("RWA008-SGFWOFH");

        gemJoin = new AuthGemJoin(address(vat), "RWA008-SGFWOFH", address(wrapper));
        vat.rely(address(gemJoin));

        outConduit = new RwaOutputConduit(address(dai));

        urn = new RwaUrn(address(vat), address(jug), address(gemJoin), address(daiJoin), address(outConduit));
        gemJoin.rely(address(urn));
        inConduit = new RwaInputConduit(address(dai), address(urn));

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
        vat.file("RWA008-SGFWOFH", "line", 0);

        oracle.tell("RWA008-SGFWOFH");

        assertTrue(!op.canDraw(10 ether));

        // Advances time before the remediation period expires
        hevm.warp(block.timestamp + TAU / 2);
        oracle.cure("RWA008-SGFWOFH");
        vat.file("RWA008-SGFWOFH", "line", rad(CEILING));

        assertTrue(oracle.good("RWA008-SGFWOFH"));

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
        oracle.cure("RWA008-SGFWOFH");
    }

    function testFailCureLiquidationCancelled() public {
        op.lock(400 ether);
        assertTrue(op.canDraw(1 ether));

        // Flashes the liquidation beacon
        vat.file("RWA008-SGFWOFH", "line", 0);
        oracle.tell("RWA008-SGFWOFH");

        // Borrowing not possible anymore
        assertTrue(!op.canDraw(1 ether));

        // Still in remediation period
        hevm.warp(block.timestamp + TAU / 2);
        assertTrue(oracle.good("RWA008-SGFWOFH"));

        // Cancels liquidation
        oracle.cure("RWA008-SGFWOFH");
        vat.file("RWA008-SGFWOFH", "line", rad(CEILING));
        assertTrue(oracle.good("RWA008-SGFWOFH"));

        oracle.cure("RWA008-SGFWOFH");
    }

    function testCull() public {
        // Lock the gem
        op.lock(400 ether);
        op.draw(200 ether);

        // Flashes the liquidation beacon
        vat.file("RWA008-SGFWOFH", "line", 0);
        oracle.tell("RWA008-SGFWOFH");

        hevm.warp(block.timestamp + TAU + 1 days);

        assertEq(vat.gem("RWA008-SGFWOFH", address(oracle)), 0);
        assertTrue(!oracle.good("RWA008-SGFWOFH"));

        oracle.cull("RWA008-SGFWOFH", address(urn));

        assertTrue(!op.canDraw(1 ether));

        spotter.poke("RWA008-SGFWOFH");
        (, , uint256 spot, , ) = vat.ilks("RWA008-SGFWOFH");
        assertEq(spot, 0);

        (uint256 ink, uint256 art) = vat.urns("RWA008-SGFWOFH", address(urn));
        assertEq(ink, 0);
        assertEq(art, 0);

        // The system debt is equal to the drawn amount
        assertEq(vat.sin(VOW), rad(200 ether));

        // After the write-off, the gem goes to the oracle
        assertEq(vat.gem("RWA008-SGFWOFH", address(oracle)), 400 ether);
    }

    function testUnremediedLoanIsNotGood() public {
        op.lock(400 ether);
        op.draw(100 ether);

        vat.file("RWA008-SGFWOFH", "line", 0);
        oracle.tell("RWA008-SGFWOFH");
        assertTrue(oracle.good("RWA008-SGFWOFH"));

        hevm.warp(block.timestamp + TAU + 1 days);
        assertTrue(!oracle.good("RWA008-SGFWOFH"));
    }

    function testCullMultipleUrns() public {
        RwaUrn urn2 = new RwaUrn(address(vat), address(jug), address(gemJoin), address(daiJoin), address(outConduit));
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

        vat.file("RWA008-SGFWOFH", "line", 0);
        oracle.tell("RWA008-SGFWOFH");

        assertTrue(!op.canDraw(1 ether));
        assertTrue(!op2.canDraw(1 ether));

        hevm.warp(block.timestamp + TAU + 1 days);

        oracle.cull("RWA008-SGFWOFH", address(urn));
        assertEq(vat.sin(VOW), rad(50 ether));
        oracle.cull("RWA008-SGFWOFH", address(urn2));
        assertEq(vat.sin(VOW), rad(50 ether + 80 ether));
    }

    function testBump() public {
        op.lock(400 ether);
        op.draw(CEILING);

        op.pick(address(rec));
        mate.pushOut();

        // Debt ceiling was reached
        assertTrue(!op.canDraw(1 ether));

        // Increase the debt ceiling
        vat.file("RWA008-SGFWOFH", "line", rad(CEILING + 200 ether));

        // Still can't borrow much more because vault is unsafe
        assertTrue(op.canDraw(1 ether));
        assertTrue(!op.canDraw(200 ether));

        // Bump the price of RWA008-SGFWOFH
        oracle.bump("RWA008-SGFWOFH", wmul(2 ether, 1.1 ether));
        spotter.poke("RWA008-SGFWOFH");

        op.draw(200 ether);
        op.pick(address(rec));
        mate.pushOut();

        assertEq(dai.balanceOf(address(rec)), CEILING + 200 ether);
    }

    function testFailBumpUnknownIlk() public {
        oracle.bump("ecma", wmul(2 ether, 1.1 ether));
    }

    function testFailBumpDuringLiquidation() public {
        vat.file("RWA008-SGFWOFH", "line", 0);
        oracle.tell("RWA008-SGFWOFH");
        oracle.bump("RWA008-SGFWOFH", wmul(2 ether, 1.1 ether));
    }
}
