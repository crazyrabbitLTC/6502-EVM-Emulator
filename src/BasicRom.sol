// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BasicRom – placeholder cartridge contract
/// @notice Runtime bytecode represents the BASIC ROM image. Replace the hex blob with the real ROM bytes later.
contract BasicRom {
    constructor() {
        // Placeholder ROM: single 0xEA (NOP) instruction
        bytes memory rom = hex"EA";
        assembly {
            return(add(rom, 0x20), mload(rom))
        }
    }
} 