// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Emulator6502.sol";

contract InterruptsTest is Test {
    Emulator6502 emu;

    // Helper to decode CPU struct
    function _cpu() internal view returns (
        uint8 A,
        uint8 X,
        uint8 Y,
        uint8 SP,
        uint16 PC,
        uint8 P,
        uint64 cycles
    ) {
        return emu.cpu();
    }

    function setUp() public {
        emu = new Emulator6502();

        // Set reset vector to 0x8000 for convenience (little‑endian)
        emu.poke8(0xFFFC, 0x00);
        emu.poke8(0xFFFD, 0x80);
        // Manually place PC there for tests (constructor already fetched 0 earlier)
        emu.testSetPC(0x8000);
    }

    function testBRKAndRTIFlow() public {
        // IRQ/BRK vector -> 0x9000
        emu.poke8(0xFFFE, 0x00);
        emu.poke8(0xFFFF, 0x90);

        // Instruction bytes
        emu.poke8(0x8000, 0x00); // BRK
        emu.poke8(0x9000, 0x40); // RTI at ISR start

        // Step BRK
        emu.step();

        // After BRK, PC should be 0x9000, SP = 0xFA
        (, , , uint8 spAfterBRK, uint16 pcAfterBRK, uint8 pAfterBRK,) = _cpu();
        assertEq(pcAfterBRK, 0x9000, "PC not loaded from IRQ vector");
        assertEq(spAfterBRK, 0xFA, "SP decrement incorrect after BRK push");
        // Stack checks
        assertEq(emu.peek8(0x01FD), 0x80, "High byte incorrect");
        assertEq(emu.peek8(0x01FC), 0x02, "Low byte incorrect");
        assertEq(emu.peek8(0x01FB), 0x34, "Status byte incorrect");

        // Step RTI
        emu.step();
        (, , , uint8 spAfterRTI, uint16 pcAfterRTI, uint8 pAfterRTI,) = _cpu();
        assertEq(spAfterRTI, 0xFD, "SP not restored by RTI");
        assertEq(pcAfterRTI, 0x8002, "PC not restored by RTI");
        assertEq(pAfterRTI, 0x24, "Processor status restore incorrect");
    }

    function testIRQServicedWhenEnabled() public {
        // Clear I flag so IRQs are allowed
        emu.testSetFlag(2, false);
        // Set IRQ vector
        emu.poke8(0xFFFE, 0x00);
        emu.poke8(0xFFFF, 0x90);
        // Place RTI
        emu.poke8(0x9000, 0x40);
        // trigger
        emu.triggerIRQ();
        // Step once -> should service IRQ then execute RTI
        emu.step();
        (, , , uint8 spAfter, uint16 pcAfter,,) = _cpu();
        assertEq(pcAfter, 0x8000, "RTI should return to original PC");
        assertEq(spAfter, 0xFD, "Stack pointer should be restored");
    }

    function testNMIOverridesIRQ() public {
        // Clear I flag to allow IRQ, but NMI should still override even if set
        emu.testSetFlag(2, false);
        // Set vectors
        emu.poke8(0xFFFE, 0x00); emu.poke8(0xFFFF, 0x90); // IRQ -> 0x9000
        emu.poke8(0xFFFA, 0x00); emu.poke8(0xFFFB, 0x91); // NMI -> 0x9100
        emu.poke8(0x9000, 0x40); // RTI at 0x9000
        emu.poke8(0x9100, 0x40); // RTI at 0x9100

        emu.triggerIRQ();
        emu.triggerNMI();
        emu.step();
        (, , , uint8 spAfter, uint16 pcAfter,,) = _cpu();
        // After servicing NMI and executing RTI, PC should return to original 0x8000
        assertEq(pcAfter, 0x8000, "NMI RTI should return to original PC");
        assertEq(spAfter, 0xFD, "Stack pointer restore after NMI");
    }

    function testIRQMasksWhenIFlagSet() public {
        // Ensure I flag is set (default after reset), IRQ should be ignored
        // Set IRQ vector
        emu.poke8(0xFFFE, 0x00);
        emu.poke8(0xFFFF, 0x90);

        // Program at 0x8000: LDA #$01 (0xA9 0x01)
        emu.poke8(0x8000, 0xA9);
        emu.poke8(0x8001, 0x01);

        // Trigger IRQ while I flag set
        emu.triggerIRQ();

        // Step executes LDA, IRQ should not be serviced
        emu.step();

        (, , , uint8 spAfter, uint16 pcAfter,,) = _cpu();
        assertEq(pcAfter, 0x8002, "PC should advance normally when IRQ masked");
        assertEq(spAfter, 0xFD, "Stack pointer unchanged when IRQ masked");
    }
} 