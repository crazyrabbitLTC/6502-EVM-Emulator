// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract BranchTest is Test {
    Emulator6502 emu;

    function setUp() public { emu = new Emulator6502(); }

    function _runBranch(uint8 opcode, uint8 offset, bool flagSet, uint8 flagBit) internal returns (uint16 pc) {
        uint16 start = 0x8000;
        emu.testSetPC(start);
        emu.poke8(start, opcode);
        emu.poke8(start+1, offset);
        emu.testSetFlag(flagBit, flagSet);
        emu.step();
        (, , , , pc,,) = emu.cpu();
    }

    function test_BCC_taken() public {
        uint16 pc = _runBranch(0x90, 0x02, false, 0); // carry clear
        assertEq(pc, 0x8004);
    }

    function test_BCC_notTaken() public {
        uint16 pc = _runBranch(0x90, 0x02, true, 0);
        assertEq(pc, 0x8002);
    }

    function test_BEQ_taken() public {
        uint16 pc = _runBranch(0xF0, 0x05, true, 1); // Z set
        assertEq(pc, 0x8007);
    }

    function test_BEQ_notTaken() public {
        uint16 pc = _runBranch(0xF0, 0x05, false, 1);
        assertEq(pc, 0x8002);
    }

    function test_BMI_taken() public {
        uint16 pc = _runBranch(0x30, 0xFE, true, 7); // negative, offset -2
        assertEq(pc, 0x8000);
    }

    function test_BNE_taken() public {
        uint16 pc = _runBranch(0xD0, 0x01, false, 1); // Z clear
        assertEq(pc, 0x8003);
    }
} 