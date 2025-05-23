// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseToken {
    /**
     * @notice Mints tokens to the specified address
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount, uint256 interestRate) external;

    /**
     * @notice Burns tokens from the specified address
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @notice Gets the interest rate for the specified address
     * @param user The address to get the interest rate for
     * @return The interest rate for the specified address
     */
    function getUserInterestRate(address user) external view returns (uint256);

    function getInterestRate() external view returns (uint256);
}
