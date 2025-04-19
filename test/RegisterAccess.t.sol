// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract RegisterAccessTest is Test {
    Emulator6502 internal emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_SetAndGetFlags() public {
        // Initially I flag set only
        assertTrue(emu.testGetFlag(2)); // I
        assertFalse(emu.testGetFlag(0)); // C

        // Set C and Z
        emu.testSetFlag(0, true);
        emu.testSetFlag(1, true);

        assertTrue(emu.testGetFlag(0));
        assertTrue(emu.testGetFlag(1));

        // Clear I flag
        emu.testSetFlag(2, false);
        assertFalse(emu.testGetFlag(2));
    }
} 