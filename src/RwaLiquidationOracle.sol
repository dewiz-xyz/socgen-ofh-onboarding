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
pragma solidity 0.6.12;

import {VatAbstract} from "dss-interfaces/dss/VatAbstract.sol";
import {DSValue} from "ds-value/value.sol";

/**
 * @title An extension/subset of `DSMath` containing only the methods required in this file.
 */
library DSMathCustom {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "DSMath/add-overflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "DSMath/mul-overflow");
    }
}

/**
 * @author Lev Livnev <lev@liv.nev.org.uk>
 * @author Henrique Barcelos <henrique@clio.finance>
 * @title An Oracle for liquitation of real-world assets (RWA).
 * @dev One instance of contract can be used for many RWA collateral types.
 */
contract RwaLiquidationOracle {

    /**
    * @notice Ilk metadata struct
    * @dev 4-member struct:
    * @member string hash, of borrower's agrrement with MakerDAO.
    * @member address pip, An Oracle for liquitation of real-world assets (RWA).
    * @member uint48 tau, remediation period.
    * @member uint48 toc, timestamp when liquidation was initiated.
    */
    struct Ilk {
        string doc;
        address pip;
        uint48 tau;
        uint48 toc;
    }

    /// @notice Core module address.
    VatAbstract public immutable vat;
    /// @notice Module that handles system debt and surplus.
    address public vow;

    /// @notice All collateral types supported by this oracle. `ilks[ilk]`
    mapping(bytes32 => Ilk) public ilks;
    /// @notice Addresses with admin access on this contract. `wards[usr]`
    mapping(address => uint256) public wards;

    /**
     * @notice `usr` was granted admin access.
     * @param usr The user address.
     */
    event Rely(address indexed usr);
    /**
     * @notice `usr` admin access was revoked.
     * @param usr The user address.
     */
    event Deny(address indexed usr);
    /**
     * @notice A contract parameter was updated.
     * @param what The changed parameter name. Currently the only supported value is "vow".
     * @param data The new value of the parameter.
     */
    event File(bytes32 indexed what, address data);
    /**
     * @notice A new collateral `ilk` was added.
     * @param ilk The name of the collateral.
     * @param val The initial value for the price feed.
     * @param doc The hash to the off-chain agreement for the ilk.
     * @param tau The amount of time the ilk can remain in liquidation before being written-off.
     */
    event Init(bytes32 indexed ilk, uint256 val, string doc, uint48 tau);
    /**
     * @notice The value of the collateral `ilk` was updated.
     * @param ilk The name of the collateral.
     * @param val The new value.
     */
    event Bump(bytes32 indexed ilk, uint256 val);
    /**
     * @notice The liquidation process for collateral `ilk` was started.
     * @param ilk The name of the collateral.
     */
    event Tell(bytes32 indexed ilk);
    /**
     * @notice The liquidation process for collateral `ilk` was stopped before the write-off.
     * @param ilk The name of the collateral.
     */
    event Cure(bytes32 indexed ilk);
    /**
     * @notice A `urn` outstanding debt for collateral `ilk` was written-off.
     * @param ilk The name of the collateral.
     * @param urn The address of the urn.
     */
    event Cull(bytes32 indexed ilk, address indexed urn);

    /**
     * @param vat_ The core module address.
     * @param vow_ The address of module that handles system debt and surplus.
     */
    constructor(address vat_, address vow_) public {
        vat = VatAbstract(vat_);
        vow = vow_;
        wards[msg.sender] = 1;

        emit Rely(msg.sender);
        emit File("vow", vow_);
    }

    /*//////////////////////////////////
               Authorization
    //////////////////////////////////*/

    /**
     * @notice Grants `usr` admin access to this contract.
     * @param usr The user address.
     */
    function rely(address usr) external auth {
        wards[usr] = 1;
        emit Rely(usr);
    }

    /**
     * @notice Revokes `usr` admin access from this contract.
     * @param usr The user address.
     */
    function deny(address usr) external auth {
        wards[usr] = 0;
        emit Deny(usr);
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "RwaOracle/not-authorized");
        _;
    }

    /*//////////////////////////////////
               Administration
    //////////////////////////////////*/

    /**
     * @notice Updates a contract parameter.
     * @param what The changed parameter name. Currently the only supported value is "vow".
     * @param data The new value of the parameter.
     */
    function file(bytes32 what, address data) external auth {
        if (what == "vow") {
            vow = data;
        } else {
            revert("RwaOracle/unrecognised-param");
        }

        emit File(what, data);
    }

    /**
     * @notice Initializes a new collateral type `ilk`.
     * @param ilk The name of the collateral type.
     * @param val The initial value for the price feed.
     * @param doc The hash to the off-chain agreement for the ilk.
     * @param tau The amount of time the ilk can remain in liquidation before being written-off.
     */
    function init(
        bytes32 ilk,
        uint256 val,
        string calldata doc,
        uint48 tau
    ) external auth {
        // doc, and tau can be amended, but tau cannot decrease
        require(tau >= ilks[ilk].tau, "RwaOracle/decreasing-tau");
        ilks[ilk].doc = doc;
        ilks[ilk].tau = tau;

        if (ilks[ilk].pip == address(0)) {
            DSValue pip = new DSValue();
            ilks[ilk].pip = address(pip);
            pip.poke(bytes32(val));
        } else {
            val = uint256(DSValue(ilks[ilk].pip).read());
        }

        emit Init(ilk, val, doc, tau);
    }

    /*//////////////////////////////////
                 Operations
    //////////////////////////////////*/

    /**
     * @notice Performs valuation adjustment for a given ilk.
     * @param ilk The ilk to adjust.
     * @param val The new value.
     */
    function bump(bytes32 ilk, uint256 val) external auth {
        DSValue pip = DSValue(ilks[ilk].pip);
        require(address(pip) != address(0), "RwaOracle/unknown-ilk");
        require(ilks[ilk].toc == 0, "RwaOracle/in-remediation");

        require(val >= uint256(pip.read()), "RwaOracle/decreasing-val");
        pip.poke(bytes32(val));

        emit Bump(ilk, val);
    }

    /**
     * @notice Enables liquidation for a given ilk.
     * @param ilk The ilk being liquidated.
     */
    function tell(bytes32 ilk) external auth {
        require(ilks[ilk].pip != address(0), "RwaOracle/unknown-ilk");

        (, , , uint256 line, ) = vat.ilks(ilk);
        require(line == 0, "RwaOracle/nonzero-line");

        ilks[ilk].toc = uint48(block.timestamp);

        emit Tell(ilk);
    }

    /**
     * @notice Remediation: stops the liquidation process for a given ilk.
     * @param ilk The ilk being remediated.
     */
    function cure(bytes32 ilk) external auth {
        require(ilks[ilk].pip != address(0), "RwaOracle/unknown-ilk");
        require(ilks[ilk].toc > 0, "RwaOracle/not-in-liquidation");

        ilks[ilk].toc = 0;

        emit Cure(ilk);
    }

    /**
     * @notice Writes-off a specific urn for a given ilk.
     * @dev It assigns the outstanding debt of the urn to the vow.
     * @param ilk The ilk being liquidated.
     * @param urn The urn being written-off.
     */
    function cull(bytes32 ilk, address urn) external auth {
        require(ilks[ilk].pip != address(0), "RwaOracle/unknown-ilk");
        require(block.timestamp >= DSMathCustom.add(ilks[ilk].toc, ilks[ilk].tau), "RwaOracle/early-cull");

        DSValue(ilks[ilk].pip).poke(bytes32(0));

        (uint256 ink, uint256 art) = vat.urns(ilk, urn);

        vat.grab(ilk, urn, address(this), vow, -int256(ink), -int256(art));

        emit Cull(ilk, urn);
    }

    /**
     * @notice Allows off-chain parties to check the state of the loan.
     * @param ilk the Ilk.
     */
    function good(bytes32 ilk) external view returns (bool) {
        require(ilks[ilk].pip != address(0), "RwaOracle/unknown-ilk");

        return (ilks[ilk].toc == 0 || block.timestamp < DSMathCustom.add(ilks[ilk].toc, ilks[ilk].tau));
    }
}
