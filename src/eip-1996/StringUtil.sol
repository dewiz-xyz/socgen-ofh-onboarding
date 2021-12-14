// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

library StringUtil {
    function toHash(string calldata _s) internal pure returns (bytes32) {
        return keccak256(abi.encode(_s));
    }

    function isEmpty(string calldata _s) internal pure returns (bool) {
        return bytes(_s).length == 0;
    }
}
