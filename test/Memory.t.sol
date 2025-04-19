// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract MemoryTest is Test {
    Emulator6502 internal emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_ReadWriteMemory() public {
        uint16 addr = 0x1234;
        uint8 value = 0x42;

        emu.poke8(addr, value);
        uint8 readVal = emu.peek8(addr);

        assertEq(readVal, value, "Memory mismatch");
    }

    function test_ZeroPageAndStack() public {
        emu.poke8(0x00ff, 0xaa);
        assertEq(emu.peek8(0x00ff), 0xaa);

        emu.poke8(0x01fe, 0xbb);
        assertEq(emu.peek8(0x01fe), 0xbb);
    }
} 