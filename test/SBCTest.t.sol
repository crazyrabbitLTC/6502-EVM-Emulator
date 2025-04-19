// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract SBCTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function _flag(uint8 mask) internal view returns (bool) {
        (, , , , , uint8 P, ) = emu.cpu();
        return (P & mask) != 0;
    }

    function test_SBC_NoBorrow() public {
        // A=0x03, carry set => subtract 0x01 => 0x02, carry stays 1
        emu.testSetPC(0xA000);
        emu.testSetA(0x03);
        emu.testSetFlag(0, true); // carry = 1 (no borrow)
        emu.poke8(0xA000, 0xE9); // SBC #imm
        emu.poke8(0xA001, 0x01);
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x02);
        assertTrue(_flag(1 << 0)); // Carry
        assertFalse(_flag(1 << 1)); // Zero
        assertFalse(_flag(1 << 7)); // Negative
        assertFalse(_flag(1 << 6)); // Overflow
    }

    function test_SBC_Borrow() public {
        // A=0x00, subtract 0x01 => 0xFF, carry clear
        emu.testSetPC(0xA100);
        emu.testSetA(0x00);
        emu.testSetFlag(0, true);
        emu.poke8(0xA100, 0xE9);
        emu.poke8(0xA101, 0x01);
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0xFF);
        assertFalse(_flag(1 << 0)); // Carry cleared (borrow)
        assertFalse(_flag(1 << 1)); // Zero
        assertTrue(_flag(1 << 7)); // Negative
    }

    function test_SBC_Overflow() public {
        // A=0x80, subtract 0x7F => 0x01, overflow set
        emu.testSetPC(0xA200);
        emu.testSetA(0x80);
        emu.testSetFlag(0, true);
        emu.poke8(0xA200, 0xE9);
        emu.poke8(0xA201, 0x7F);
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x01);
        assertTrue(_flag(1 << 6)); // Overflow
        assertFalse(_flag(1 << 7)); // Negative
    }
} 