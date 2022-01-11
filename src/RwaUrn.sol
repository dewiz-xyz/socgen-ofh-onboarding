// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.6.8 <0.7.0;

import {VatAbstract, JugAbstract, DSTokenAbstract, GemJoinAbstract, DaiJoinAbstract, DaiAbstract} from "dss-interfaces/Interfaces.sol";

library Math {
    uint256 internal constant RAY = 10**27;

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "Math/add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "Math/sub-overflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "Math/mul-overflow");
    }

    function divup(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(x, sub(y, 1)) / y;
    }
}

contract RwaUrn {
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Hope(address indexed usr);
    event Nope(address indexed usr);
    event File(bytes32 indexed what, address data);
    event Lock(address indexed usr, uint256 wad);
    event Free(address indexed usr, uint256 wad);
    event Draw(address indexed usr, uint256 wad);
    event Wipe(address indexed usr, uint256 wad);
    event Quit(address indexed usr, uint256 wad);

    VatAbstract public immutable vat;
    GemJoinAbstract public immutable gemJoin;
    DaiJoinAbstract public immutable daiJoin;
    JugAbstract public jug;
    address public outputConduit;

    mapping(address => uint256) public wards;
    mapping(address => uint256) public can;

    constructor(
        address vat_,
        address jug_,
        address gemJoin_,
        address daiJoin_,
        address outputConduit_
    ) public {
        // require(outputConduit_ != address(0), "RwaUrn/invalid-conduit");

        vat = VatAbstract(vat_);
        jug = JugAbstract(jug_);
        gemJoin = GemJoinAbstract(gemJoin_);
        daiJoin = DaiJoinAbstract(daiJoin_);
        outputConduit = outputConduit_;

        wards[msg.sender] = 1;

        DSTokenAbstract(GemJoinAbstract(gemJoin_).gem()).approve(gemJoin_, type(uint256).max);
        DaiAbstract(DaiJoinAbstract(daiJoin_).dai()).approve(daiJoin_, type(uint256).max);
        VatAbstract(vat_).hope(daiJoin_);

        emit Rely(msg.sender);
        emit File("outputConduit", outputConduit_);
        emit File("jug", jug_);
    }

    /*//////////////////////////////////
               Authorization
    //////////////////////////////////*/

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "RwaUrn/not-authorized");
        _;
    }

    function hope(address usr) external auth {
        can[usr] = 1;
        emit Hope(usr);
    }

    function nope(address usr) external auth {
        can[usr] = 0;
        emit Nope(usr);
    }

    modifier operator() {
        require(can[msg.sender] == 1, "RwaUrn/not-operator");
        _;
    }

    /*//////////////////////////////////
               Administration
    //////////////////////////////////*/

    function file(bytes32 what, address data) external auth {
        if (what == "outputConduit") {
            require(data != address(0), "RwaUrn/invalid-conduit");
            outputConduit = data;
        } else if (what == "jug") {
            jug = JugAbstract(data);
        } else {
            revert("RwaUrn/unrecognised-param");
        }

        emit File(what, data);
    }

    /*//////////////////////////////////
              Vault Operation
    //////////////////////////////////*/

    function lock(uint256 wad) external operator {
        require(wad <= 2**255 - 1, "RwaUrn/overflow");

        DSTokenAbstract(gemJoin.gem()).transferFrom(msg.sender, address(this), wad);
        // join with address this
        gemJoin.join(address(this), wad);
        vat.frob(gemJoin.ilk(), address(this), address(this), address(this), int256(wad), 0);

        emit Lock(msg.sender, wad);
    }

    function free(uint256 wad) external operator {
        require(wad <= 2**255, "RwaUrn/overflow");

        vat.frob(gemJoin.ilk(), address(this), address(this), address(this), -int256(wad), 0);
        gemJoin.exit(msg.sender, wad);
        emit Free(msg.sender, wad);
    }

    function draw(uint256 wad) external operator {
        bytes32 ilk = gemJoin.ilk();
        jug.drip(ilk);
        (, uint256 rate, , , ) = vat.ilks(ilk);

        uint256 dart = Math.divup(Math.mul(Math.RAY, wad), rate);
        require(dart <= 2**255 - 1, "RwaUrn/overflow");

        vat.frob(ilk, address(this), address(this), address(this), 0, int256(dart));
        daiJoin.exit(outputConduit, wad);
        emit Draw(msg.sender, wad);
    }

    function wipe(uint256 wad) external {
        daiJoin.join(address(this), wad);

        bytes32 ilk = gemJoin.ilk();
        jug.drip(ilk);
        (, uint256 rate, , , ) = vat.ilks(ilk);

        uint256 dart = Math.mul(Math.RAY, wad) / rate;
        require(dart <= 2**255, "RwaUrn/overflow");

        vat.frob(ilk, address(this), address(this), address(this), 0, -int256(dart));
        emit Wipe(msg.sender, wad);
    }

    function quit() external {
        require(vat.live() == 0, "RwaUrn/vat-still-live");

        DSTokenAbstract dai = DSTokenAbstract(daiJoin.dai());
        uint256 wad = dai.balanceOf(address(this));

        dai.transfer(outputConduit, wad);
        emit Quit(msg.sender, wad);
    }
}
