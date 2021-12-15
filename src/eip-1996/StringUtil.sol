// SPDX-License-Identifier: GPL-3.0-or-later
// @author Adapted from https://github.com/IoBuilders/solidity-string-util/blob/2af6a135446499b372d8577a2ff4c5fd7f7a2911/contracts/StringUtil.sol
pragma solidity ^0.6.12;

library StringUtil {
    function toHash(string calldata _s) internal pure returns (bytes32) {
        return keccak256(abi.encode(_s));
    }

    function isEmpty(string calldata _s) internal pure returns (bool) {
        return bytes(_s).length == 0;
    }
}
