pragma solidity 0.6.12;

interface DSTokenLike {
    function balanceOf(address) external view returns (uint256);

    function transfer(address, uint256) external returns (uint256);
}

/**
 * @dev After the deploy the owner must call `hope()` for the DIIS Group wallet.
 */
contract RwaInputConduit {
    // --- auth ---

    mapping(address => uint256) public wards;
    mapping(address => uint256) public can;

    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Hope(address indexed usr);
    event Nope(address indexed usr);

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "RwaConduit/not-authorized");
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
        require(can[msg.sender] == 1, "RwaConduit/not-operator");
        _;
    }

    DSTokenLike public gov;
    DSTokenLike public dai;
    address public to;

    event Push(address indexed to, uint256 wad);

    constructor(
        DSTokenLike _gov,
        DSTokenLike _dai,
        address _to
    ) public {
        gov = _gov;
        dai = _dai;
        to = _to;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    function push() external operator {
        // TODO: is this check still relevant to MakerDAO?
        require(gov.balanceOf(msg.sender) > 0, "RwaConduit/no-gov");

        uint256 balance = dai.balanceOf(address(this));
        dai.transfer(to, balance);

        emit Push(to, balance);
    }
}

contract RwaOutputConduit {
    // --- auth ---
    mapping(address => uint256) public wards;
    mapping(address => uint256) public can;

    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "RwaConduit/not-authorized");
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
        require(can[msg.sender] == 1, "RwaConduit/not-operator");
        _;
    }

    DSTokenLike public gov;
    DSTokenLike public dai;

    address public to;
    mapping(address => uint256) public bud;

    // Events
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event Hope(address indexed usr);
    event Nope(address indexed usr);
    event Kiss(address indexed who);
    event Diss(address indexed who);
    event Pick(address indexed who);
    event Push(address indexed to, uint256 wad);

    constructor(DSTokenLike _gov, DSTokenLike _dai) public {
        gov = _gov;
        dai = _dai;

        wards[msg.sender] = 1;
        emit Rely(msg.sender);
    }

    // --- administration ---
    function kiss(address who) public auth {
        bud[who] = 1;
        emit Kiss(who);
    }

    function diss(address who) public auth {
        if (to == who) {
            to = address(0);
        }
        bud[who] = 0;
        emit Diss(who);
    }

    // --- routing ---
    function pick(address who) public operator {
        require(bud[who] == 1 || who == address(0), "RwaConduit/not-bud");
        to = who;
        emit Pick(who);
    }

    function push() external {
        require(to != address(0), "RwaConduit/to-not-set");
        require(gov.balanceOf(msg.sender) > 0, "RwaConduit/no-gov");

        uint256 balance = dai.balanceOf(address(this));
        address recipient = to;
        to = address(0);

        dai.transfer(recipient, balance);
        emit Push(recipient, balance);
    }
}
