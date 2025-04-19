// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract ShiftRotateTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function _flag(uint8 mask) internal view returns (bool) {
        (, , , , , uint8 P, ) = emu.cpu();
        return (P & mask) != 0;
    }

    function test_ASLAccumulator() public {
        // A=0x80 (1000 0000) after ASL => 0x00, C=1, Z=1, N=0
        emu.testSetPC(0xB300);
        emu.testSetA(0x80);
        emu.poke8(0xB300, 0x0A); // ASL A
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x00);
        assertTrue(_flag(1 << 0)); // Carry
        assertTrue(_flag(1 << 1)); // Zero
        assertFalse(_flag(1 << 7)); // Negative
    }

    function test_LSRAccumulator() public {
        // A=0x01 => 0x00, C=1, Z=1
        emu.testSetPC(0xB400);
        emu.testSetA(0x01);
        emu.poke8(0xB400, 0x4A); // LSR A
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x00);
        assertTrue(_flag(1 << 0)); // Carry
        assertTrue(_flag(1 << 1)); // Zero
    }

    function test_ROLAccumulator_WithCarryIn() public {
        // Set carry =1, A=0x01 (0000 0001) => result 0x03, C=0
        emu.testSetPC(0xB500);
        emu.testSetA(0x01);
        emu.testSetFlag(0, true); // carry in
        emu.poke8(0xB500, 0x2A); // ROL A
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x03);
        assertFalse(_flag(1 << 0)); // Carry cleared (bit7 was 0)
        assertFalse(_flag(1 << 7)); // Negative
    }

    function test_RORAccumulator_WithCarryIn() public {
        // Set carry=1, A=0x02 (0000 0010) => After ROR: 0x81, C=0x0 (bit0 of original)
        emu.testSetPC(0xB600);
        emu.testSetA(0x02);
        emu.testSetFlag(0, true); // carry in
        emu.poke8(0xB600, 0x6A); // ROR A
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x81);
        assertFalse(_flag(1 << 0)); // Carry cleared (original bit0 =0)
        assertTrue(_flag(1 << 7)); // Negative set
    }
} 