// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Contract elements should be laid out in the following order:
// Pragma statements
// Import statements
// Events
// Errors
// Interfaces
// Libraries
// Contracts

// Inside each contract, library or interface, use the following order:
// Type declarations
// State variables
// Events
// Errors
// Modifiers
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

/**
 * IMPORT STATEMENTS
 */
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

/**
 * @title Vault
 * @author Harsh Suthar
 * @notice This contract defines a vault for the rebase token
 * @notice Should store addressof the depositors and the amount they deposited
 * @notice Should be able to mint tokens and assign it to the depositor
 * @notice Should be able to redeem the balance and get additional interest rewards
 */
contract Vault {
    /**
     * STATE VARIABLES
     */
    IRebaseToken private immutable i_rebaseToken;

    /**
     * EVENTS
     */
    event Deposit(uint256 indexed amount, address indexed user);
    event Withdraw(uint256 indexed amount, address indexed user);

    /**
     * ERRORS
     */
    error Vault__RedeemFailed();
    error Vault__DepositFailed();
    error Vault__AmountMustBeGreaterThanZero();

    /**
     * MODIFIERS
     */
    modifier aboveZero(uint256 amount) {
        if (amount <= 0) {
            revert Vault__AmountMustBeGreaterThanZero();
        }
        _;
    }

    /**
     * CONSTRUCTOR
     */
    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    /**
     * @notice deposits the amount of tokens to the vault
     * @notice the amount of tokens to deposit/add up to the balance when the amount is sent without a calldata
     */
    receive() external payable {}

    /**
     * EXTERNAL FUNCTIONS
     */
    function deposit() external payable aboveZero(msg.value) {
        i_rebaseToken.mint(msg.sender, msg.value, i_rebaseToken.getInterestRate());
        emit Deposit(msg.value, msg.sender);
    }

    function redeem(uint256 amount) external aboveZero(amount) {
        i_rebaseToken.burn(msg.sender, amount);
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Withdraw(amount, msg.sender);
    }

    /**
     * EXTERNAL/PUBLIC VIEW/PURE FUNCTIONS
     */

    /**
     * @notice gets the address of the initialized immutable rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
