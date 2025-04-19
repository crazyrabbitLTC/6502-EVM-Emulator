// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract OpcodeTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_LDAImmediate() public {
        // Program: LDA #$7F ; BRK (0x00) to stop (not implemented but okay)
        emu.testSetPC(0x8000);
        emu.poke8(0x8000, 0xA9); // LDA #imm
        emu.poke8(0x8001, 0x7F);

        emu.step();

        (uint8 A, uint8 _x, uint8 _y, uint8 _sp, uint16 _pc, uint8 P, uint64 _cycles) = emu.cpu();
        assertEq(A, 0x7F);
        // Zero flag cleared, Negative flag cleared
        bool Z = (P & (1 << 1)) != 0;
        bool N = (P & (1 << 7)) != 0;
        assertFalse(Z);
        assertFalse(N);
    }

    function test_LDAZeroPage() public {
        emu.testSetPC(0x8200);
        emu.poke8(0x8200, 0xA5); // LDA $44
        emu.poke8(0x8201, 0x44);
        emu.poke8(0x0044, 0x00); // value 0 sets Z flag

        emu.step();

        (, , , , , uint8 P, ) = emu.cpu();
        bool Z = (P & (1 << 1)) != 0;
        assertTrue(Z);
    }

    function test_LDAAbsoluteNegative() public {
        emu.testSetPC(0x8300);
        emu.poke8(0x8300, 0xAD); // LDA $1234
        emu.poke8(0x8301, 0x34);
        emu.poke8(0x8302, 0x12);
        emu.poke8(0x1234, 0x80); // Negative bit set

        emu.step();

        (, , , , , uint8 P, ) = emu.cpu();
        bool N = (P & (1 << 7)) != 0;
        assertTrue(N);
    }
} 