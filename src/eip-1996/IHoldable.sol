// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IHoldable is IERC20 {
    enum HoldStatusCode {
        Nonexistent,
        Ordered,
        Executed,
        ExecutedAndKeptOpen,
        ReleasedByNotary,
        ReleasedByPayee,
        ReleasedOnExpiration
    }

    function hold(
        string calldata operationId,
        address to,
        address notary,
        uint256 value,
        uint256 timeToExpiration
    ) external returns (bool);

    function holdFrom(
        string calldata operationId,
        address from,
        address to,
        address notary,
        uint256 value,
        uint256 timeToExpiration
    ) external returns (bool);

    function holdWithExpirationDate(
        string calldata operationId,
        address to,
        address notary,
        uint256 value,
        uint256 expiration
    ) external returns (bool);

    function holdFromWithExpirationDate(
        string calldata operationId,
        address from,
        address to,
        address notary,
        uint256 value,
        uint256 expiration
    ) external returns (bool);

    function releaseHold(string calldata operationId) external returns (bool);

    function executeHold(string calldata operationId, uint256 value) external returns (bool);

    function executeHoldAndKeepOpen(string calldata operationId, uint256 value) external returns (bool);

    function renewHold(string calldata operationId, uint256 timeToExpiration) external returns (bool);

    function renewHoldWithExpirationDate(string calldata operationId, uint256 expiration) external returns (bool);

    function retrieveHoldData(string calldata operationId)
        external
        view
        returns (
            address from,
            address to,
            address notary,
            uint256 value,
            uint256 expiration,
            HoldStatusCode status
        );

    function balanceOnHold(address account) external view returns (uint256);

    function netBalanceOf(address account) external view returns (uint256);

    function totalSupplyOnHold() external view returns (uint256);

    function authorizeHoldOperator(address operator) external returns (bool);

    function revokeHoldOperator(address operator) external returns (bool);

    function isHoldOperatorFor(address operator, address from) external view returns (bool);

    event HoldCreated(
        address indexed holdIssuer,
        string operationId,
        address from,
        address to,
        address indexed notary,
        uint256 value,
        uint256 expiration
    );
    event HoldExecuted(
        address indexed holdIssuer,
        string operationId,
        address indexed notary,
        uint256 heldValue,
        uint256 transferredValue
    );
    event HoldExecutedAndKeptOpen(
        address indexed holdIssuer,
        string operationId,
        address indexed notary,
        uint256 heldValue,
        uint256 transferredValue
    );
    event HoldReleased(address indexed holdIssuer, string operationId, HoldStatusCode status);
    event HoldRenewed(address indexed holdIssuer, string operationId, uint256 oldExpiration, uint256 newExpiration);
    event HoldOperatorAuthorized(address indexed operator, address indexed account);
    event RevokedHoldOperator(address indexed operator, address indexed account);
}
