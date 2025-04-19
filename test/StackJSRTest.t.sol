// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract StackJSRTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_JSR_RTS() public {
        // Program: JSR $9000 ; (subroutine) RTS
        emu.testSetPC(0x8000);
        emu.poke8(0x8000, 0x20); // JSR
        emu.poke8(0x8001, 0x00);
        emu.poke8(0x8002, 0x90);
        emu.poke8(0x9000, 0x60); // RTS

        emu.step(); // Execute JSR
        (, , , uint8 spAfterJSR,, ,) = emu.cpu();
        // Stack pointer should be 0xFB (two pushes)
        assertEq(spAfterJSR, 0xFB);

        emu.step(); // Execute RTS
        (, , , uint8 spAfterRTS, uint16 pcAfterRTS,,) = emu.cpu();
        assertEq(spAfterRTS, 0xFD);
        assertEq(pcAfterRTS, 0x8003); // Return to after JSR
    }
} 