// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");

    function setUp() external {
        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1 ether}("");
        require(success, "Failed to send Ether");
        vm.stopPrank();
    }

    function _addRewardsToVault(uint256 amount) internal {
        vm.startPrank(owner);
        vm.deal(owner, amount);
        (bool success,) = payable(address(vault)).call{value: amount}("");
        require(success, "Failed to send Ether");
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) external {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();

        uint256 initBalance = rebaseToken.balanceOf(user1);
        assertEq(initBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 midBalance = rebaseToken.balanceOf(user1);
        assertGt(midBalance, initBalance);
        vm.warp(block.timestamp + 1 hours);
        uint256 finalBalance = rebaseToken.balanceOf(user1);
        assertGt(finalBalance, midBalance);
        assertApproxEqAbs(finalBalance - midBalance, midBalance - initBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) external {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        vault.redeem(amount);
        uint256 initBalance = rebaseToken.balanceOf(user1);
        assertEq(initBalance, 0);
        uint256 userBalance = address(user1).balance;
        assertEq(userBalance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePasses(uint256 amount) external {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfterTime = rebaseToken.balanceOf(user1);
        assertGt(balanceAfterTime, amount);
        vm.stopPrank();
        _addRewardsToVault(balanceAfterTime - amount);
        vm.startPrank(user1);
        vault.redeem(balanceAfterTime);
        uint256 userBalance = address(user1).balance;
        assertEq(userBalance, balanceAfterTime);
        uint256 finalBalance = rebaseToken.balanceOf(user1);
        assertEq(finalBalance, 0);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount) external {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        vm.stopPrank();
        vm.startPrank(owner);
        rebaseToken.setInterestRate(4e10);
        vm.warp(block.timestamp + 1 hours);
        vm.stopPrank();

        vm.startPrank(user1);
        uint256 newBalance = rebaseToken.balanceOf(user1);
        assertGt(newBalance, amount);
        rebaseToken.transfer(user2, newBalance);
        uint256 user1Balance = rebaseToken.balanceOf(user1);
        assertEq(user1Balance, 0);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(user2Balance, newBalance);
        uint256 user2InterestRate = rebaseToken.getUserInterestRate(user2);
        assertEq(user2InterestRate, 5e10);
    }

    function testGetPrincipalBalance(uint256 amount) external {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user1);
        vm.deal(user1, amount);
        vault.deposit{value: amount}();
        uint256 principalBalance = rebaseToken.getPrincipalBalance(user1);
        assertEq(principalBalance, amount);
        vm.warp(block.timestamp + 1 hours);
        uint256 newPrincipalBalance = rebaseToken.getPrincipalBalance(user1);
        assertEq(newPrincipalBalance, principalBalance);
    }

    function testCannotSetInterestRateIfNotOwner() external {
        vm.startPrank(user1);
        vm.expectRevert();
        rebaseToken.setInterestRate(4e10);
        vm.stopPrank();
    }

    function testCannotCallMintAndBurnRoleIfNotVault() external {
        vm.startPrank(user1);
        vm.expectRevert();
        rebaseToken.mint(user1, 1e5, 5e10);
        vm.stopPrank();
    }
}
