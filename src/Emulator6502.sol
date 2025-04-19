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

    /// @notice Executes one instruction (currently only implements LDA #imm)
    function step() external {
        uint8 opcode = _fetch8();

        if (opcode == 0xA9) {
            _opLDAImmediate();
        } else if (opcode == 0xA5) {
            _opLDAZeroPage();
        } else if (opcode == 0xB5) {
            _opLDAZeroPageX();
        } else if (opcode == 0xAD) {
            _opLDAAbsolute();
        } else if (opcode == 0xBD) {
            _opLDAAbsoluteX();
        } else if (opcode == 0xB9) {
            _opLDAAbsoluteY();
        } else if (opcode == 0xA1) {
            _opLDAIndexedIndirect();
        } else if (opcode == 0xB1) {
            _opLDAIndirectIndexed();
        } else {
            revert("OpcodeNotImplemented");
        }
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

    // --- LDA helpers ---

    function _lda(uint8 value) internal {
        cpu.A = value;
        _updateZN(value);
    }

    function _opLDAImmediate() internal {
        _lda(_fetch8());
    }

    function _opLDAZeroPage() internal {
        uint8 addr = _fetch8();
        _lda(_read8(uint16(addr)));
    }

    function _opLDAZeroPageX() internal {
        uint8 base = _fetch8();
        unchecked { base += cpu.X; }
        _lda(_read8(uint16(base)));
    }

    function _opLDAAbsolute() internal {
        uint16 addr = _fetch16();
        _lda(_read8(addr));
    }

    function _opLDAAbsoluteX() internal {
        uint16 base = _fetch16();
        uint16 addr = base + cpu.X;
        _lda(_read8(addr));
    }

    function _opLDAAbsoluteY() internal {
        uint16 base = _fetch16();
        uint16 addr = base + cpu.Y;
        _lda(_read8(addr));
    }

    function _opLDAIndexedIndirect() internal {
        uint8 ptr = _fetch8();
        unchecked { ptr += cpu.X; }
        uint8 lo = _read8(uint16(ptr));
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 addr = uint16(lo) | (uint16(hi) << 8);
        _lda(_read8(addr));
    }

    function _opLDAIndirectIndexed() internal {
        uint8 ptr = _fetch8();
        uint8 lo = _read8(uint16(ptr));
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 base = uint16(lo) | (uint16(hi) << 8);
        uint16 addr = base + cpu.Y;
        _lda(_read8(addr));
    }

    function _updateZN(uint8 value) internal {
        // Zero flag
        _setFlag(FLAG_ZERO, value == 0);
        // Negative flag mirrors bit 7
        _setFlag(FLAG_NEGATIVE, (value & 0x80) != 0);
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

    // Direct register setters (testing only)
    function testSetPC(uint16 newPC) external {
        cpu.PC = newPC;
    }

    function testSetX(uint8 newX) external {
        cpu.X = newX;
    }

    function testSetY(uint8 newY) external {
        cpu.Y = newY;
    }

    /*//////////////////////////////////////////////////////////////////////////
                          FETCH & ADDRESSING HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Fetch next byte at PC and increment PC
    function _fetch8() internal returns (uint8 val) {
        val = _read8(cpu.PC);
        unchecked { cpu.PC += 1; }
    }

    /// @dev Fetch next two bytes little‑endian and increment PC by 2
    function _fetch16() internal returns (uint16 val) {
        uint8 lo = _fetch8();
        uint8 hi = _fetch8();
        val = uint16(lo) | (uint16(hi) << 8);
    }

    /// @notice Immediate addressing – returns address of literal byte (current PC prior fetch)
    function addrImmediate() external returns (uint16 addr) {
        addr = cpu.PC;
        _fetch8();
    }

    /// @notice Zero‑page addressing
    function addrZeroPage() external returns (uint16 addr) {
        addr = uint16(_fetch8());
    }

    /// @notice Zero‑page,X addressing
    function addrZeroPageX() external returns (uint16 addr) {
        uint8 base = _fetch8();
        unchecked { base += cpu.X; }
        addr = uint16(base);
    }

    /// @notice Absolute addressing
    function addrAbsolute() external returns (uint16 addr) {
        addr = _fetch16();
    }

    /// @notice Absolute,X addressing – returns addr and whether page was crossed
    function addrAbsoluteX() external returns (uint16 addr, bool pageCrossed) {
        uint16 base = _fetch16();
        addr = base + cpu.X;
        pageCrossed = (base & 0xff00) != (addr & 0xff00);
    }

    /// @notice Absolute,Y addressing
    function addrAbsoluteY() external returns (uint16 addr, bool pageCrossed) {
        uint16 base = _fetch16();
        addr = base + cpu.Y;
        pageCrossed = (base & 0xff00) != (addr & 0xff00);
    }

    /// @notice Indexed Indirect (zp,X)
    function addrIndexedIndirect() external returns (uint16 addr) {
        uint8 ptr = _fetch8();
        uint8 lo = _read8(uint16(ptr));
        uint8 hi;
        unchecked { hi = _read8(uint16(uint8(ptr + 1))); }
        addr = uint16(lo) | (uint16(hi) << 8);
    }

    /// @notice Indirect Indexed (zp),Y
    function addrIndirectIndexed() external returns (uint16 addr, bool pageCrossed) {
        uint8 ptr = _fetch8();
        uint8 lo = _read8(uint16(ptr));
        uint8 hi;
        unchecked { hi = _read8(uint16(uint8(ptr + 1))); }
        uint16 base = uint16(lo) | (uint16(hi) << 8);
        addr = base + cpu.Y;
        pageCrossed = (base & 0xff00) != (addr & 0xff00);
    }
} 