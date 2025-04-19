// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract OpcodeMatrixTest is Test {
    Emulator6502 emu;

    function setUp() public {
        emu = new Emulator6502();
    }

    function _execute(uint8 opcode) internal returns (bool implemented) {
        uint16 pc = 0x8000;
        emu.testSetPC(pc);
        emu.poke8(pc, opcode);
        // Write dummy operand bytes (0x00) to avoid out‑of‑bounds for multi‑byte insns
        emu.poke8(pc + 1, 0x00);
        emu.poke8(pc + 2, 0x00);
        try emu.step() {
            implemented = true;
        } catch Error(string memory reason) {
            // Only treat explicit OpcodeNotImplemented as unimplemented
            if (keccak256(bytes(reason)) == keccak256("OpcodeNotImplemented")) {
                implemented = false;
            } else {
                // Any other revert propagate as test failure
                revert(reason);
            }
        }
    }

    function test_AllOpcodesHandledOrRevert() public {
        uint256 implementedCount;
        for (uint16 op = 0; op < 256; op++) {
            bool ok = _execute(uint8(op));
            if (ok) implementedCount++;
        }
        emit log_uint(implementedCount);
        // Sanity: we expect at least the set we coded ( >60 ).
        assertGt(implementedCount, 50);
    }
} 