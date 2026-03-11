// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ClimberTimelock} from "./ClimberTimelock.sol";
import {Test, console} from "forge-std/Test.sol";

contract ScheduleHelper {
    ClimberTimelock public timelock;
    address[] public targets;
    uint256[] public values;
    bytes[] public dataElements;
    bytes32 public salt;

    constructor(address _timelock) {
        timelock = ClimberTimelock(payable(_timelock));
    }

    function setData(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _dataElements,
        bytes32 _salt
    ) external {
        targets = _targets;
        values = _values;
        dataElements = _dataElements;
        salt = _salt;
    }

    function schedule() external {
        timelock.schedule(targets, values, dataElements, salt);
    }
}
