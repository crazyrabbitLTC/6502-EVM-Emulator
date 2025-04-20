// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Emulator6502} from "../src/Emulator6502.sol";

/// @title MiniRomHelloTest – minimal self‑contained ROM that prints "HELLO WORLD!" directly
/// @notice Demonstrates the 6502 core can execute real code and drive the IO_TTY device without
///         relying on the full BASIC interpreter.  The program is assembled at $9000 and uses
///         a simple loop that streams the zero‑terminated string to $F001 followed by BRK.
contract MiniRomHelloTest is Test {
    Emulator6502 private emu;

    // Pre‑assembled machine code (see README in comments below)
    bytes constant ROM = hex"a200bd0d90f0138d01f0e8d0f548454c4c4f20574f524c44210000";

    /* Program layout (@ $9000):
    ///   9000  A2 00        LDX #$00
    ///   9002  BD 0D 90     LDA $900D,X ; load byte of message
    ///   9005  F0 13        BEQ $901A   ; 0‑byte terminator → exit
    ///   9007  8D 01 F0     STA $F001   ; write to terminal
    ///   900A  E8           INX         ; X++
    ///   900B  D0 F5        BNE $9002   ; loop
    ///   900D …            "HELLO WORLD!"  (12 bytes)
    ///   9019  00           Terminator
    ///   901A  00           BRK         ; halt CPU – emits ProgramHalted
    */

    function setUp() public {
        emu = new Emulator6502();

        // Copy ROM into RAM at $9000
        for (uint256 i = 0; i < ROM.length; ++i) {
            emu.poke8(uint16(0x9000 + i), uint8(ROM[i]));
        }

        // Point RESET vector ($FFFC/$FFFD) to $9000 little‑endian
        emu.poke8(0xFFFC, 0x00);
        emu.poke8(0xFFFD, 0x90);

        // Boot CPU so it reads new RESET vector
        emu.boot();
    }

    function _collectOutput() internal returns (bytes memory out) {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 sel = keccak256("CharOut(uint8)");
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].topics[0] == sel) {
                out = bytes.concat(out, bytes1(uint8(abi.decode(logs[i].data, (uint8)))));
            }
        }
    }

    function test_miniRomPrintsHelloWorld() public {
        vm.recordLogs();

        // Run with a very small cycle budget – program takes < 500 cycles
        emu.run(5_000);

        bytes memory out = _collectOutput();
        assertEq(string(out), "HELLO WORLD!", "output mismatch");
    }
} 