// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Emulator6502} from "../src/Emulator6502.sol";

contract IOTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function testKeyboardBuffer() public {
        bytes memory keys = "HI"; // 0x48 0x49
        emu.sendKeys(keys);

        // First read
        uint8 b1 = emu.testReadIO(0xF000);
        assertEq(b1, 0x48, "First key");

        // Second read
        uint8 b2 = emu.testReadIO(0xF000);
        assertEq(b2, 0x49, "Second key");

        // Buffer exhausted
        uint8 b3 = emu.testReadIO(0xF000);
        assertEq(b3, 0x00, "Empty returns 0");
    }

    function testCharOutEvent() public {
        vm.expectEmit(false, false, false, true);
        emit Emulator6502.CharOut(0x41); // 'A'
        emu.poke8(0xF001, 0x41);
    }
} 