// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRebaseToken} from "./interfaces/IRebaseToken.sol"; // Adjust path if your interface is elsewhere
import {Pool} from "@ccip/contracts/src/v0.8/ccip/libraries/Pool.sol"; // For CCIP structs

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token, address[] memory _allowlist, address _rnmProxy, address _router)
        TokenPool(_token,18, _allowlist, _rnmProxy, _router)
    {
        // Constructor body (if any additional logic is needed)
    }

    // We will implement lockOrBurn and releaseOrMint functions next
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn)
        external
        override
        returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut)
    {
        _validateLockOrBurn(lockOrBurnIn);
        address originalSender = lockOrBurnIn.originalSender;
        uint256 interestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);
        IRebaseToken(address(i_token)).burn(address(this), lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(interestRate)
        });
    }

    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn)
        external
        override
        returns (Pool.ReleaseOrMintOutV1 memory releaseOrMintOut)
    {
        _validateReleaseOrMint(releaseOrMintIn);
        uint256 interestRate = abi.decode(releaseOrMintIn.sourcePoolData, (uint256));
        address reciever = releaseOrMintIn.receiver;

        IRebaseToken(address(i_token)).mint(reciever, releaseOrMintIn.amount, interestRate);

        releaseOrMintOut = Pool.ReleaseOrMintOutV1({destinationAmount: releaseOrMintIn.amount});
    }
}
