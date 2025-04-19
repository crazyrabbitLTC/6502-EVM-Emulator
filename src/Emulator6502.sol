// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./OpcodeTable.sol";

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
                                   INTERRUPT VECTORS
    //////////////////////////////////////////////////////////////////////////*/

    uint16 private constant VECTOR_NMI   = 0xFFFA;
    uint16 private constant VECTOR_RESET = 0xFFFC;
    uint16 private constant VECTOR_IRQ   = 0xFFFE;

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
        _legacyDispatch(opcode);
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

    // --- ADC helpers ---

    function _adc(uint8 value) internal {
        uint8 a = cpu.A;
        uint8 carryIn = _getFlag(FLAG_CARRY) ? 1 : 0;
        uint16 sum = uint16(a) + uint16(value) + uint16(carryIn);
        uint8 result = uint8(sum);

        // Carry flag
        _setFlag(FLAG_CARRY, sum > 0xFF);
        // Overflow flag: set if (~(A ^ V) & (A ^ R)) bit 7 set
        bool overflow = ((~(a ^ value) & (a ^ result)) & 0x80) != 0;
        _setFlag(FLAG_OVERFLOW, overflow);

        cpu.A = result;
        _updateZN(result);
    }

    function _opADCImmediate() internal {
        _adc(_fetch8());
    }

    function _opADCZeroPage() internal {
        uint8 addr = _fetch8();
        _adc(_read8(uint16(addr)));
    }

    function _opADCZeroPageX() internal {
        uint8 base = _fetch8();
        unchecked { base += cpu.X; }
        _adc(_read8(uint16(base)));
    }

    function _opADCAbsolute() internal {
        uint16 addr = _fetch16();
        _adc(_read8(addr));
    }

    function _opADCAbsoluteX() internal {
        uint16 base = _fetch16();
        uint16 addr = base + cpu.X;
        _adc(_read8(addr));
    }

    function _opADCAbsoluteY() internal {
        uint16 base = _fetch16();
        uint16 addr = base + cpu.Y;
        _adc(_read8(addr));
    }

    function _opADCIndexedIndirect() internal {
        uint8 ptr = _fetch8();
        unchecked { ptr += cpu.X; }
        uint8 lo = _read8(uint16(ptr));
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 addr = uint16(lo) | (uint16(hi) << 8);
        _adc(_read8(addr));
    }

    function _opADCIndirectIndexed() internal {
        uint8 ptr = _fetch8();
        uint8 lo = _read8(uint16(ptr));
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 base = uint16(lo) | (uint16(hi) << 8);
        uint16 addr = base + cpu.Y;
        _adc(_read8(addr));
    }

    // --- SBC helpers (uses ADC with value ^ 0xFF) ---

    function _sbc(uint8 value) internal {
        _adc(value ^ 0xFF);
    }

    function _opSBCImmediate() internal {
        _sbc(_fetch8());
    }

    function _opSBCZeroPage() internal {
        uint8 addr = _fetch8();
        _sbc(_read8(uint16(addr)));
    }

    function _opSBCZeroPageX() internal {
        uint8 base = _fetch8();
        unchecked { base += cpu.X; }
        _sbc(_read8(uint16(base)));
    }

    function _opSBCAbsolute() internal {
        uint16 addr = _fetch16();
        _sbc(_read8(addr));
    }

    function _opSBCAbsoluteX() internal {
        uint16 base = _fetch16();
        uint16 addr = base + cpu.X;
        _sbc(_read8(addr));
    }

    function _opSBCAbsoluteY() internal {
        uint16 base = _fetch16();
        uint16 addr = base + cpu.Y;
        _sbc(_read8(addr));
    }

    function _opSBCIndexedIndirect() internal {
        uint8 ptr = _fetch8();
        unchecked { ptr += cpu.X; }
        uint8 lo = _read8(uint16(ptr));
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 addr = uint16(lo) | (uint16(hi) << 8);
        _sbc(_read8(addr));
    }

    function _opSBCIndirectIndexed() internal {
        uint8 ptr = _fetch8();
        uint8 lo = _read8(uint16(ptr));
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 base = uint16(lo) | (uint16(hi) << 8);
        uint16 addr = base + cpu.Y;
        _sbc(_read8(addr));
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

    function testSetA(uint8 newA) external {
        cpu.A = newA;
    }

    // Stack helper wrappers for tests
    function testPush8(uint8 val) external {
        _push8(val);
    }

    function testPop8() external returns (uint8) {
        return _pop8();
    }

    function testPush16(uint16 val) external {
        _push16(val);
    }

    function testPop16() external returns (uint16) {
        return _pop16();
    }

    function testSetSP(uint8 newSP) external {
        cpu.SP = newSP;
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
        uint8 hi = _read8(uint16(uint8(ptr + 1)));
        uint16 base = uint16(lo) | (uint16(hi) << 8);
        addr = base + cpu.Y;
        pageCrossed = (base & 0xff00) != (addr & 0xff00);
    }

    /// @notice Zero‑page,Y addressing
    function addrZeroPageY() external returns (uint16 addr) {
        uint8 base = _fetch8();
        unchecked { base += cpu.Y; }
        addr = uint16(base);
    }

    /// @notice Relative addressing – returns branch target and pageCross flag
    function addrRelative() external returns (uint16 target, bool pageCrossed) {
        int8 offset = int8(uint8(_fetch8()));
        uint16 pc = cpu.PC;
        int32 calc = int32(uint32(pc)) + int32(offset);
        target = uint16(uint32(calc) & 0xFFFF);
        pageCrossed = (pc & 0xFF00) != (target & 0xFF00);
    }

    /// @notice Absolute Indirect addressing (JMP ($addr)) with 6502 page bug
    function addrIndirect() external returns (uint16 addr) {
        uint16 ptr = _fetch16();
        uint16 loAddr = ptr;
        uint16 hiAddr = (ptr & 0xFF00) | uint16(uint8(ptr + 1));
        uint8 lo = _read8(loAddr);
        uint8 hi = _read8(hiAddr);
        addr = uint16(lo) | (uint16(hi) << 8);
    }

    // --- AND helpers ---

    function _and(uint8 value) internal {
        uint8 res = cpu.A & value;
        cpu.A = res;
        _updateZN(res);
    }

    function _opANDImmediate() internal { _and(_fetch8()); }
    function _opANDZeroPage() internal { _and(_read8(uint16(_fetch8()))); }
    function _opANDZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} _and(_read8(uint16(b))); }
    function _opANDAbsolute() internal { _and(_read8(_fetch16())); }
    function _opANDAbsoluteX() internal { uint16 base=_fetch16(); _and(_read8(base+cpu.X)); }
    function _opANDAbsoluteY() internal { uint16 base=_fetch16(); _and(_read8(base+cpu.Y)); }
    function _opANDIndexedIndirect() internal { uint8 p=_fetch8(); unchecked{p+=cpu.X;} uint16 addr=uint16(_read8(uint16(p)))| (uint16(_read8(uint16(uint8(p+1))))<<8); _and(_read8(addr)); }
    function _opANDIndirectIndexed() internal { uint8 p=_fetch8(); uint16 base=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _and(_read8(base+cpu.Y)); }

    // --- ORA helpers ---
    function _ora(uint8 value) internal { uint8 res = cpu.A | value; cpu.A = res; _updateZN(res);}    
    function _opORAImmediate() internal { _ora(_fetch8()); }
    function _opORAZeroPage() internal { _ora(_read8(uint16(_fetch8()))); }
    function _opORAZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} _ora(_read8(uint16(b))); }
    function _opORAAbsolute() internal { _ora(_read8(_fetch16())); }
    function _opORAAbsoluteX() internal { uint16 base=_fetch16(); _ora(_read8(base+cpu.X)); }
    function _opORAAbsoluteY() internal { uint16 base=_fetch16(); _ora(_read8(base+cpu.Y)); }
    function _opORAIndexedIndirect() internal { uint8 p=_fetch8(); unchecked{p+=cpu.X;} uint16 a=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _ora(_read8(a)); }
    function _opORAIndirectIndexed() internal { uint8 p=_fetch8(); uint16 base=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _ora(_read8(base+cpu.Y)); }

    // --- EOR helpers ---
    function _eor(uint8 value) internal { uint8 res = cpu.A ^ value; cpu.A = res; _updateZN(res);}    
    function _opEORImmediate() internal { _eor(_fetch8()); }
    function _opEORZeroPage() internal { _eor(_read8(uint16(_fetch8()))); }
    function _opEORZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} _eor(_read8(uint16(b))); }
    function _opEORAbsolute() internal { _eor(_read8(_fetch16())); }
    function _opEORAbsoluteX() internal { uint16 base=_fetch16(); _eor(_read8(base+cpu.X)); }
    function _opEORAbsoluteY() internal { uint16 base=_fetch16(); _eor(_read8(base+cpu.Y)); }
    function _opEORIndexedIndirect() internal { uint8 p=_fetch8(); unchecked{p+=cpu.X;} uint16 a=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _eor(_read8(a)); }
    function _opEORIndirectIndexed() internal { uint8 p=_fetch8(); uint16 base=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _eor(_read8(base+cpu.Y)); }

    // --- BIT helper --- (affects Z = A & val ==0, N,V from val bits 7/6)
    function _bit(uint8 val) internal {
        _setFlag(FLAG_ZERO, (cpu.A & val) == 0);
        _setFlag(FLAG_NEGATIVE, (val & 0x80)!=0);
        _setFlag(FLAG_OVERFLOW, (val & 0x40)!=0);
    }
    function _opBITZeroPage() internal { _bit(_read8(uint16(_fetch8()))); }
    function _opBITAbsolute() internal { _bit(_read8(_fetch16())); }

    // --- Compare helpers ---
    function _cmp(uint8 reg, uint8 value) internal {
        uint8 diff;
        unchecked { diff = reg - value; }
        _setFlag(FLAG_CARRY, reg >= value);
        _updateZN(diff);
    }

    // CMP (with A)
    function _opCMPImmediate() internal { _cmp(cpu.A, _fetch8()); }
    function _opCMPZeroPage() internal { _cmp(cpu.A, _read8(uint16(_fetch8()))); }
    function _opCMPZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} _cmp(cpu.A, _read8(uint16(b))); }
    function _opCMPAbsolute() internal { _cmp(cpu.A, _read8(_fetch16())); }
    function _opCMPAbsoluteX() internal { uint16 base=_fetch16(); _cmp(cpu.A, _read8(base+cpu.X)); }
    function _opCMPAbsoluteY() internal { uint16 base=_fetch16(); _cmp(cpu.A, _read8(base+cpu.Y)); }
    function _opCMPIndexedIndirect() internal { uint8 p=_fetch8(); unchecked{p+=cpu.X;} uint16 a=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _cmp(cpu.A, _read8(a)); }
    function _opCMPIndirectIndexed() internal { uint8 p=_fetch8(); uint16 base=uint16(_read8(uint16(p)))|(uint16(_read8(uint16(uint8(p+1))))<<8); _cmp(cpu.A, _read8(base+cpu.Y)); }

    // CPX
    function _opCPXImmediate() internal { _cmp(cpu.X, _fetch8()); }
    function _opCPXZeroPage() internal { _cmp(cpu.X, _read8(uint16(_fetch8()))); }
    function _opCPXAbsolute() internal { _cmp(cpu.X, _read8(_fetch16())); }

    // CPY
    function _opCPYImmediate() internal { _cmp(cpu.Y, _fetch8()); }
    function _opCPYZeroPage() internal { _cmp(cpu.Y, _read8(uint16(_fetch8()))); }
    function _opCPYAbsolute() internal { _cmp(cpu.Y, _read8(_fetch16())); }

    // --- Shift / Rotate helpers ---
    function _asl(uint8 value) internal returns (uint8 res) {
        _setFlag(FLAG_CARRY, (value & 0x80) != 0);
        res = value << 1;
        _updateZN(res);
    }

    function _lsr(uint8 value) internal returns (uint8 res) {
        _setFlag(FLAG_CARRY, (value & 0x01) != 0);
        res = value >> 1;
        _updateZN(res);
    }

    function _rol(uint8 value) internal returns (uint8 res) {
        uint8 carryIn = _getFlag(FLAG_CARRY) ? 1 : 0;
        _setFlag(FLAG_CARRY, (value & 0x80) != 0);
        res = (value << 1) | carryIn;
        _updateZN(res);
    }

    function _ror(uint8 value) internal returns (uint8 res) {
        uint8 carryIn = _getFlag(FLAG_CARRY) ? 0x80 : 0;
        _setFlag(FLAG_CARRY, (value & 0x01) != 0);
        res = (value >> 1) | carryIn;
        _updateZN(res);
    }

    // ASL
    function _opASLAccumulator() internal { cpu.A = _asl(cpu.A); }
    function _opASLZeroPage() internal { uint16 addr = uint16(_fetch8()); uint8 v=_read8(addr); uint8 r=_asl(v); _write8(addr,r);} 
    function _opASLZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} uint16 addr=uint16(b); uint8 v=_read8(addr); uint8 r=_asl(v); _write8(addr,r);} 
    function _opASLAbsolute() internal { uint16 addr = _fetch16(); uint8 v=_read8(addr); uint8 r=_asl(v); _write8(addr,r);} 
    function _opASLAbsoluteX() internal { uint16 base=_fetch16(); uint16 addr=base+cpu.X; uint8 v=_read8(addr); uint8 r=_asl(v); _write8(addr,r);} 

    // LSR
    function _opLSRAccumulator() internal { cpu.A = _lsr(cpu.A); }
    function _opLSRZeroPage() internal { uint16 addr=uint16(_fetch8()); uint8 v=_read8(addr); uint8 r=_lsr(v); _write8(addr,r);} 
    function _opLSRZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} uint16 addr=uint16(b); uint8 v=_read8(addr); uint8 r=_lsr(v); _write8(addr,r);} 
    function _opLSRAbsolute() internal { uint16 addr=_fetch16(); uint8 v=_read8(addr); uint8 r=_lsr(v); _write8(addr,r);} 
    function _opLSRAbsoluteX() internal { uint16 base=_fetch16(); uint16 addr=base+cpu.X; uint8 v=_read8(addr); uint8 r=_lsr(v); _write8(addr,r);} 

    // ROL
    function _opROLAccumulator() internal { cpu.A = _rol(cpu.A); }
    function _opROLZeroPage() internal { uint16 addr=uint16(_fetch8()); uint8 v=_read8(addr); uint8 r=_rol(v); _write8(addr,r);} 
    function _opROLZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} uint16 addr=uint16(b); uint8 v=_read8(addr); uint8 r=_rol(v); _write8(addr,r);} 
    function _opROLAbsolute() internal { uint16 addr=_fetch16(); uint8 v=_read8(addr); uint8 r=_rol(v); _write8(addr,r);} 
    function _opROLAbsoluteX() internal { uint16 base=_fetch16(); uint16 addr=base+cpu.X; uint8 v=_read8(addr); uint8 r=_rol(v); _write8(addr,r);} 

    // ROR
    function _opRORAccumulator() internal { cpu.A = _ror(cpu.A); }
    function _opRORZeroPage() internal { uint16 addr=uint16(_fetch8()); uint8 v=_read8(addr); uint8 r=_ror(v); _write8(addr,r);} 
    function _opRORZeroPageX() internal { uint8 b=_fetch8(); unchecked{b+=cpu.X;} uint16 addr=uint16(b); uint8 v=_read8(addr); uint8 r=_ror(v); _write8(addr,r);} 
    function _opRORAbsolute() internal { uint16 addr=_fetch16(); uint8 v=_read8(addr); uint8 r=_ror(v); _write8(addr,r);} 
    function _opRORAbsoluteX() internal { uint16 base=_fetch16(); uint16 addr=base+cpu.X; uint8 v=_read8(addr); uint8 r=_ror(v); _write8(addr,r);} 

    /// @dev Legacy if/else opcode dispatcher – will be removed once table is complete
    function _legacyDispatch(uint8 opcode) internal {
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
        } else if (opcode == 0x69) {
            _opADCImmediate();
        } else if (opcode == 0x65) {
            _opADCZeroPage();
        } else if (opcode == 0x75) {
            _opADCZeroPageX();
        } else if (opcode == 0x6D) {
            _opADCAbsolute();
        } else if (opcode == 0x7D) {
            _opADCAbsoluteX();
        } else if (opcode == 0x79) {
            _opADCAbsoluteY();
        } else if (opcode == 0x61) {
            _opADCIndexedIndirect();
        } else if (opcode == 0x71) {
            _opADCIndirectIndexed();
        } else if (opcode == 0xE9) {
            _opSBCImmediate();
        } else if (opcode == 0xE5) {
            _opSBCZeroPage();
        } else if (opcode == 0xF5) {
            _opSBCZeroPageX();
        } else if (opcode == 0xED) {
            _opSBCAbsolute();
        } else if (opcode == 0xFD) {
            _opSBCAbsoluteX();
        } else if (opcode == 0xF9) {
            _opSBCAbsoluteY();
        } else if (opcode == 0xE1) {
            _opSBCIndexedIndirect();
        } else if (opcode == 0xF1) {
            _opSBCIndirectIndexed();
        } else if (opcode == 0x29) {
            _opANDImmediate();
        } else if (opcode == 0x25) {
            _opANDZeroPage();
        } else if (opcode == 0x35) {
            _opANDZeroPageX();
        } else if (opcode == 0x2D) {
            _opANDAbsolute();
        } else if (opcode == 0x3D) {
            _opANDAbsoluteX();
        } else if (opcode == 0x39) {
            _opANDAbsoluteY();
        } else if (opcode == 0x21) {
            _opANDIndexedIndirect();
        } else if (opcode == 0x31) {
            _opANDIndirectIndexed();
        } else if (opcode == 0x09) {
            _opORAImmediate();
        } else if (opcode == 0x05) {
            _opORAZeroPage();
        } else if (opcode == 0x15) {
            _opORAZeroPageX();
        } else if (opcode == 0x0D) {
            _opORAAbsolute();
        } else if (opcode == 0x1D) {
            _opORAAbsoluteX();
        } else if (opcode == 0x19) {
            _opORAAbsoluteY();
        } else if (opcode == 0x01) {
            _opORAIndexedIndirect();
        } else if (opcode == 0x11) {
            _opORAIndirectIndexed();
        } else if (opcode == 0x49) {
            _opEORImmediate();
        } else if (opcode == 0x45) {
            _opEORZeroPage();
        } else if (opcode == 0x55) {
            _opEORZeroPageX();
        } else if (opcode == 0x4D) {
            _opEORAbsolute();
        } else if (opcode == 0x5D) {
            _opEORAbsoluteX();
        } else if (opcode == 0x59) {
            _opEORAbsoluteY();
        } else if (opcode == 0x41) {
            _opEORIndexedIndirect();
        } else if (opcode == 0x51) {
            _opEORIndirectIndexed();
        } else if (opcode == 0x24) {
            _opBITZeroPage();
        } else if (opcode == 0x2C) {
            _opBITAbsolute();
        } else if (opcode == 0x08) {
            _opPHP();
        } else if (opcode == 0x28) {
            _opPLP();
        } else if (opcode == 0x48) {
            _opPHA();
        } else if (opcode == 0x68) {
            _opPLA();
        } else if (opcode == 0x9A) {
            _opTXS();
        } else if (opcode == 0xBA) {
            _opTSX();
        } else if (opcode == 0xC9) {
            _opCMPImmediate();
        } else if (opcode == 0xC5) {
            _opCMPZeroPage();
        } else if (opcode == 0xD5) {
            _opCMPZeroPageX();
        } else if (opcode == 0xCD) {
            _opCMPAbsolute();
        } else if (opcode == 0xDD) {
            _opCMPAbsoluteX();
        } else if (opcode == 0xD9) {
            _opCMPAbsoluteY();
        } else if (opcode == 0xC1) {
            _opCMPIndexedIndirect();
        } else if (opcode == 0xD1) {
            _opCMPIndirectIndexed();
        } else if (opcode == 0xE0) {
            _opCPXImmediate();
        } else if (opcode == 0xE4) {
            _opCPXZeroPage();
        } else if (opcode == 0xEC) {
            _opCPXAbsolute();
        } else if (opcode == 0xC0) {
            _opCPYImmediate();
        } else if (opcode == 0xC4) {
            _opCPYZeroPage();
        } else if (opcode == 0xCC) {
            _opCPYAbsolute();
        } else if (opcode == 0x06) { _opASLZeroPage(); }
        else if (opcode == 0x16) { _opASLZeroPageX(); }
        else if (opcode == 0x0E) { _opASLAbsolute(); }
        else if (opcode == 0x1E) { _opASLAbsoluteX(); }
        else if (opcode == 0x0A) { _opASLAccumulator(); }
        else if (opcode == 0x46) { _opLSRZeroPage(); }
        else if (opcode == 0x56) { _opLSRZeroPageX(); }
        else if (opcode == 0x4E) { _opLSRAbsolute(); }
        else if (opcode == 0x5E) { _opLSRAbsoluteX(); }
        else if (opcode == 0x4A) { _opLSRAccumulator(); }
        else if (opcode == 0x26) { _opROLZeroPage(); }
        else if (opcode == 0x36) { _opROLZeroPageX(); }
        else if (opcode == 0x2E) { _opROLAbsolute(); }
        else if (opcode == 0x3E) { _opROLAbsoluteX(); }
        else if (opcode == 0x2A) { _opROLAccumulator(); }
        else if (opcode == 0x66) { _opRORZeroPage(); }
        else if (opcode == 0x76) { _opRORZeroPageX(); }
        else if (opcode == 0x6E) { _opRORAbsolute(); }
        else if (opcode == 0x7E) { _opRORAbsoluteX(); }
        else if (opcode == 0x6A) { _opRORAccumulator(); }
        else if (opcode == 0x20) { _opJSR(); }
        else if (opcode == 0x60) { _opRTS(); }
        else if (opcode == 0x90) { _opBCC(); }
        else if (opcode == 0xB0) { _opBCS(); }
        else if (opcode == 0xF0) { _opBEQ(); }
        else if (opcode == 0x30) { _opBMI(); }
        else if (opcode == 0xD0) { _opBNE(); }
        else if (opcode == 0x10) { _opBPL(); }
        else if (opcode == 0x50) { _opBVC(); }
        else if (opcode == 0x70) { _opBVS(); }
        else if (opcode == 0x00) { _opBRK(); }
        else {
            revert("OpcodeNotImplemented");
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  STACK OPS
    //////////////////////////////////////////////////////////////////////////*/

    function _push8(uint8 value) internal {
        _write8(0x0100 | uint16(cpu.SP), value);
        unchecked { cpu.SP -= 1; }
    }

    function _pop8() internal returns (uint8 value) {
        unchecked { cpu.SP += 1; }
        value = _read8(0x0100 | uint16(cpu.SP));
    }

    function _push16(uint16 value) internal {
        _push8(uint8(value >> 8));
        _push8(uint8(value));
    }

    function _pop16() internal returns (uint16 value) {
        uint8 lo = _pop8();
        uint8 hi = _pop8();
        value = uint16(lo) | (uint16(hi) << 8);
    }

    // --- Stack related opcodes ---
    function _opPHA() internal { _push8(cpu.A); }
    function _opPLA() internal { cpu.A = _pop8(); _updateZN(cpu.A); }
    function _opPHP() internal { _push8(cpu.P | 0x10); } // B flag set when pushed
    function _opPLP() internal { cpu.P = (_pop8() & 0xEF) | 0x20; }
    function _opTXS() internal { cpu.SP = cpu.X; }
    function _opTSX() internal { cpu.X = cpu.SP; _updateZN(cpu.X); }

    // --- Branch helper ---
    function _branch(bool condition) internal {
        int8 offset = int8(uint8(_fetch8()));
        uint16 pc = cpu.PC;
        uint16 target = uint16(uint32(int32(uint32(pc)) + int32(offset)) & 0xFFFF);
        if (condition) {
            cpu.PC = target;
        }
    }

    // Branch opcodes
    function _opBCC() internal { _branch(!_getFlag(FLAG_CARRY)); }
    function _opBCS() internal { _branch(_getFlag(FLAG_CARRY)); }
    function _opBEQ() internal { _branch(_getFlag(FLAG_ZERO)); }
    function _opBMI() internal { _branch(_getFlag(FLAG_NEGATIVE)); }
    function _opBNE() internal { _branch(!_getFlag(FLAG_ZERO)); }
    function _opBPL() internal { _branch(!_getFlag(FLAG_NEGATIVE)); }
    function _opBVC() internal { _branch(!_getFlag(FLAG_OVERFLOW)); }
    function _opBVS() internal { _branch(_getFlag(FLAG_OVERFLOW)); }

    // JSR / RTS
    function _opJSR() internal {
        uint16 addr = _fetch16();
        // push (PC-1) high then low (PC already points to next after operand)
        uint16 returnAddr = cpu.PC - 1;
        _push16(returnAddr);
        cpu.PC = addr;
    }

    function _opRTS() internal {
        uint16 addr = _pop16();
        cpu.PC = addr + 1;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  INTERRUPT HELPER
    //////////////////////////////////////////////////////////////////////////*/

    function _serviceInterrupt(uint16 vectorAddr, bool setBreakFlag) internal {
        // Push current PC onto the stack (high byte first, then low byte)
        uint16 pc = cpu.PC;
        _push8(uint8(pc >> 8));
        _push8(uint8(pc & 0xFF));

        // Prepare processor status byte to push
        uint8 status = cpu.P;
        // Bit 5 is always set when pushed to the stack
        status |= uint8(1 << FLAG_UNUSED);

        // Set or clear the Break flag (bit 4) according to the interrupt source
        if (setBreakFlag) {
            status |= uint8(1 << FLAG_BREAK);
        } else {
            status &= ~uint8(1 << FLAG_BREAK);
        }

        _push8(status);

        // Set Interrupt Disable flag to prevent nested IRQs
        _setFlag(FLAG_INTERRUPT, true);

        // Load new PC from the interrupt vector
        uint8 lo = _read8(vectorAddr);
        uint8 hi = _read8(vectorAddr + 1);
        cpu.PC = uint16(lo) | (uint16(hi) << 8);
    }

    // --- Interrupt opcodes ---
    function _opBRK() internal {
        // BRK is a 2‑byte instruction; consume the padding byte
        _fetch8();
        // Service interrupt using the IRQ/BRK vector with Break flag set
        _serviceInterrupt(VECTOR_IRQ, true);
    }
} 