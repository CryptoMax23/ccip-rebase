// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

contract BridgeTokensScript is Script {
    function run(
        address receiverAddress, // Address receiving tokens on the destination chain
        uint64 destinationChainSelector, // CCIP selector for the destination chain
        address tokenToSendAddress, // Address of the ERC20 token being bridged
        uint256 amountToSend, // Amount of the token to bridge
        address linkTokenAddress, // Address of the LINK token (for fees) on the source chain
        address routerAddress
    ) public {
        vm.startBroadcast();

        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(tokenToSendAddress), amount: amountToSend});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 500_000}))
        });

        uint256 fee = IRouterClient(routerAddress).getFee(destinationChainSelector, message);

        IERC20(linkTokenAddress).approve(routerAddress, fee);
        IERC20(address(tokenToSendAddress)).approve(routerAddress, amountToSend);

        IRouterClient(routerAddress).ccipSend(destinationChainSelector, message);

        vm.stopBroadcast();
    }
}
