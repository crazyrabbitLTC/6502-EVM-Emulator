// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract AddressingModesTest is Test {
    Emulator6502 internal emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_Immediate() public {
        // Write literal 0x99 at PC=0x8000
        emu.testSetPC(0x8000);
        emu.poke8(0x8000, 0x99);

        uint16 addr = emu.addrImmediate();
        assertEq(addr, 0x8000);
        assertEq(emu.peek8(addr), 0x99);
    }

    function test_ZeroPageXWrap() public {
        emu.testSetPC(0x9000);
        emu.testSetX(0x0f);
        emu.poke8(0x9000, 0xf8); // base addr 0xf8
        uint16 addr = emu.addrZeroPageX();
        // expect wrap: 0xf8 + 0x0f = 0x07
        assertEq(addr, 0x0007);
    }

    function test_AbsoluteXPageCross() public {
        emu.testSetPC(0xA000);
        emu.testSetX(0x10);
        // write low byte 0xFF, high 0x20 → base 0x20FF, +0x10 -> 0x210F crossing
        emu.poke8(0xA000, 0xFF);
        emu.poke8(0xA001, 0x20);
        (uint16 addr, bool crossed) = emu.addrAbsoluteX();
        assertEq(addr, 0x210F);
        assertTrue(crossed);
    }
} 