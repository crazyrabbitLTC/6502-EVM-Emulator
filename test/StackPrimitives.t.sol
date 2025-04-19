// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract StackPrimitivesTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function test_PushPop8() public {
        // initial SP = 0xFD per reset state
        (, , , uint8 spInitial, , ,) = emu.cpu();
        assertEq(spInitial, 0xFD);

        emu.testPush8(0x42);
        (, , , uint8 spAfterPush, , ,) = emu.cpu();
        assertEq(spAfterPush, 0xFC, "SP should post-decrement");

        uint8 val = emu.testPop8();
        assertEq(val, 0x42, "popped value mismatch");

        (, , , uint8 spAfterPop, , ,) = emu.cpu();
        assertEq(spAfterPop, 0xFD, "SP should return to original");
    }

    function test_PushPop16() public {
        // Push 0xBEEF and pop
        (, , , uint8 spStart, , ,) = emu.cpu();
        emu.testPush16(0xBEEF);
        (, , , uint8 spAfterPush, , ,) = emu.cpu();
        assertEq(spAfterPush, spStart - 2);

        uint16 val = emu.testPop16();
        assertEq(val, 0xBEEF);
        (, , , uint8 spAfterPop, , ,) = emu.cpu();
        assertEq(spAfterPop, spStart);
    }

    function test_PHA_PLA() public {
        emu.testSetPC(0x8000);
        emu.testSetA(0x7F);
        emu.poke8(0x8000, 0x48); // PHA
        emu.poke8(0x8001, 0x68); // PLA

        emu.step(); // PHA
        emu.step(); // PLA

        (uint8 A, , , uint8 sp, , uint8 P,) = emu.cpu();
        assertEq(A, 0x7F);
        assertEq(sp, 0xFD); // stack pointer back
        // Z flag should be 0, N flag 0 since 0x7F positive
        bool Z = (P & 0x02)!=0;
        bool N = (P & 0x80)!=0;
        assertFalse(Z);
        assertFalse(N);
    }

    function test_PHP_PLP() public {
        // Set flags pattern, push and pull
        emu.testSetFlag(0, true); // C
        emu.testSetFlag(7, true); // N

        emu.testSetPC(0x9000);
        emu.poke8(0x9000, 0x08); // PHP
        emu.poke8(0x9001, 0x28); // PLP

        emu.step();
        // Modify flags to check PLP restoration
        emu.testSetFlag(0, false);
        emu.testSetFlag(7, false);
        emu.step();

        (, , , , , uint8 P,) = emu.cpu();
        assertTrue((P & 0x01)!=0); // C restored
        assertTrue((P & 0x80)!=0); // N restored
    }

    function _flag(uint8 mask) internal view returns (bool) {
        (, , , , , uint8 P,) = emu.cpu();
        return (P & mask)!=0;
    }

    function test_TXS_TSX() public {
        // X -> SP
        emu.testSetX(0x10);
        emu.testSetPC(0x9100);
        emu.poke8(0x9100, 0x9A); // TXS
        emu.poke8(0x9101, 0xBA); // TSX
        emu.step();
        (, , , uint8 spAfterTxs,, ,) = emu.cpu();
        assertEq(spAfterTxs, 0x10);

        emu.step();
        (, uint8 X,, , , uint8 P,) = emu.cpu();
        assertEq(X, 0x10);
        // Z and N clear
        assertFalse(_flag(1<<1));
        assertFalse(_flag(1<<7));

        // Now set SP to 0x80 negative test
        emu.testSetSP(0x80);
        emu.testSetPC(0x9200);
        emu.poke8(0x9200, 0xBA);
        emu.step();
        (, uint8 X2,, , , uint8 P2,) = emu.cpu();
        assertEq(X2, 0x80);
        assertTrue((P2 & 0x80)!=0); // N set
    }
} 