// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import "dss-interfaces/dss/VatAbstract.sol";
import "dss-interfaces/dapp/DSPauseAbstract.sol";
import "dss-interfaces/dss/JugAbstract.sol";
import "dss-interfaces/dss/SpotAbstract.sol";
import "dss-interfaces/dss/GemJoinAbstract.sol";
import "dss-interfaces/dapp/DSTokenAbstract.sol";
import "dss-interfaces/dss/ChainlogAbstract.sol";

interface RwaLiquidationLike {
    function wards(address) external returns (uint256);

    function ilks(bytes32)
        external
        returns (
            string memory,
            address,
            uint48,
            uint48
        );

    function rely(address) external;

    function deny(address) external;

    function init(
        bytes32,
        uint256,
        string calldata,
        uint48
    ) external;

    function tell(bytes32) external;

    function cure(bytes32) external;

    function cull(bytes32) external;

    function good(bytes32) external view;
}

interface RwaOutputConduitLike {
    function wards(address) external returns (uint256);

    function can(address) external returns (uint256);

    function rely(address) external;

    function deny(address) external;

    function hope(address) external;

    function mate(address) external;

    function nope(address) external;

    function bud(address) external returns (uint256);

    function kiss(address) external;

    function diss(address) external;

    function pick(address) external;

    function push() external;
}

interface RwaInputConduitLike {
    function rely(address usr) external;

    function deny(address usr) external;

    function mate(address usr) external;

    function hate(address usr) external;

    function push() external;
}

interface RwaUrnLike {
    function hope(address) external;
}

contract SpellAction {
    // GOERLI ADDRESSES

    // The contracts in this list should correspond to MCD core contracts, verify
    // against the current release list at:
    //     https://github.com/clio-finance/ces-goerli/blob/master/contracts.json
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);

    address constant MIP21_LIQUIDATION_ORACLE_2 = 0x6F8896892AD583BfAE6f7E24d12FC821cC846AB0;
    address constant RWA007 = 0x3B8D51859DD2A33E6a34798c80375dCd0D44b290;
    address constant MCD_JOIN_RWA007_A = 0x2093ea40eCB44DC6813f49507537C4F48D1Be10f;
    address constant RWA007_A_URN = 0x11a9befCe5D1985B510236b933e99AD2d9144bA1;
    address constant RWA007_A_INPUT_CONDUIT = 0x63073972E41D3bb1B293f747B969aB45d3D2a777;
    address constant RWA007_A_OUTPUT_CONDUIT = 0x77eE4C8C9E46091202Be264aD0140B50b9d118fe;
    address constant RWA007_A_OPERATOR = 0x50b8C31E88eE19c480Cc60c780c77051D3aFE775;
    address constant RWA007_A_MATE = 0x62431c4563C8C24fE0756D541c72D2A51B635b96;

    uint256 constant THREE_PCT_RATE = 1000000000937303470807876289; // TODO RWA team should provide this one

    /// @notice precision
    uint256 public constant THOUSAND = 10**3;
    uint256 public constant MILLION = 10**6;
    uint256 public constant WAD = 10**18;
    uint256 public constant RAY = 10**27;
    uint256 public constant RAD = 10**45;

    uint256 constant RWA007_A_INITIAL_DC = 10000000 * RAD; // TODO RWA team should provide
    uint256 constant RWA007_A_INITIAL_PRICE = 13000 * WAD; // TODO RWA team should provide
    uint48 constant RWA007_A_TAU = 300; // TODO RWA team should provide

    /**
     * @notice MIP13c3-SP4 Declaration of Intent & Commercial Points -
     *   Off-Chain Asset Backed Lender to onboard Real World Assets
     *   as Collateral for a DAI loan
     *
     * https://ipfs.io/ipfs/QmdmAUTU3sd9VkdfTZNQM6krc9jsKgF2pz7W1qvvfJo1xk
     */
    string constant DOC = "QmdmAUTU3sd9VkdfTZNQM6krc9jsKgF2pz7W1qvvfJo1xk"; // TODO Reference to a documents which describe deal (should be uploaded to IPFS)

    function execute() external {
        address MCD_VAT = ChainlogAbstract(CHANGELOG).getAddress("MCD_VAT");
        address MCD_JUG = ChainlogAbstract(CHANGELOG).getAddress("MCD_JUG");
        address MCD_SPOT = ChainlogAbstract(CHANGELOG).getAddress("MCD_SPOT");

        // RWA007-SGFWOFH1-A collateral deploy

        // Set ilk bytes32 variable
        bytes32 ilk = "RWA007-A";

        // Add RWA007SGHWOFH1 contract to the changelog
        CHANGELOG.setAddress("RWA007", RWA007);
        CHANGELOG.setAddress("MCD_JOIN_RWA007_A", MCD_JOIN_RWA007_A);
        CHANGELOG.setAddress("MIP21_LIQUIDATION_ORACLE_2", MIP21_LIQUIDATION_ORACLE_2);
        CHANGELOG.setAddress("RWA007_A_URN", RWA007_A_URN);
        CHANGELOG.setAddress("RWA007_A_INPUT_CONDUIT", RWA007_A_INPUT_CONDUIT);
        CHANGELOG.setAddress("RWA007_A_OUTPUT_CONDUIT", RWA007_A_OUTPUT_CONDUIT);

        // bump changelog version
        // TODO make sure to update this version on mainnet
        CHANGELOG.setVersion("1.0.0");

        // Sanity checks
        require(GemJoinAbstract(MCD_JOIN_RWA007_A).vat() == MCD_VAT, "join-vat-not-match");
        require(GemJoinAbstract(MCD_JOIN_RWA007_A).ilk() == ilk, "join-ilk-not-match");
        require(GemJoinAbstract(MCD_JOIN_RWA007_A).gem() == RWA007, "join-gem-not-match");
        require(GemJoinAbstract(MCD_JOIN_RWA007_A).dec() == DSTokenAbstract(RWA007).decimals(), "join-dec-not-match");

        /*
         * init the RwaLiquidationOracle2
         */
        // TODO: this should be verified with RWA Team (5 min for testing is good)
        RwaLiquidationLike(MIP21_LIQUIDATION_ORACLE_2).init(ilk, RWA007_A_INITIAL_PRICE, DOC, RWA007_A_TAU);
        (, address pip, , ) = RwaLiquidationLike(MIP21_LIQUIDATION_ORACLE_2).ilks(ilk);
        CHANGELOG.setAddress("PIP_RWA007", pip);

        // Set price feed for RWA007SGHWOFH1
        SpotAbstract(MCD_SPOT).file(ilk, "pip", pip);

        // Init RWA007SGHWOFH1 in Vat
        VatAbstract(MCD_VAT).init(ilk);
        // Init RWA007SGHWOFH1 in Jug
        JugAbstract(MCD_JUG).init(ilk);

        // Allow RWA007SGHWOFH1 Join to modify Vat registry
        VatAbstract(MCD_VAT).rely(MCD_JOIN_RWA007_A);

        // Allow RwaLiquidationOracle2 to modify Vat registry
        VatAbstract(MCD_VAT).rely(MIP21_LIQUIDATION_ORACLE_2);

        // 1000 debt ceiling
        VatAbstract(MCD_VAT).file(ilk, "line", RWA007_A_INITIAL_DC);
        VatAbstract(MCD_VAT).file("Line", VatAbstract(MCD_VAT).Line() + RWA007_A_INITIAL_DC);

        // No dust
        // VatAbstract(MCD_VAT).file(ilk, "dust", 0)

        // 3% stability fee // TODO get from RWA
        JugAbstract(MCD_JUG).file(ilk, "duty", THREE_PCT_RATE);

        // collateralization ratio 100%
        SpotAbstract(MCD_SPOT).file(ilk, "mat", RAY); // TODO Should get from RWA team

        // poke the spotter to pull in a price
        SpotAbstract(MCD_SPOT).poke(ilk);

        // give the urn permissions on the join adapter
        GemJoinAbstract(MCD_JOIN_RWA007_A).rely(RWA007_A_URN);

        // set up the urn
        RwaUrnLike(RWA007_A_URN).hope(RWA007_A_OPERATOR);

        // set up output conduit
        RwaOutputConduitLike(RWA007_A_OUTPUT_CONDUIT).hope(RWA007_A_OPERATOR);

        // whitelist DIIS Group in the conduits
        RwaOutputConduitLike(RWA007_A_OUTPUT_CONDUIT).mate(RWA007_A_MATE);
        RwaInputConduitLike(RWA007_A_INPUT_CONDUIT).mate(RWA007_A_MATE);
    }
}

contract RwaSpell {
    ChainlogAbstract constant CHANGELOG = ChainlogAbstract(0x7EafEEa64bF6F79A79853F4A660e0960c821BA50);

    DSPauseAbstract public pause = DSPauseAbstract(CHANGELOG.getAddress("MCD_PAUSE"));
    address public action;
    bytes32 public tag;
    uint256 public eta;
    bytes public sig;
    uint256 public expiration;
    bool public done;

    string public constant description = "CESFork Goerli Spell Deploy";

    constructor() public {
        sig = abi.encodeWithSignature("execute()");
        action = address(new SpellAction());
        bytes32 _tag;
        address _action = action;
        assembly {
            _tag := extcodehash(_action)
        }
        tag = _tag;
        expiration = block.timestamp + 30 days;
    }

    function schedule() public {
        require(block.timestamp <= expiration, "This contract has expired");
        require(eta == 0, "This spell has already been scheduled");
        eta = block.timestamp + DSPauseAbstract(pause).delay();
        pause.plot(action, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        pause.exec(action, tag, sig, eta);
    }
}
