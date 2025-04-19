// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {BasicRom} from "../src/BasicRom.sol";
import {Emulator6502} from "../src/Emulator6502.sol";

/// @dev Example script: deploys cartridge + emulator and loads ROM at $8000.
contract LoadRomScript is Script {
    function run() external {
        // 1. Resolve base address from env (defaults to 0x8000)
        uint256 baseAddr;
        try vm.envUint("BASE_ADDR") returns (uint256 v) {
            baseAddr = v;
        } catch {
            baseAddr = 0x8000;
        }

        // Optional: instruction budget after boot for quick smoke (default 0)
        uint256 initialSteps;
        try vm.envUint("RUN_STEPS") returns (uint256 s) {
            initialSteps = s;
        } catch {
            initialSteps = 0;
        }

        vm.startBroadcast();

        // Deploy cartridge contract (replace with real ROM bytes in BasicRom)
        BasicRom rom = new BasicRom();

        // Deploy emulator
        Emulator6502 emu = new Emulator6502();

        // Load ROM into emulator at specified base address
        emu.loadRomFrom(address(rom), uint16(baseAddr));

        // Patch vectors (RESET, IRQ, NMI) to point to baseAddr for convenience
        uint8 lo = uint8(baseAddr & 0xFF);
        uint8 hi = uint8((baseAddr >> 8) & 0xFF);
        emu.poke8(0xFFFC, lo);
        emu.poke8(0xFFFD, hi);
        emu.poke8(0xFFFA, lo); // NMI
        emu.poke8(0xFFFB, hi);
        emu.poke8(0xFFFE, lo); // IRQ/BRK
        emu.poke8(0xFFFF, hi);

        // Boot CPU
        emu.boot();

        // Optionally run some steps to reach prompt
        if (initialSteps > 0) {
            emu.run(uint64(initialSteps));
        }

        vm.stopBroadcast();
    }
} 