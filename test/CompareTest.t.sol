// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract CompareTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function _flag(uint8 mask) internal view returns (bool) {
        (, , , , , uint8 P, ) = emu.cpu();
        return (P & mask) != 0;
    }

    function test_CMP_equal() public {
        emu.testSetPC(0xC000);
        emu.testSetA(0x42);
        emu.poke8(0xC000, 0xC9); // CMP #imm
        emu.poke8(0xC001, 0x42);
        emu.step();
        assertTrue(_flag(1<<1)); // Z
        assertTrue(_flag(1<<0)); // C
        assertFalse(_flag(1<<7)); // N
    }

    function test_CMP_less() public {
        emu.testSetPC(0xC100);
        emu.testSetA(0x01);
        emu.poke8(0xC100, 0xC9);
        emu.poke8(0xC101, 0x02);
        emu.step();
        assertFalse(_flag(1<<0)); // C
        assertFalse(_flag(1<<1)); // Z
        assertTrue(_flag(1<<7)); // N
    }

    function test_CMP_greater() public {
        emu.testSetPC(0xC200);
        emu.testSetA(0x03);
        emu.poke8(0xC200, 0xC9);
        emu.poke8(0xC201, 0x02);
        emu.step();
        assertTrue(_flag(1<<0)); // C
        assertFalse(_flag(1<<1)); // Z
        assertFalse(_flag(1<<7)); // N
    }

    function test_CPX_equal() public {
        emu.testSetPC(0xC300);
        emu.testSetX(0x10);
        emu.poke8(0xC300, 0xE0); // CPX #imm
        emu.poke8(0xC301, 0x10);
        emu.step();
        assertTrue(_flag(1<<1));
        assertTrue(_flag(1<<0));
    }

    function test_CPY_less() public {
        emu.testSetPC(0xC400);
        emu.testSetY(0x00);
        emu.poke8(0xC400, 0xC0); // CPY #imm
        emu.poke8(0xC401, 0x01);
        emu.step();
        assertFalse(_flag(1<<0));
        assertTrue(_flag(1<<7));
    }
} 