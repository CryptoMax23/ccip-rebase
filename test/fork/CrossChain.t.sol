// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {RebaseTokenPool} from "../../src/RebaseTokenPool.sol";

import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChainTest is Test {
    uint256 sepoliaFork;
    uint256 arbsepFork;
    CCIPLocalSimulatorFork ccipLocalSimulator;
    RebaseToken public rebaseTokenSepolia;
    RebaseToken public rebaseTokenArbSepolia;
    RebaseTokenPool public rebaseTokenPoolSepolia;
    RebaseTokenPool public rebaseTokenPoolArbSepolia;
    Register.NetworkDetails networkDetailsSepolia;
    Register.NetworkDetails networkDetailsArbSepolia;

    Vault public vault;
    IRebaseToken public i_rebaseToken;

    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");

    function setUp() external {
        sepoliaFork = vm.createSelectFork("sepolia");
        arbsepFork = vm.createFork("arb-sepolia");
        ccipLocalSimulator = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulator));

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        rebaseTokenSepolia = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseTokenSepolia)));
        vm.stopPrank();
        vm.selectFork(arbsepFork);
        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        rebaseTokenArbSepolia = new RebaseToken();
        vm.stopPrank();

        vm.selectFork(sepoliaFork);
        networkDetailsSepolia = ccipLocalSimulator.getNetworkDetails(block.chainid);

        vm.selectFork(arbsepFork);
        networkDetailsArbSepolia = ccipLocalSimulator.getNetworkDetails(block.chainid);

        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        rebaseTokenPoolSepolia = new RebaseTokenPool(
            IERC20(address(rebaseTokenSepolia)),
            new address[](0),
            networkDetailsSepolia.rmnProxyAddress,
            networkDetailsSepolia.routerAddress
        );
        vm.stopPrank();

        vm.selectFork(arbsepFork);
        vm.startPrank(owner);
        rebaseTokenPoolArbSepolia = new RebaseTokenPool(
            IERC20(address(rebaseTokenArbSepolia)),
            new address[](0),
            networkDetailsArbSepolia.rmnProxyAddress,
            networkDetailsArbSepolia.routerAddress
        );
        vm.stopPrank();

        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        rebaseTokenSepolia.grantMintAndBurnRole(address(vault));
        rebaseTokenSepolia.grantMintAndBurnRole(address(rebaseTokenPoolSepolia));
        vm.stopPrank();

        vm.selectFork(arbsepFork);
        vm.startPrank(owner);
        rebaseTokenArbSepolia.grantMintAndBurnRole(address(rebaseTokenPoolArbSepolia));
        vm.stopPrank();

        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        RegistryModuleOwnerCustom(networkDetailsSepolia.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(rebaseTokenSepolia)
        );
        vm.stopPrank();

        vm.selectFork(arbsepFork);
        vm.startPrank(owner);
        RegistryModuleOwnerCustom(networkDetailsArbSepolia.registryModuleOwnerCustomAddress).registerAdminViaOwner(
            address(rebaseTokenArbSepolia)
        );
        vm.stopPrank();

        vm.selectFork(sepoliaFork);
        vm.startPrank(owner);
        TokenAdminRegistry(networkDetailsSepolia.tokenAdminRegistryAddress).acceptAdminRole(address(rebaseTokenSepolia));
        TokenAdminRegistry(networkDetailsSepolia.tokenAdminRegistryAddress).setPool(
            address(rebaseTokenSepolia), address(rebaseTokenPoolSepolia)
        );
        vm.stopPrank();

        vm.selectFork(arbsepFork);
        vm.startPrank(owner);
        TokenAdminRegistry(networkDetailsArbSepolia.tokenAdminRegistryAddress).acceptAdminRole(
            address(rebaseTokenArbSepolia)
        );
        TokenAdminRegistry(networkDetailsArbSepolia.tokenAdminRegistryAddress).setPool(
            address(rebaseTokenArbSepolia), address(rebaseTokenPoolArbSepolia)
        );
        vm.stopPrank();
        configureTokenPool(
            arbsepFork,
            address(rebaseTokenPoolArbSepolia),
            networkDetailsSepolia.chainSelector,
            address(rebaseTokenPoolSepolia),
            address(rebaseTokenSepolia)
        );

        configureTokenPool(
            sepoliaFork,
            address(rebaseTokenPoolSepolia),
            networkDetailsArbSepolia.chainSelector,
            address(rebaseTokenPoolArbSepolia),
            address(rebaseTokenArbSepolia)
        );
    }

    function configureTokenPool(
        uint256 forkId,
        address localPoolAddress,
        uint64 remoteChainSelector,
        address remotePoolAddress,
        address remoteTokenAddress
    ) public {
        vm.selectFork(forkId);
        vm.startPrank(owner);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        bytes[] memory poolAddresses = new bytes[](1);
        poolAddresses[0] = abi.encode(remotePoolAddress);
        
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            remotePoolAddresses: poolAddresses,
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false, capacity: 0, rate: 0})
        });
        uint64[] memory chainsToRemove = new uint64[](0);
        TokenPool(localPoolAddress).applyChainUpdates(chainsToRemove, chainsToAdd);
        vm.stopPrank();
    }

    function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork, // Source chain fork ID
        uint256 remoteFork, // Destination chain fork ID
        Register.NetworkDetails memory localNetworkDetails, // Struct with source chain info
        Register.NetworkDetails memory remoteNetworkDetails, // Struct with dest. chain info
        RebaseToken localToken, // Source token contract instance
        RebaseToken remoteToken // Destination token contract instance
    ) public {
        vm.selectFork(localFork);

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(user1),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000}))
        });

        uint256 fee =
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message);

        ccipLocalSimulator.requestLinkFromFaucet(user1, fee);

        vm.startPrank(user1);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress, fee);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        uint256 localBalBefore = localToken.balanceOf(user1);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message);

        uint256 localBalAfter = localToken.balanceOf(user1);
        assertEq(localBalAfter, localBalBefore - amountToBridge);
        vm.stopPrank();

        vm.warp(block.timestamp + 20 minutes);
        vm.selectFork(remoteFork);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(user1);
        ccipLocalSimulator.switchChainAndRouteMessage(remoteFork);
        uint256 remoteBalanceAfter = remoteToken.balanceOf(user1);
        assertEq(remoteBalanceAfter, remoteBalanceBefore + amountToBridge);
    }

    function testBridgeTokens() external {
        uint256 amountToBridge = 1e5;
        vm.selectFork(sepoliaFork);
        vm.startPrank(user1);
        vm.deal(user1, amountToBridge);
        Vault(payable(address(vault))).deposit{value: amountToBridge}();
        uint256 initBalance = IERC20(address(rebaseTokenSepolia)).balanceOf(user1);
        assertEq(initBalance, amountToBridge);

        bridgeTokens(
            amountToBridge,
            sepoliaFork, // Source chain fork ID
            arbsepFork, // Destination chain fork ID
            networkDetailsSepolia, // Struct with source chain info
            networkDetailsArbSepolia, // Struct with dest. chain info
            rebaseTokenSepolia, // Source token contract instance
            rebaseTokenArbSepolia // Destination token contract instance
        );

        vm.selectFork(arbsepFork);
        vm.warp(block.timestamp + 20 minutes);
        uint256 arbsepBalanceBefore = rebaseTokenArbSepolia.balanceOf(user1);
        assertTrue(arbsepBalanceBefore > 0);
        vm.stopPrank();

        bridgeTokens(
            arbsepBalanceBefore,
            arbsepFork, // Source chain fork ID
            sepoliaFork, // Destination chain fork ID
            networkDetailsArbSepolia, // Struct with source chain info
            networkDetailsSepolia, // Struct with dest. chain info
            rebaseTokenArbSepolia, // Source token contract instance
            rebaseTokenSepolia // Destination token contract instance
        );
    }
}
