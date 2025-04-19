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

    function test_ZeroPageYWrap() public {
        emu.testSetPC(0xB000);
        emu.testSetY(0x0d);
        emu.poke8(0xB000, 0xF6); // base 0xF6
        uint16 addr = emu.addrZeroPageY();
        // 0xF6 + 0x0d = 0x03 with wrap
        assertEq(addr, 0x0003);
    }

    function test_RelativeForward() public {
        emu.testSetPC(0xB100);
        emu.poke8(0xB100, 0x05); // +5
        (uint16 target, bool crossed) = emu.addrRelative();
        assertEq(target, 0xB106); // PC after fetch 0xB101 +5 =0xB106
        assertFalse(crossed);
    }

    function test_RelativeBackwardNoPageCross() public {
        emu.testSetPC(0xB1F0);
        emu.poke8(0xB1F0, 0xF0); // -16 (0xF0 signed)
        (uint16 target, bool crossed) = emu.addrRelative();
        assertEq(target, 0xB1F1 - 0x10); // 0xB1F1 (after fetch) -16 = 0xB1E1
        assertFalse(crossed);
    }

    function test_RelativeBackwardPageCross() public {
        emu.testSetPC(0xC000);
        emu.poke8(0xC000, 0x80); // -128 (0x80 signed)
        (uint16 target, bool crossed) = emu.addrRelative();
        assertEq(target, 0xBF81); // 0xC001 - 128 = 0xBF81
        assertTrue(crossed);
    }

    function test_IndirectPageBug() public {
        // Pointer = 0x12FF (low FF, high 12)
        emu.testSetPC(0xD000);
        emu.poke8(0xD000, 0xFF); // low byte ptr
        emu.poke8(0xD001, 0x12); // high byte ptr
        // Write target low/high obeying wrap bug
        emu.poke8(0x12FF, 0x34); // low target byte
        emu.poke8(0x1200, 0x12); // high target byte (wrap within page)
        uint16 addr = emu.addrIndirect();
        assertEq(addr, 0x1234);
    }
} 