// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {BasicRom} from "../src/BasicRom.sol";
import {Emulator6502} from "../src/Emulator6502.sol";

/// @dev Example script: deploys cartridge + emulator and loads ROM at $8000.
contract LoadRomScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy cartridge contract (replace with real ROM bytes in BasicRom)
        BasicRom rom = new BasicRom();

        // Deploy emulator
        Emulator6502 emu = new Emulator6502();

        // Load ROM into emulator at $8000
        emu.loadRomFrom(address(rom), 0x8000);

        vm.stopBroadcast();
    }
} 