#!/usr/bin/env python3
"""Generate `src/BasicRom.sol` from the two EhBASIC ROM hex dumps.

This script:
1. Reads `rom/eh_hex_part1.txt` and `rom/eh_hex_part2.txt`.
2. Strips whitespace/newlines and validates each part is exactly 16,384 hex characters (8 KiB).
3. Concatenates the parts (total 32,768 hex characters → 16 KiB).
4. Emits `src/BasicRom.sol` with the ROM embedded as a series of concatenated `hex"…"` literals, each 512 bytes (1,024 hex chars) long for compiler friendliness.
5. The contract constructor loads the ROM into memory and immediately returns it, so the deployed bytecode *is* the ROM image.

Run this script whenever the ROM dumps change (they never should).
"""

from __future__ import annotations

import textwrap
from pathlib import Path

PART_FILES = [Path("rom/eh_hex_part1.txt"), Path("rom/eh_hex_part2.txt")]
OUTPUT_SOL = Path("src/BasicRom.sol")
CHUNK_HEX_LEN = 1024  # 512 bytes per literal


def read_and_validate(path: Path) -> str:
    data = path.read_text().strip().replace("\n", "")
    if len(data) != 16_384:
        raise ValueError(f"{path} is {len(data)} chars, expected 16384")
    # quick sanity: must be even length and valid hex
    if len(data) % 2 or any(c not in "0123456789abcdefABCDEF" for c in data):
        raise ValueError(f"{path} contains invalid hex")
    return data.lower()


def main() -> None:
    parts = [read_and_validate(p) for p in PART_FILES]
    combined = "".join(parts)

    if len(combined) != 32_768:
        raise AssertionError("Combined ROM hex should be 32768 chars (16 KiB)")

    # Split into fixed‑size chunks for readability & compiler limits.
    chunks = textwrap.wrap(combined, CHUNK_HEX_LEN)
    # Build Solidity hex literal series.
    hex_literals = " ".join(f'hex"{chunk}"' for chunk in chunks)

    sol_source = f"""// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title BasicRom — EhBASIC v2.22 ROM (16 KiB)
/// @notice Deployed bytecode *is* the ROM image. Auto‑generated — DO NOT EDIT MANUALLY.
///          Regenerate with `python scripts/build_basic_rom.py` if needed.
contract BasicRom {{
    constructor() {{
        bytes memory rom = {hex_literals};
        assembly {{
            return(add(rom, 0x20), mload(rom))
        }}
    }}
}}
"""

    OUTPUT_SOL.write_text(sol_source)
    print(f"Generated {{OUTPUT_SOL}} ({{len(combined) // 2}} bytes)")


if __name__ == "__main__":
    main() 