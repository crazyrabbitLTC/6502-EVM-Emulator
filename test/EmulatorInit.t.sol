// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

/// @title EmulatorInitTest – validates power‑on reset state for Phase 0
contract EmulatorInitTest is Test {
    Emulator6502 private emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_PowerOnState() public {
        (uint8 A, uint8 X, uint8 Y, uint8 SP, uint16 PC, uint8 P, uint64 cycles) = emu.cpu();

        assertEq(uint256(A), 0, "A != 0");
        assertEq(uint256(X), 0, "X != 0");
        assertEq(uint256(Y), 0, "Y != 0");
        assertEq(uint256(SP), 0xfd, "SP != 0xfd");
        assertEq(uint256(PC), 0, "PC != 0");
        assertEq(uint256(P), 1 << 2, "P != I flag");
        assertEq(cycles, 0, "cycles != 0");
    }
} 