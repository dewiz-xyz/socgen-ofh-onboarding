// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Copyright (C) 2021-2022 Dai Foundation
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

pragma solidity 0.6.12;

contract Config {
    struct SpellValues {
        address deployed_spell;
        uint256 deployed_spell_created;
        address previous_spell;
        bool office_hours_enabled;
        uint256 expiration_threshold;
    }

    struct SystemValues {
        uint256 line_offset;
        uint256 pot_dsr;
        uint256 pause_delay;
        uint256 vow_wait;
        uint256 vow_dump;
        uint256 vow_sump;
        uint256 vow_bump;
        uint256 vow_hump_min;
        uint256 vow_hump_max;
        uint256 flap_beg;
        uint256 flap_ttl;
        uint256 flap_tau;
        uint256 flap_lid;
        uint256 cat_box;
        uint256 dog_Hole;
        uint256 esm_min;
        address pause_authority;
        address osm_mom_authority;
        address flipper_mom_authority;
        address clipper_mom_authority;
        uint256 ilk_count;
        mapping(bytes32 => CollateralValues) collaterals;
    }

    struct CollateralValues {
        bool aL_enabled;
        uint256 aL_line;
        uint256 aL_gap;
        uint256 aL_ttl;
        uint256 line;
        uint256 dust;
        uint256 pct;
        uint256 mat;
        bytes32 liqType;
        bool liqOn;
        uint256 chop;
        uint256 cat_dunk;
        uint256 flip_beg;
        uint48 flip_ttl;
        uint48 flip_tau;
        uint256 flipper_mom;
        uint256 dog_hole;
        uint256 clip_buf;
        uint256 clip_tail;
        uint256 clip_cusp;
        uint256 clip_chip;
        uint256 clip_tip;
        uint256 clipper_mom;
        uint256 cm_tolerance;
        uint256 calc_tau;
        uint256 calc_step;
        uint256 calc_cut;
        bool lerp;
    }

    uint256 constant HUNDRED = 10**2;
    uint256 constant THOUSAND = 10**3;
    uint256 constant MILLION = 10**6;
    uint256 constant BILLION = 10**9;

    uint256 constant monthly_expiration = 4 days;
    uint256 constant weekly_expiration = 30 days;

    SpellValues spellValues;
    SystemValues afterSpell;

    function setValues(address chief) public {
        //
        // Values for spell-specific parameters
        //
        spellValues = SpellValues({
            deployed_spell: address(0), // populate with deployed spell if deployed
            deployed_spell_created: 0, // use get-created-timestamp.sh if deployed
            previous_spell: address(0), // supply if there is a need to test prior to its cast() function being called on-chain.
            office_hours_enabled: false, // true if officehours is expected to be enabled in the spell
            expiration_threshold: weekly_expiration // (weekly_expiration,monthly_expiration) if weekly or monthly spell
        });

        //
        // Values for all system configuration changes
        //
        afterSpell = SystemValues({
            line_offset: 500 * MILLION, // Offset between the global line against the sum of local lines
            pot_dsr: 1, // In basis points
            pause_delay: 60 seconds, // In seconds
            vow_wait: 156 hours, // In seconds
            vow_dump: 250, // In whole Dai units
            vow_sump: 50 * THOUSAND, // In whole Dai units
            vow_bump: 30 * THOUSAND, // In whole Dai units
            vow_hump_min: 0, // In whole Dai units
            vow_hump_max: 1000 * MILLION, // In whole Dai units
            flap_beg: 400, // in basis points
            flap_ttl: 30 minutes, // in seconds
            flap_tau: 72 hours, // in seconds
            flap_lid: 150 * THOUSAND, // in whole Dai units
            cat_box: 20 * MILLION, // In whole Dai units
            dog_Hole: 100 * MILLION, // In whole Dai units
            esm_min: 50 * THOUSAND, // In whole MKR units
            pause_authority: chief, // Pause authority
            osm_mom_authority: chief, // OsmMom authority
            flipper_mom_authority: chief, // FlipperMom authority
            clipper_mom_authority: chief, // ClipperMom authority
            ilk_count: 6 // Num expected in system
        });

        //
        // Values for all collateral
        // Update when adding or modifying Collateral Values
        //

        //
        // Test for all collateral based changes here
        //
        afterSpell.collaterals["ETH-A"] = CollateralValues({
            aL_enabled: true, // DssAutoLine is enabled?
            aL_line: 15 * BILLION, // In whole Dai units
            aL_gap: 100 * MILLION, // In whole Dai units
            aL_ttl: 8 hours, // In seconds
            line: 0, // In whole Dai units  // Not checked here as there is auto line
            dust: 10 * THOUSAND, // In whole Dai units
            pct: 200, // In basis points
            mat: 15000, // In basis points
            liqType: "clip", // "" or "flip" or "clip"
            liqOn: true, // If liquidations are enabled
            chop: 1300, // In basis points
            cat_dunk: 0, // In whole Dai units
            flip_beg: 0, // In basis points
            flip_ttl: 0, // In seconds
            flip_tau: 0, // In seconds
            flipper_mom: 0, // 1 if circuit breaker enabled
            dog_hole: 30 * MILLION,
            clip_buf: 13000,
            clip_tail: 140 minutes,
            clip_cusp: 4000,
            clip_chip: 10,
            clip_tip: 300,
            clipper_mom: 1,
            cm_tolerance: 5000,
            calc_tau: 0,
            calc_step: 90,
            calc_cut: 9900,
            lerp: false
        });

        afterSpell.collaterals["DUMMY-A"] = CollateralValues({
            aL_enabled: true, // DssAutoLine is enabled?
            aL_line: 100 * MILLION, // In whole Dai units
            aL_gap: 50 * MILLION, // In whole Dai units
            aL_ttl: 1 hours, // In seconds
            line: 0, // In whole Dai units  // Not checked here as there is auto line
            dust: 1 * THOUSAND, // In whole Dai units
            pct: 0, // In basis points
            mat: 10000, // In basis points
            liqType: "clip", // "" or "flip" or "clip"
            liqOn: false, // If liquidations are enabled
            chop: 1300, // In basis points
            cat_dunk: 0, // In whole Dai units
            flip_beg: 0, // In basis points
            flip_ttl: 0, // In seconds
            flip_tau: 0, // In seconds
            flipper_mom: 0, // 1 if circuit breaker enabled
            dog_hole: 3 * MILLION,
            clip_buf: 13000,
            clip_tail: 140 minutes,
            clip_cusp: 4000,
            clip_chip: 10,
            clip_tip: 300,
            clipper_mom: 1,
            cm_tolerance: 5000,
            calc_tau: 0,
            calc_step: 90,
            calc_cut: 9900,
            lerp: false
        });

        // ... other onboarded ilks

        // TODO: Add the below to the config.sol file in the actual spell repo...
        afterSpell.collaterals["RWA008-A"] = CollateralValues({
            aL_enabled: false, // DssAutoLine is enabled?
            aL_line: 0, // In whole Dai units
            aL_gap: 0, // In whole Dai units
            aL_ttl: 1 hours, // In seconds
            line: 80 * MILLION, // In whole Dai units  // Not checked here as there is auto line
            dust: 0, // In whole Dai units
            pct: 300, // In basis points
            mat: 10 * THOUSAND, // In basis points
            liqType: "", // "" or "flip" or "clip"
            liqOn: false, // If liquidations are enabled
            chop: 1300, // In basis points
            cat_dunk: 0, // In whole Dai units
            flip_beg: 0, // In basis points
            flip_ttl: 0, // In seconds
            flip_tau: 0, // In seconds
            flipper_mom: 0, // 1 if circuit breaker enabled
            dog_hole: 3 * MILLION,
            clip_buf: 13000,
            clip_tail: 140 minutes,
            clip_cusp: 4000,
            clip_chip: 10,
            clip_tip: 300,
            clipper_mom: 1,
            cm_tolerance: 5000,
            calc_tau: 0,
            calc_step: 90,
            calc_cut: 9900,
            lerp: false
        });
    }
}
