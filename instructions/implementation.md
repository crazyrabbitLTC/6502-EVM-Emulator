Below is a high‑level, yet concrete, implementation roadmap that takes you from a blank contract to an on‑chain 6502 capable of running BASIC programs.  
At each stage I call out (1) scope, (2) key assumptions, (3) deliverables, (4) recommended tests, and (5) branch / CI hygiene so the work fits cleanly with your house rules.

------------------------------------------------
PHASE 0 – Foundation & Project‑level Plumbing
------------------------------------------------
1. Create a new feature branch `feat/6502-core‑scaffolding`.
2. Add `forge‑std` test helpers and a basic Foundry project layout (`src/`, `test/`, `script/`).
3. Enforce linting (`solhint`, `slither‑json`) via `pre‑commit` or CI.  
4. Add a minimal `Emulator6502.sol` shell that merely stores registers and exposes a `step()` stub.
5. Write a smoke test `test/EmulatorInit.t.sol` that:
   • deploys the contract  
   • asserts all registers & flags power‑on values (per §5 of instructions).

------------------------------------------------
PHASE 1 – Core Data Structures
------------------------------------------------
Scope  
• Registers: A, X, Y, SP, PC, P (flags).  
• Memory array: fixed `bytes` of size 64 K.  
• Helpers to get/set flags.

Assumptions  
• Store memory in a `bytes` array inside the contract; later we may map it to storage pages for gas efficiency.  
• Contract can be initialised with a `bytes` ROM image.

Deliverables  
• `struct CPU` holding the 6 registers + cycle counter.  
• `mapping(uint16 => uint8) mem;` or `bytes memory mem` plus helpers `read8`, `write8`.

Tests  
• `test/RegisterAccess.t.sol` – unit tests for flag helpers (set/clear/toggle/serialize).  
• `test/Memory.t.sol` – reads & writes, zero‑page and stack page boundaries.

------------------------------------------------
PHASE 2 – Addressing‑mode Helpers
------------------------------------------------
Scope  
Implement 13 NMOS addressing modes (§3).

Deliverables  
• Pure/constant internal functions that, given `CPU` & `bytes mem`, compute the effective address plus flags about page‑cross penalties.

Tests  
• Table‑driven test `test/AddressingModes.t.sol` using vectors from real 6502 docs.  
• Cross‑check page‑cross cycle penalty flag.

------------------------------------------------
PHASE 3 – Opcode Table & Dispatcher
------------------------------------------------
Scope  
• A `struct OpInfo { function(CPU storage, bytes storage) internal returns (uint cycles) handler; uint8 bytes; uint8 baseCycles; bool pagePenalty; }`.  
• Populate a 256‑entry constant array at deployment.

Assumptions  
• Illegal opcodes revert for v1.

Deliverables  
• `executeNext()` that:  
  1. fetches opcode at `PC`,  
  2. looks up `OpInfo`,  
  3. calls handler,  
  4. updates cycle counter.

Tests  
• `test/OpcodeMatrix.t.sol` that loops all 256 entries and ensures non‑implemented opcodes revert with an `IllegalOpcode()` error.

------------------------------------------------
PHASE 4 – ALU & Flag Logic
------------------------------------------------
Scope  
ADC, SBC, AND, ORA, EOR, CMP, CPX, CPY, BIT + shifts/rotates.  
Decimal mode optional but recommended (see §6 caveats).

Deliverables  
• Internal pure functions `adc`, `sbc` etc. returning result + updated flags.  
• Unit opcode handlers that glue addressing‑mode helpers with ALU helpers.

Tests  
• Property‑based tests for ADC/SBC overflow & carry.  
• Exhaustive tables for BIT, CMP etc.  
• Decimal mode golden vectors from real hardware trace.

------------------------------------------------
PHASE 5 – Control‑flow & Stack Ops
------------------------------------------------
Scope  
JSR, RTS, BRK, RTI, all branches, PHA/PLA/PHP/PLP, TXS/TSX.

Assumptions  
• Stack page is `$0100–$01FF` with post‑decrement semantics (see §7).

Deliverables  
• Helpers `push8`, `push16`, `pop8`, `pop16` that manipulate `SP` and `mem`.  
• Complete implementation of control‑flow opcodes.

Tests  
• `test/StackOps.t.sol` – push/pop round‑trips, RTS returning to correct `PC+1`.  
• Branch tests that cover page‑cross penalties.

Sub‑phases (incremental PR plan)  
• 5.0 Stack byte helpers – implement `_push8`, `_pop8`; unit test push/pop round‑trip.  
• 5.1 16‑bit helpers – `_push16`, `_pop16`; test 16‑bit round‑trip.  
• 5.2 Accumulator stack ops – opcodes PHA (0x48), PLA (0x68) with flag updates and tests.  
• 5.3 Processor status ops – PHP (0x08), PLP (0x28). Ensure B and unused bits handling; tests.  
• 5.4 Stack‑pointer transfer – TXS (0x9A) and TSX (0xBA); tests for Z/N flags.  
• 5.5 Sub‑routine flow – JSR (0x20) and RTS (0x60); tests that verify return address.  
• 5.6 Relative branch helper – finalize `addrRelative` and `_branch` function.  
• 5.7 Branch opcodes – implement BPL, BMI, BVC, BVS, BCC, BCS, BEQ, BNE with tests for taken/untaken and page‑crossing.

Each sub‑phase should compile and pass its new tests before proceeding to the next.

------------------------------------------------
PHASE 6 – Interrupt Controller
------------------------------------------------
Scope  
RESET, IRQ, NMI logic; vector fetch; BRK behaviour with B flag.

Deliverables  
• `triggerIRQ()` and `triggerNMI()` external calls.  
• Internal `_serviceInterrupt(vectorAddr, setBFlag)`.

Tests  
• `test/Interrupts.t.sol` – simulate BRK, IRQ, NMI and assert pushed stack bytes & `PC` after handler jump.

------------------------------------------------
PHASE 7 – Cycle‑Counting & Timing Accuracy (optional v1)
------------------------------------------------
If you need cycle‑exact behaviour (for raster demos etc.), wire page‑cross flags and branch penalties into `CPU.cycles`.  
Test with known instruction traces.

------------------------------------------------
PHASE 8 – BASIC ROM Integration (updated)
------------------------------------------------
Scope
•  Treat the BASIC ROM as a separate immutable "cartridge" contract (`BasicRom.sol`), whose bytecode is the raw ROM image.
•  Extend the emulator with `loadRomFrom(address rom, uint16 baseAddr)` that uses `extcodecopy` to copy the cartridge bytes into RAM.
•  Map simple UART‑style IO: `$F000` CPU read = keyboard buffer, `$F001` CPU write = emits `CharOut(uint8)`.
•  Provide external `sendKeys(bytes ascii)` to queue keystrokes.
•  Add `boot()` and gas‑capped `run(uint64 maxSteps)` execution loop.

Sub‑phases
8.0  ROM contract + `loadRomFrom` helper & Foundry script to deploy + load.
8.1  Memory‑mapped IO overrides in `_read8` / `_write8` and `CharOut` event.
8.2  Keystroke ring‑buffer + `sendKeys` + `boot()` wiring.
8.3  `run()` instruction loop with BRK/step‑budget halt.
8.4  End‑to‑end test that loads TinyBASIC, types `PRINT 2+2` (newline) and asserts `CharOut` contains `"4"`.

Assumptions
•  TinyBASIC (~4–8 KiB) fits comfortably in contract bytecode and RAM.
•  Exact cycle accuracy not required; functional correctness only.
•  USART addresses chosen above may be tweaked to match ROM expectations.

Deliverables
•  `BasicRom.sol` (immutable library/contract).
•  Updated `Emulator6502.sol` with ROM loading & IO hooks.
•  Script `script/LoadRom.s.sol`.
•  Tests `test/BasicIntegration.t.sol`.

------------------------------------------------
PHASE 9 – High‑level BASIC Program Runner
------------------------------------------------
Scope  
• Convenience function `run(bytes program)` that:  
  – resets CPU,  
  – pastes BASIC program into RAM buffer,  
  – triggers `SYS` token (if ROM requires),  
  – executes until `BRK` or cycle budget reached.

Deliverables  
• Gas‑metered loop with safety break after N cycles to avoid DoS.  
• Event `ProgramHalted(uint cyclesUsed)`.

Tests  
• Multiple sample BASIC listings (loops, branching, string ops).  
• Gas profiling to ensure per‑instruction cost is bounded.

------------------------------------------------
Branch & CI Workflow (applies to every phase)
------------------------------------------------
1. Start a short‑lived feature branch per phase (`feat/6502‑phase‑N`).  
2. After lint + build + tests pass locally:  
   – `git add . && git commit -m "Phase N: …"`  
   – Open PR → get review (remember: ask reviewer to keep us focused).  
3. Merge **into the parent integration branch, never main**.  
4. Delete feature branch.

------------------------------------------------
Future Nice‑to‑Haves
------------------------------------------------
• CMOS 65C02 opcodes (§8).  
• Cycle‑exact bus timing (Appendix A) for peripheral emulation.  
• Verifier contract to replay traces off‑chain for cheaper on‑chain verification.

This roadmap should let us grow functionality incrementally, keep tests fast, and respect your branching/linting conventions. 