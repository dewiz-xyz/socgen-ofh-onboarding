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
import {RwaLiquidationOracle} from "./RwaLiquidationOracle.sol";
import {RwaUrn} from "./RwaUrn.sol";

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

contract RwaUser is TryCaller {
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

    function canDraw(address who) public returns (bool) {
        return this.tryCall(address(outC), abi.encodeWithSignature("draw(uint256)", who));
    }

    function canFree(address who) public returns (bool) {
        return this.tryCall(address(outC), abi.encodeWithSignature("free(uint256)", who));
    }
}

contract TryPusher is TryCaller {
    function canPush(address who) public returns (bool) {
        return this.tryCall(address(who), abi.encodeWithSignature("push()"));
    }
}

contract RwaUrnTest is DSTest, DSMath, TryPusher {
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

    RwaUser internal usr;
    TokenUser internal rec;

    // Debt ceiling of 1000 DAI
    string internal constant DOC = "Please sign this";
    uint256 internal constant CEILING = 1000 ether;
    uint256 internal constant EIGHT_PCT = 1000000002440418608258400030;

    uint48 internal constant TAU = 2 weeks;

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10**27;
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

        vat.init("acme");
        vat.file("Line", 100 * rad(CEILING));
        vat.file("acme", "line", rad(CEILING));

        jug.init("acme");
        jug.file("acme", "duty", EIGHT_PCT);

        oracle = new RwaLiquidationOracle(address(vat), VOW);
        oracle.init("acme", wmul(CEILING, 1.1 ether), DOC, TAU);
        vat.rely(address(oracle));
        (, address pip, , ) = oracle.ilks("acme");

        spotter = new Spotter(address(vat));
        vat.rely(address(spotter));
        spotter.file("acme", "mat", RAY);
        spotter.file("acme", "pip", pip);
        spotter.poke("acme");

        gemJoin = new AuthGemJoin(address(vat), "acme", address(wrapper));
        vat.rely(address(gemJoin));

        outConduit = new RwaOutputConduit(address(dai));

        urn = new RwaUrn(address(vat), address(jug), address(gemJoin), address(daiJoin), address(outConduit));
        gemJoin.rely(address(urn));
        inConduit = new RwaInputConduit(address(dai), address(urn));

        usr = new RwaUser(urn, outConduit, inConduit);
        rec = new TokenUser(dai);

        // Wraps all tokens into `usr` balance
        token.transfer(address(wrapper), 400);
        wrapper.wrap(address(usr), 400);

        urn.hope(address(usr));
        outConduit.hope(address(usr));
        outConduit.kiss(address(rec));

        usr.approve(wrapper, address(urn), type(uint256).max);
    }

    function testFile() public {
        urn.file("outputConduit", address(123));
        assertEq(urn.outputConduit(), address(123));
        urn.file("jug", address(456));
        assertEq(address(urn.jug()), address(456));
    }
}
