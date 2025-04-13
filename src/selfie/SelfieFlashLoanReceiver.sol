// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

import {ISimpleGovernance} from "./ISimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";

contract SelfieFlashLoanReceiver is IERC3156FlashBorrower {
    ISimpleGovernance simpleGovernance;
    SelfiePool selfiePool;

    address recovery;

    error NotCalledFromPool();

    constructor(
        ISimpleGovernance _simpleGovernance,
        SelfiePool _selfiePool,
        address _recovery
    ) {
        simpleGovernance = _simpleGovernance;
        selfiePool = _selfiePool;
        recovery = _recovery;
    }

    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        // Allow only Selfie Pool to call
        if (msg.sender != address(selfiePool)) revert NotCalledFromPool();

        // Craft the action to be executed
        // Call emergencyExit on the SelfiePool contract
        bytes memory _data = abi.encodeWithSelector(
            SelfiePool.emergencyExit.selector,
            recovery
        );

        // Delegate votes to our self
        DamnValuableVotes(token).delegate(address(this));

        // Queue the action in the governance contract
        simpleGovernance.queueAction(address(selfiePool), 0, _data);

        // Approve the SelfiePool to pull the tokens back
        IERC20(token).approve(address(selfiePool), amount);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
