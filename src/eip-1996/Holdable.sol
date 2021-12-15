// SPDX-License-Identifier: GPL-3.0-or-later
// @author Adapted from https://github.com/IoBuilders/holdable-token/blob/372dd8ed0252691231bea6d0b9e724cfb5fa0494/contracts/Holdable.sol
pragma solidity ^0.6.12;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {StringUtil} from "./StringUtil.sol";
import {IHoldable} from "./IHoldable.sol";

abstract contract Holdable is IHoldable, ERC20 {
    using StringUtil for string;

    struct Hold {
        address issuer;
        address origin;
        address target;
        address notary;
        uint256 expiration;
        uint256 value;
        HoldStatusCode status;
    }

    mapping(bytes32 => Hold) internal holds;
    mapping(address => uint256) internal heldBalance;
    mapping(address => mapping(address => bool)) internal operators;
    mapping(address => bool) internal defaultOperators;

    uint256 internal _totalHeldBalance;

    constructor(string memory name_, string memory symbol_) public ERC20(name_, symbol_) {}

    function hold(
        string calldata operationId,
        address to,
        address notary,
        uint256 value,
        uint256 timeToExpiration
    ) external override returns (bool) {
        _checkHold(to);

        return _hold(operationId, msg.sender, msg.sender, to, notary, value, _computeExpiration(timeToExpiration));
    }

    function holdFrom(
        string calldata operationId,
        address from,
        address to,
        address notary,
        uint256 value,
        uint256 timeToExpiration
    ) external override returns (bool) {
        _checkHoldFrom(to, from);

        return _hold(operationId, msg.sender, from, to, notary, value, _computeExpiration(timeToExpiration));
    }

    function holdWithExpirationDate(
        string calldata operationId,
        address to,
        address notary,
        uint256 value,
        uint256 expiration
    ) external override returns (bool) {
        _checkHold(to);
        _checkExpiration(expiration);

        return _hold(operationId, msg.sender, msg.sender, to, notary, value, expiration);
    }

    function holdFromWithExpirationDate(
        string calldata operationId,
        address from,
        address to,
        address notary,
        uint256 value,
        uint256 expiration
    ) external override returns (bool) {
        _checkHoldFrom(to, from);
        _checkExpiration(expiration);

        return _hold(operationId, msg.sender, from, to, notary, value, expiration);
    }

    function releaseHold(string calldata operationId) external override returns (bool) {
        Hold storage releasableHold = holds[operationId.toHash()];

        return _releaseHold(releasableHold, operationId);
    }

    function executeHold(string calldata operationId, uint256 value) external override returns (bool) {
        return _executeHold(operationId, value, false, true);
    }

    function executeHoldAndKeepOpen(string calldata operationId, uint256 value) external override returns (bool) {
        return _executeHold(operationId, value, true, true);
    }

    function renewHold(string calldata operationId, uint256 timeToExpiration) external override returns (bool) {
        Hold storage renewableHold = holds[operationId.toHash()];

        _checkRenewableHold(renewableHold);

        return _renewHold(renewableHold, operationId, _computeExpiration(timeToExpiration));
    }

    function renewHoldWithExpirationDate(string calldata operationId, uint256 expiration)
        external
        override
        returns (bool)
    {
        Hold storage renewableHold = holds[operationId.toHash()];

        _checkRenewableHold(renewableHold);
        _checkExpiration(expiration);

        return _renewHold(renewableHold, operationId, expiration);
    }

    function retrieveHoldData(string calldata operationId)
        external
        view
        override
        returns (
            address from,
            address to,
            address notary,
            uint256 value,
            uint256 expiration,
            HoldStatusCode status
        )
    {
        Hold storage retrievedHold = holds[operationId.toHash()];
        return (
            retrievedHold.origin,
            retrievedHold.target,
            retrievedHold.notary,
            retrievedHold.value,
            retrievedHold.expiration,
            retrievedHold.status
        );
    }

    function balanceOnHold(address account) external view override returns (uint256) {
        return heldBalance[account];
    }

    function netBalanceOf(address account) external view override returns (uint256) {
        return super.balanceOf(account);
    }

    function totalSupplyOnHold() external view override returns (uint256) {
        return _totalHeldBalance;
    }

    function isHoldOperatorFor(address operator, address from) external view override returns (bool) {
        return operators[from][operator];
    }

    function authorizeHoldOperator(address operator) external override returns (bool) {
        require(operators[msg.sender][operator] == false, "The operator is already authorized");

        operators[msg.sender][operator] = true;
        emit HoldOperatorAuthorized(operator, msg.sender);
        return true;
    }

    function revokeHoldOperator(address operator) external override returns (bool) {
        require(operators[msg.sender][operator] == true, "The operator is already not authorized");

        operators[msg.sender][operator] = false;
        emit RevokedHoldOperator(operator, msg.sender);
        return true;
    }

    /// @notice Retrieve the erc20.balanceOf(account) - heldBalance(account)
    function balanceOf(address account) public view override(IERC20, ERC20) returns (uint256) {
        return super.balanceOf(account).sub(heldBalance[account]);
    }

    function transfer(address _to, uint256 _value) public override(IERC20, ERC20) returns (bool) {
        require(balanceOf(msg.sender) >= _value, "Not enough available balance");
        return super.transfer(_to, _value);
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public override(IERC20, ERC20) returns (bool) {
        require(balanceOf(_from) >= _value, "Not enough available balance");
        return super.transferFrom(_from, _to, _value);
    }

    function _isExpired(uint256 expiration) internal view returns (bool) {
        /* solium-disable-next-line security/no-block-members */
        return expiration != 0 && (now >= expiration);
    }

    function _hold(
        string calldata operationId,
        address issuer,
        address from,
        address to,
        address notary,
        uint256 value,
        uint256 expiration
    ) internal returns (bool) {
        Hold storage newHold = holds[operationId.toHash()];

        require(!operationId.isEmpty(), "Operation ID must not be empty");
        require(value != 0, "Value must be greater than zero");
        require(newHold.value == 0, "This operationId already exists");
        require(notary != address(0), "Notary address must not be zero address");
        require(value <= balanceOf(from), "Amount of the hold can't be greater than the balance of the origin");

        newHold.issuer = issuer;
        newHold.origin = from;
        newHold.target = to;
        newHold.notary = notary;
        newHold.value = value;
        newHold.status = HoldStatusCode.Ordered;
        newHold.expiration = expiration;

        heldBalance[from] = heldBalance[from].add(value);
        _totalHeldBalance = _totalHeldBalance.add(value);

        emit HoldCreated(issuer, operationId, from, to, notary, value, expiration);

        return true;
    }

    function _releaseHold(Hold storage releasableHold, string calldata operationId) internal returns (bool) {
        require(
            releasableHold.status == HoldStatusCode.Ordered ||
                releasableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
            "A hold can only be released in status Ordered or ExecutedAndKeptOpen"
        );
        require(
            _isExpired(releasableHold.expiration) ||
                (msg.sender == releasableHold.notary) ||
                (msg.sender == releasableHold.target),
            "A not expired hold can only be released by the notary or the payee"
        );

        if (_isExpired(releasableHold.expiration)) {
            releasableHold.status = HoldStatusCode.ReleasedOnExpiration;
        } else {
            if (releasableHold.notary == msg.sender) {
                releasableHold.status = HoldStatusCode.ReleasedByNotary;
            } else {
                releasableHold.status = HoldStatusCode.ReleasedByPayee;
            }
        }

        heldBalance[releasableHold.origin] = heldBalance[releasableHold.origin].sub(releasableHold.value);
        _totalHeldBalance = _totalHeldBalance.sub(releasableHold.value);

        emit HoldReleased(releasableHold.issuer, operationId, releasableHold.status);

        return true;
    }

    function _executeHold(
        string calldata operationId,
        uint256 value,
        bool keepOpenIfHoldHasBalance,
        bool doTransfer
    ) internal returns (bool) {
        Hold storage executableHold = holds[operationId.toHash()];

        require(
            executableHold.status == HoldStatusCode.Ordered ||
                executableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
            "A hold can only be executed in status Ordered or ExecutedAndKeptOpen"
        );
        require(value != 0, "Value must be greater than zero");
        require(executableHold.notary == msg.sender, "The hold can only be executed by the notary");
        require(!_isExpired(executableHold.expiration), "The hold has already expired");
        require(value <= executableHold.value, "The value should be equal or less than the held amount");

        if (keepOpenIfHoldHasBalance && ((executableHold.value - value) > 0)) {
            _setHoldToExecutedAndKeptOpen(executableHold, operationId, value, value);
        } else {
            _setHoldToExecuted(executableHold, operationId, value, executableHold.value);
        }

        if (doTransfer) {
            _transfer(executableHold.origin, executableHold.target, value);
        }

        return true;
    }

    function _renewHold(
        Hold storage renewableHold,
        string calldata operationId,
        uint256 expiration
    ) internal returns (bool) {
        uint256 oldExpiration = renewableHold.expiration;
        renewableHold.expiration = expiration;

        emit HoldRenewed(renewableHold.issuer, operationId, oldExpiration, expiration);

        return true;
    }

    function _setHoldToExecuted(
        Hold storage executableHold,
        string calldata operationId,
        uint256 value,
        uint256 heldBalanceDecrease
    ) internal {
        _decreaseHeldBalance(executableHold, heldBalanceDecrease);

        executableHold.status = HoldStatusCode.Executed;

        emit HoldExecuted(executableHold.issuer, operationId, executableHold.notary, executableHold.value, value);
    }

    function _setHoldToExecutedAndKeptOpen(
        Hold storage executableHold,
        string calldata operationId,
        uint256 value,
        uint256 heldBalanceDecrease
    ) internal {
        _decreaseHeldBalance(executableHold, heldBalanceDecrease);

        executableHold.status = HoldStatusCode.ExecutedAndKeptOpen;
        executableHold.value = executableHold.value.sub(value);

        emit HoldExecutedAndKeptOpen(
            executableHold.issuer,
            operationId,
            executableHold.notary,
            executableHold.value,
            value
        );
    }

    function _addDefaultOperator(address defaultOperator) internal {
        defaultOperators[defaultOperator] = true;
    }

    function _removeDefaultOperator(address defaultOperator) internal {
        defaultOperators[defaultOperator] = false;
    }

    function _computeExpiration(uint256 _timeToExpiration) internal view returns (uint256) {
        uint256 expiration = 0;

        if (_timeToExpiration != 0) {
            /* solium-disable-next-line security/no-block-members */
            expiration = now.add(_timeToExpiration);
        }

        return expiration;
    }

    function _isDefaultOperatorOrOperator(address operator, address from) internal view returns (bool) {
        return defaultOperators[operator] || operators[from][operator];
    }

    function _decreaseHeldBalance(Hold storage executableHold, uint256 value) private {
        heldBalance[executableHold.origin] = heldBalance[executableHold.origin].sub(value);
        _totalHeldBalance = _totalHeldBalance.sub(value);
    }

    function _checkHold(address to) private pure {
        require(to != address(0), "Payee address must not be zero address");
    }

    function _checkHoldFrom(address to, address from) private view {
        require(to != address(0), "Payee address must not be zero address");
        require(from != address(0), "Payer address must not be zero address");
        require(_isDefaultOperatorOrOperator(msg.sender, from), "This operator is not authorized");
    }

    function _checkRenewableHold(Hold storage renewableHold) private view {
        require(
            renewableHold.status == HoldStatusCode.Ordered ||
                renewableHold.status == HoldStatusCode.ExecutedAndKeptOpen,
            "A hold can only be renewed in status Ordered or ExecutedAndKeptOpen"
        );
        require(!_isExpired(renewableHold.expiration), "An expired hold can not be renewed");
        require(
            renewableHold.origin == msg.sender || renewableHold.issuer == msg.sender,
            "The hold can only be renewed by the issuer or the payer"
        );
    }

    function _checkExpiration(uint256 expiration) private view {
        /* solium-disable-next-line security/no-block-members */
        require(expiration > now || expiration == 0, "Expiration date must be greater than block timestamp or zero");
    }
}
