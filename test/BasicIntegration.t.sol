// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {BasicRom} from "../src/BasicRom.sol";
import {Emulator6502} from "../src/Emulator6502.sol";

/// @title BasicIntegrationTest – runs the tiny ROM that prints '4'
contract BasicIntegrationTest is Test {
    Emulator6502 emu;
    BasicRom rom;

    function setUp() public {
        rom = new BasicRom();
        // BasicRom bytecode already contains the full 16 KiB EhBASIC image, so no
        // need to read from disk or use `vm.etch`.

        emu = new Emulator6502();

        // Load ROM at $A000 (native EhBASIC base)
        emu.loadRomFrom(address(rom), 0xA000);

        // Patch reset vector to $8000 (start of our stub)
        emu.poke8(0xFFFC, 0x00);
        emu.poke8(0xFFFD, 0x80);

        // Overwrite reset vector entry ($8000..) with stub:
        // LDA #$34 ; STA $F001 ; BRK
        emu.poke8(0x8000, 0xA9); // LDA immediate
        emu.poke8(0x8001, 0x34); // value '4'
        emu.poke8(0x8002, 0x8D); // STA abs
        emu.poke8(0x8003, 0x01);
        emu.poke8(0x8004, 0xF0); // $F001
        emu.poke8(0x8005, 0x00); // BRK – halts CPU

        emu.boot();
    }

    function testRomPrintsFour() public {
        vm.recordLogs();

        // Run enough steps: LDA (2) + STA (4) + BRK (7) cycles – use generous budget
        emu.run(50);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Expect at least one CharOut event with ASCII '4'
        bool found;
        bytes32 topic0 = keccak256("CharOut(uint8)");
        for (uint i; i < logs.length; ++i) {
            if (logs[i].topics[0] == topic0) {
                uint8 val = abi.decode(logs[i].data, (uint8));
                if (val == 0x34) {
                    found = true;
                    break;
                }
            }
        }

        assertTrue(found, "CharOut '4' not emitted");
        assertTrue(emu.halted(), "CPU did not halt on BRK");
    }
} 