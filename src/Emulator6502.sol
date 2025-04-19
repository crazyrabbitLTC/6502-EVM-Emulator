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
        _initMemory();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   PUBLIC API
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes one instruction (stub in Phase 0)
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

    /*//////////////////////////////////////////////////////////////////////////
                                   MEMORY
    //////////////////////////////////////////////////////////////////////////*/

    bytes internal RAM; // 64 KiB main memory

    /// @dev Allocate full 64 KiB RAM on deployment
    function _initMemory() internal {
        RAM = new bytes(65536);
    }

    /// @dev Read an 8‑bit value from RAM
    function _read8(uint16 addr) internal view returns (uint8) {
        return uint8(RAM[addr]);
    }

    /// @dev Write an 8‑bit value to RAM
    function _write8(uint16 addr, uint8 value) internal {
        RAM[addr] = bytes1(value);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   FLAG HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function _getFlag(uint8 flag) internal view returns (bool) {
        return (cpu.P & uint8(1 << flag)) != 0;
    }

    function _setFlag(uint8 flag, bool value) internal {
        if (value) {
            cpu.P |= uint8(1 << flag);
        } else {
            cpu.P &= ~uint8(1 << flag);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                            WRAPPERS (TESTING ONLY)
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Expose RAM peek for tests
    function peek8(uint16 addr) external view returns (uint8) {
        return _read8(addr);
    }

    /// @notice Expose RAM poke for tests
    function poke8(uint16 addr, uint8 value) external {
        _write8(addr, value);
    }

    /// @notice Expose flag helpers for tests
    function testSetFlag(uint8 flag, bool value) external {
        _setFlag(flag, value);
    }

    function testGetFlag(uint8 flag) external view returns (bool) {
        return _getFlag(flag);
    }
} 