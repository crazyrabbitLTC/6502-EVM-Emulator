// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Emulator6502 – Minimal 6502 CPU skeleton
/// @notice Phase 0 shell that only initialises registers to power‑on state
/// @dev Further opcodes and memory will be added in later phases
contract Emulator6502 {
    /*//////////////////////////////////////////////////////////////////////////
                                   CPU MODEL
    //////////////////////////////////////////////////////////////////////////*/

    struct CPU {
        uint8 A;      // Accumulator
        uint8 X;      // Index register X
        uint8 Y;      // Index register Y
        uint8 SP;     // Stack pointer ($0100 page offset)
        uint16 PC;    // Program counter
        uint8 P;      // Processor status flags
        uint64 cycles; // Cycle counter (optional)
    }

    CPU public cpu;

    /*//////////////////////////////////////////////////////////////////////////
                                   FLAGS
    //////////////////////////////////////////////////////////////////////////*/

    uint8 private constant FLAG_NEGATIVE  = 7;
    uint8 private constant FLAG_OVERFLOW  = 6;
    uint8 private constant FLAG_UNUSED    = 5; // Always 1 on pushes, 0 otherwise (not enforced yet)
    uint8 private constant FLAG_BREAK     = 4;
    uint8 private constant FLAG_DECIMAL   = 3;
    uint8 private constant FLAG_INTERRUPT = 2;
    uint8 private constant FLAG_ZERO      = 1;
    uint8 private constant FLAG_CARRY     = 0;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _powerOnReset();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   PUBLIC API
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes one instruction (stub in Phase 0)
    function step() external pure {
        revert("NotImplemented");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   INTERNALS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Set registers to the documented power‑on/reset state
    function _powerOnReset() internal {
        cpu.A = 0;
        cpu.X = 0;
        cpu.Y = 0;
        cpu.SP = 0xfd; // Stack pointer after reset (§5)
        cpu.P = uint8(1 << FLAG_INTERRUPT); // I flag set, others cleared
        cpu.PC = 0; // Vector fetch not implemented yet
        cpu.cycles = 0;
    }
} 