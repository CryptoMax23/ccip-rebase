// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";


contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");


    function setUp() external {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1 ether}("");
        require(success, "Failed to send Ether");
        vm.stopPrank();
    }
}