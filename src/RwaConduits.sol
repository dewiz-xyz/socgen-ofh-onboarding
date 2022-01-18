pragma solidity ^0.6.12;

interface DSTokenLike {
    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (uint256);
}

/**
 * @dev After the deploy the owner must call `mate()` for the DIIS Group wallet.
 */
contract RwaInputConduit {
    DSTokenLike public immutable dai;
    address public immutable to;

    mapping(address => uint256) public wards;
    mapping(address => uint256) public may;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Mate(address indexed usr);
    event Hate(address indexed usr);
    event Push(address indexed to, uint256 wad);

    constructor(DSTokenLike _dai, address _to) public {
        dai = _dai;
        to = _to;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "RwaInputConduit/not-authorized");
        _;
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function mate(address usr) external auth {
        may[usr] = 1;
        emit Mate(usr);
    }

    function hate(address usr) external auth {
        may[usr] = 0;
        emit Hate(usr);
    }

    function push() external {
        require(may[msg.sender] == 1, "RwaInputConduit/not-mate");

        uint256 balance = dai.balanceOf(address(this));
        dai.transfer(to, balance);

        emit Push(to, balance);
    }
}

contract RwaOutputConduit {
    DSTokenLike public immutable dai;
    address public to;

    mapping(address => uint256) public wards;
    mapping(address => uint256) public can;
    mapping(address => uint256) public may;
    mapping(address => uint256) public bud;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Hope(address indexed usr);
    event Nope(address indexed usr);
    event Mate(address indexed usr);
    event Hate(address indexed usr);
    event Kiss(address indexed who);
    event Diss(address indexed who);
    event Pick(address indexed who);
    event Push(address indexed to, uint256 wad);

    constructor(DSTokenLike _dai) public {
        dai = _dai;
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "RwaOutputConduit/not-authorized");
        _;
    }

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    function hope(address usr) external auth {
        can[usr] = 1;
        emit Hope(usr);
    }

    function nope(address usr) external auth {
        can[usr] = 0;
        emit Nope(usr);
    }

    function mate(address usr) external auth {
        may[usr] = 1;
        emit Mate(usr);
    }

    function hate(address usr) external auth {
        may[usr] = 0;
        emit Hate(usr);
    }

    function kiss(address usr) public auth {
        bud[usr] = 1;
        emit Kiss(usr);
    }

    function diss(address usr) public auth {
        if (to == usr) {
            to = address(0);
        }
        bud[usr] = 0;
        emit Diss(usr);
    }

    function pick(address who) public {
        require(can[msg.sender] == 1, "RwaOutputConduit/not-operator");
        require(bud[who] == 1 || who == address(0), "RwaOutputConduit/not-bud");
        to = who;
        emit Pick(who);
    }

    function push() external {
        require(may[msg.sender] == 1, "RwaOutputConduit/not-mate");
        require(to != address(0), "RwaOutputConduit/to-not-picked");
        uint256 balance = dai.balanceOf(address(this));
        address recipient = to;
        to = address(0);

        dai.transfer(recipient, balance);
        emit Push(recipient, balance);
    }
}
