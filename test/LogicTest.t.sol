// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract LogicTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function _flag(uint8 mask) internal view returns (bool) {
        (, , , , , uint8 P, ) = emu.cpu();
        return (P & mask) != 0;
    }

    function test_ORA() public {
        // A = 0x10; ORA #0x01 -> 0x11 (N=0, Z=0)
        emu.testSetPC(0xB000);
        emu.testSetA(0x10);
        emu.poke8(0xB000, 0x09);
        emu.poke8(0xB001, 0x01);
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x11);
        assertFalse(_flag(1<<1));
        assertFalse(_flag(1<<7));
    }

    function test_EOR_ZeroNegative() public {
        // A=0xFF xor 0xFF => 0x00 sets Z, clears N
        emu.testSetPC(0xB100);
        emu.testSetA(0xFF);
        emu.poke8(0xB100, 0x49);
        emu.poke8(0xB101, 0xFF);
        emu.step();
        (uint8 A,, , , , ,) = emu.cpu();
        assertEq(A, 0x00);
        assertTrue(_flag(1<<1));
        assertFalse(_flag(1<<7));
    }

    function test_BIT() public {
        // A=0b01000000, operand 0b11000000 => Z=0, N=1, V=1
        emu.testSetPC(0xB200);
        emu.testSetA(0x40);
        emu.poke8(0x0044, 0xC0);
        emu.poke8(0xB200, 0x24); // BIT $44
        emu.poke8(0xB201, 0x44);
        emu.step();
        assertFalse(_flag(1<<1)); // Z
        assertTrue(_flag(1<<7)); // N
        assertTrue(_flag(1<<6)); // V
    }
} 