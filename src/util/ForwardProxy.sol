// Copyright (C) 2022 Clio Finance LLC <ops@clio.finance>
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
pragma solidity ^0.6.12;

import {Proxy} from "openzeppelin-contracts/proxy/Proxy.sol";

/**
 * @author Henrique Barcelos <henrique@clio.finance>
 * @dev This contract provides a fallback function that forwards all calls to another contract using the EVM
 * instruction `call`.
 *
 * Additionally, delegation to the implementation can be triggered manually through the `_fallback` function, or to a
 * different contract through the `_delegate` function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
contract ForwardProxy is Proxy {
    address internal forwardTo;

    /**
     * @param forwardTo_ The contract to which the call is going to be forwarded to.
     */
    constructor(address forwardTo_) public {
        forwardTo = forwardTo_;
    }

    /**
     * @notice Updates the `forwardTo` address.
     * @param forwardTo_ The contract to which the call is going to be forwarded to.
     */
    function updateForwardTo(address forwardTo_) public {
        forwardTo = forwardTo_;
    }

    /**
     * @notice Delegates the current call to `implementation`.
     * @dev This function does not return to its internall call site, it will return directly to the external caller.
     * @param implementation The address of the implementation contract.
     */
    function _delegate(address implementation) internal virtual override {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            // let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            let result := call(gas(), implementation, callvalue(), 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // call returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overriden so it returns the address to which the fallback function and {_fallback} should delegate.
     * @return forwardTo The address of the implementation contract.
     */
    function _implementation() internal view virtual override returns (address) {
        return forwardTo;
    }
}
