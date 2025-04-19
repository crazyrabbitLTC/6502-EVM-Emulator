# MOS 6502 Emulator Reference ( distilled from Syntertek SY6500 / SY65C02 data‑sheet )

*Everything in this file comes from the user‑supplied PDF unless otherwise stated.*  citeturn0file0  
Use it verbatim as system‑or model‑prompt context when asking an LLM to implement a 6502 core.

---

## 1  Programming Model

| Register | Size | Purpose |
|----------|------|---------|
| **A** (Accumulator) | 8‑bit | ALU source/target for arithmetic & logic |
| **X** | 8‑bit | Index #1, loop counter, memory offset |
| **Y** | 8‑bit | Index #2 |
| **SP** (Stack Pointer) | 8‑bit | Post‑decrement push / pre‑increment pull; stack page **$0100–$01FF** |
| **PC** (Program Counter) | 16‑bit | Instruction fetch pointer |
| **P** (Status) | 8‑bit | *NV‑B D I Z C* – see below |

### Status‑flag bit positions
|7|6|5|4|3|2|1|0|
|--|--|--|--|--|--|--|--|
|N|V|–|B|D|I|Z|C|
* **N** Negative, **V** Overflow, **B** BRK/IRQ marker, **D** BCD mode, **I** IRQ disable, **Z** Zero, **C** Carry*

---

## 2  Memory Map & Vectors

* Total address space: **64 KiB** (16‑bit bus).
* **Zero‑page** $0000–00FF: supports single‑byte addressing.
* **Stack page** $0100–01FF.

| Address | Vector | Description |
|---------|--------|-------------|
| **$FFFA/FFFB** | NMI | Non‑maskable interrupt (low‑byte, high‑byte) |
| **$FFFC/FFFD** | RESET | Power‑on / reset vector |
| **$FFFE/FFFF** | IRQ/BRK | Maskable IRQ & BRK instruction |

Push order during interrupt/BRK: **PC‑hi, PC‑lo, P** (with B flag as noted below).

---

## 3  Addressing Modes (NMOS 6502 – 13 modes)

| Mode | Suffix | Example | Base cycles | Extra cycle notes |
|------|--------|---------|-------------|-------------------|
| Implied | – | CLC | 2 | – |
| Accumulator | A | ASL A | 2 | – |
| Immediate | # | LDA #$42 | 2 | – |
| Zero Page | zp | LDA $44 | 3 | – |
| Zero Page,X | zp,X | LDA $44,X | 4 | – |
| Indexed Indirect | (zp,X) | LDA ($20,X) | 6 | – |
| Indirect Indexed | (zp),Y | LDA ($20),Y | 5 | +1 cycle if page crossed |
| Absolute | abs | LDA $1234 | 4 | – |
| Absolute,X | abs,X | LDA $2000,X | 4 | +1 if page crossed |
| Absolute,Y | abs,Y | LDA $2000,Y | 4 | +1 if page crossed |
| Indirect (JMP only) | (abs) | JMP ($3000) | 5 | Page‑wrap bug on low‑byte overflow |
| Relative | rel | BEQ label | 2 | +1 if branch taken, +1 if branch crosses page |
| Implicit Stack | – | JSR/RTS/RTI/PHA… | see tables | varies |

Detailed per‑cycle bus sequences are listed in **Appendix A, pp 26‑37** and can be used for cycle‑exact emulation. citeturn0file0

---

## 4  Instruction Set Summary

* **56 legal opcodes**; each combines with a subset of addressing modes → **151 distinct instruction forms**.
* Complete opcode matrix with cycles and bytes is on **page 9**.
* Groups:
  * **Load/Store:** LDA, LDX, LDY, STA, STX, STY
  * **ALU:** ADC, SBC, AND, ORA, EOR, CMP, CPX, CPY, BIT
  * **Shift/Rotate:** ASL, LSR, ROL, ROR
  * **Branch:** BMI, BPL, BEQ, BNE, BCS, BCC, BVS, BVC
  * **Register moves:** TAX, TAY, TXA, TYA, TSX, TXS
  * **Stack:** PHA, PLA, PHP, PLP
  * **System:** JSR, RTS, JMP, BRK, RTI, NOP

> **Page‑cross penalty:** if an Absolute,X / Absolute,Y / (zp),Y access crosses a 256‑byte page boundary, add **1 extra cycle**. Branches that cross a page also add **1 extra cycle** after the branch‑taken penalty.

---

## 5  Interrupt & Reset Behaviour

| Event | Sequence |
|-------|----------|
| **RESET** | 1️⃣ Set `I=1`, 2️⃣ SP ← $FD, 3️⃣ read vector $FFFC/FFFD into PC |
| **NMI** | Push *PC‑hi*, *PC‑lo*, *P* (B=0), set `I`, fetch vector $FFFA/FFFB |
| **IRQ/BRK** | Same as NMI but vector $FFFE/FFFF`. **BRK** sets B=1 before push. |

On BRK/IRQ the pushed P has **bit 5 = 1** (unused) and **bit 4 = 1** (B flag). On NMI the B flag is cleared.

---

## 6  Decimal (BCD) Mode Caveats

* `D` flag enables BCD adjustment for **ADC** & **SBC** only.
* **V flag** after decimal SBC follows binary rules (counter‑intuitive but documented on p 19‑21).
* Some early masks have undefined behaviour if `D=1` during interrupts—safe emulators leave `D` unchanged except on RESET (where it is cleared).

---

## 7  Stack Details

* Address range: **$0100–$01FF** (256 bytes).
* `SP` holds **offset**; push: `WRITE $0100+SP`, then `SP–‐‑‑`; pull: `SP++`, then `READ $0100+SP`.
* On **JSR**: push **PC‑hi**, **PC‑lo‑1**, then load target address. (Therefore RTS must add 1.)

---

## 8  CMOS 65C02 Additions (optional)

Located on **pages 14‑24**.
* Decoded all 256 opcodes, eliminating “illegal” gaps.
* New instructions: `BRA` (relative branch), `PHX/PHY`, `PLX/PLY`, `STZ`, `TRB/TSB`, `BBS/BBR`, etc.
* Hardware changes: `RMW` instructions no longer perform a dummy read.

If targeting **NMOS 6502 only**, you may ignore this section.

---

## 9  Cycle‑Accurate Bus Timing (advanced)

Appendix A provides per‑instruction bus traces (`T0…Tn`) including address‑bus source and data‑bus R/W flags.  
Example (*single‑byte* `ASL A`, p 26):
```
T0  PC   ⇒ address bus   | Fetch OP‑CODE
T1  PC+1 ⇒ address bus   | (discarded)
T2  --- (internal)       | Execute & finish
```
Use these tables to drive callbacks for memory‑mapped peripherals (video scanlines, DMA stealing, etc.).

---

## 10  Quick Implementation Checklist

1. **Opcode table (256 entries)** – name, bytes, baseCycles, addrMode, pageCrossPenalty?  
   → scrape from page 9.
2. **Addressing‑mode helpers** implementing read/write semantics above.
3. **ALU & flag update helpers** (ADC/SBC share carry/overflow rules).  
   Decimal adjust tables optional.
4. **Interrupt controller** obeying push order & vector fetch.
5. **Stack helpers** as per §7.
6. Optional: decimal mode, undocumented opcodes, 65C02 extensions.

---

### Citations
All bullet‑point facts come directly from *Syntertek SY6500/SY65C02 data‑sheet* (37 pp). citeturn0file0

