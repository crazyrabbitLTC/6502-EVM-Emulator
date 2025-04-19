// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract ArithmeticTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function _flag(uint8 mask) internal view returns (bool) {
        (, , , , , uint8 P, ) = emu.cpu();
        return (P & mask) != 0;
    }

    function test_ADC_NoCarry() public {
        // A=0x01, ADC #$01 => 0x02
        emu.testSetPC(0x9000);
        emu.testSetA(0x01);
        emu.testSetFlag(0, false); // Clear carry
        emu.poke8(0x9000, 0x69);
        emu.poke8(0x9001, 0x01);
        emu.step();
        (uint8 A, , , , , uint8 P, ) = emu.cpu();
        assertEq(A, 0x02);
        assertFalse(_flag(1 << 0)); // Carry
        assertFalse(_flag(1 << 1)); // Zero
        assertFalse(_flag(1 << 7)); // Negative
        assertFalse(_flag(1 << 6)); // Overflow
    }

    function test_ADC_CarryAndZero() public {
        // A=0x01, ADC #0xFF => 0x00 carry set, zero set
        emu.testSetPC(0x9100);
        emu.testSetA(0x01);
        emu.testSetFlag(0, false);
        emu.poke8(0x9100, 0x69);
        emu.poke8(0x9101, 0xFF);
        emu.step();
        (uint8 A, , , , , , ) = emu.cpu();
        assertEq(A, 0x00);
        assertTrue(_flag(1 << 0)); // Carry
        assertTrue(_flag(1 << 1)); // Zero
    }

    function test_ADC_Overflow() public {
        // A=0x01, ADC #0x7F => 0x80 overflow set, negative set
        emu.testSetPC(0x9200);
        emu.testSetA(0x01);
        emu.testSetFlag(0, false);
        emu.poke8(0x9200, 0x69);
        emu.poke8(0x9201, 0x7F);
        emu.step();
        (uint8 A, , , , , , ) = emu.cpu();
        assertEq(A, 0x80);
        assertFalse(_flag(1 << 0)); // Carry
        assertTrue(_flag(1 << 6)); // Overflow
        assertTrue(_flag(1 << 7)); // Negative
    }
} 