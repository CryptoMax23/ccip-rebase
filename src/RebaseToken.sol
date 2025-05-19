// SPDX-License-Identifier: SEE LICENSE IN LICENSE
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

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";


/**
 * @title Rebase Token
 * @author Harsh Suthar
 * @notice A cross chain rebase token able to incentivize the users based on the interest rate they got
 * @notice This token have a decremental interest for every new incoming depositer
 * @notice Early adopters would always have a higher interest rate compared to the later ones
 * @notice interest rate will be decided based on global market factors
 * @notice This token is a ERC20 token
 */
contract RebaseToken is ERC20, Ownable, AccessControl {

    /**
     * STATE VARIABLES
     */
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address userAddress => uint256 userInterestRate) private s_UserInterestRate;
    mapping(address userAddress => uint256 userLastUpdatedTime) private s_lastUserUpdatedTime;
    bytes32 public constant MINT_BURN_ROLE = keccak256("MINT_BURN_ROLE");

    /**
     * EVENTS
     */
    event InterestRateSet(uint256 interestRate);

    /**
     * ERRORS
     */
    error RebaseToken__NewInterestRateMustBeLowerThanOld();

    /**
     * CONSTRUCTOR
     */
    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}


    /**
     * EXTERNAL FUNCTIONS
     */
    
    /**
     * @notice Set the interest rate for the token
     * @param interestRate The new interest rate to be set
     * @dev This function can only be called by the contract owner
     * @dev The interest rate must be lower than the current interest rate
     */
    function setInterestRate(uint256 interestRate) external onlyOwner {
        if(interestRate >= s_interestRate) {
            revert RebaseToken__NewInterestRateMustBeLowerThanOld();
        }
        s_interestRate = interestRate;
        emit InterestRateSet(interestRate);
    }

    /**
     * @notice Mint new tokens to the specified address
     * @param _to The address to mint tokens to
     * @param _amount The amount of tokens to mint
     * @dev This function mints new tokens and updates the user's interest rate
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_BURN_ROLE) {
        _accruedMintInterest(_to);
        s_UserInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn tokens from the specified address
     * @param _from The address to burn tokens from
     * @param _amount The amount of tokens to burn
     * @dev This function burns tokens and updates the user's interest rate
     * @notice If amount is max uint256 then just set the amount to whatever balance is
     * @notice amount shoudlnt be more than the balance else it will revert internally
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_BURN_ROLE) {
        uint256 currentBalance = balanceOf(_from);
        if(_amount == type(uint256).max){
            _amount = currentBalance;
        }
        _accruedMintInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @notice Transfer tokens from the caller to the specified address
     * @param _to The address to transfer tokens to
     * @param _amount The amount of tokens to transfer
     * @return success A boolean indicating whether the transfer was successful
     * @dev This function overrides the transfer function from ERC20
     * @dev It updates the user's interest rate and last updated time
     */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _accruedMintInterest(_to);
        _accruedMintInterest(msg.sender);
        /** If its a new account, we assume the user wants to transfer his funds from his prev account to new account and make the new account also inherit the interest rate from previous account
         */
        if(_amount == type(uint256).max){
            _amount = balanceOf(msg.sender);
        }
        if(balanceOf(_to) == 0 && _amount > 0){
            s_UserInterestRate[_to] = s_UserInterestRate[msg.sender];
        }
        return super.transfer(_to, _amount);
    }

    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _accruedMintInterest(_to);
        _accruedMintInterest(_from);
        /** If its a new account, we assume the user wants to transfer his funds from his prev account to new account and make the new account also inherit the interest rate from previous account
         */
        if(_amount == type(uint256).max){
            _amount = balanceOf(_from);
        }
        if(balanceOf(_to) == 0 && _amount > 0){
            s_UserInterestRate[_to] = s_UserInterestRate[_from];
        }
        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @notice Grant the mint and burn role to the specified user
     * @param _user The address of the user to grant the role to
     * @dev This function can only be called by the contract owner
     */
    function grantMintAndBurnRole(address _user) external onlyOwner {
        grantRole(MINT_BURN_ROLE, _user);
    }

    /**
     * INTERNAL FUNCTIONS
     */

    /**
     * @notice Update the user's interest rate and last updated time
     * @param _user The address of the user
     * @dev This function is called when a user mints new tokens
     * @notice This is supposed to perform interest to be given calculations
     * @notice will update the user's balance wioth interest
     * @notice will set and update the time stamp upon update of user
     */
    function _accruedMintInterest(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);

        uint256 currentPrinciple = balanceOf(_user);

        uint256 balanceIncrease = currentPrinciple - previousPrincipleBalance;
        s_lastUserUpdatedTime[_user] = block.timestamp;

        if(balanceIncrease > 0){
            _mint(_user, balanceIncrease);
        }
    }

    /**
     * @notice Calculate the interest growth factor for the user
     * @param _user The address of the user
     * @return growthFactor The interest growth factor for the user
     * @dev This function is called to calculate the interest growth factor for a user
     * 1 + Rate * Time
     */
    function _calculateInterestGrowthFactor(address _user) internal view returns (uint256 growthFactor) {
        uint256 timeElapsed = block.timestamp - s_lastUserUpdatedTime[_user];

        if (timeElapsed == 0 || s_UserInterestRate[_user] == 0) {
            return PRECISION_FACTOR;
        }

        uint256 fractionalInterestRate = s_UserInterestRate[_user] * timeElapsed;

        growthFactor = PRECISION_FACTOR + fractionalInterestRate;
    }

    /**
     * PUBLIC VIEW & PURE FUNCTIONS
     */
    function getInterestRate() public view returns (uint256) {
        return s_interestRate;
    }
    function getUserInterestRate(address userAddress) public view returns (uint256) {
        return s_UserInterestRate[userAddress];
    }
    function getUserLastUpdatedTime(address userAddress) public view returns (uint256) {
        return s_lastUserUpdatedTime[userAddress];
    }
    function getPrecisionFactor() public pure returns (uint256) {
        return PRECISION_FACTOR;
    }
    /**
     * 
     * @param userAddress The address of the user
     * @return The principal balance of the user
     * @dev This function returns the principal balance of the user
     * @notice It does not include the interest growth factor
     */
    function getPrincipalBalance(address userAddress) public view returns (uint256) {
        return super.balanceOf(userAddress);
    }

    /**
     * @notice Get the balance of the specified address
     * @param _user The address to get the balance of
     * @return The balance of the specified address
     * @dev This function overrides the balanceOf function from ERC20
     * @dev It calculates the balance with interest growth factor
     */
    function balanceOf(address _user) public view override returns (uint256) {
        uint256 principalBalance = super.balanceOf(_user);
        uint256 growthFactor = _calculateInterestGrowthFactor(_user);
        return (principalBalance * growthFactor) / PRECISION_FACTOR;
    }
}