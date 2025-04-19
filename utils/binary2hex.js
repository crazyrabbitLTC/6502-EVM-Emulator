#!/usr/bin/env node
/*
 * binary2hex.js – CLI helper to convert a raw binary into a Solidity‑ready
 *                 hex literal suitable for `bytes memory rom = hex"…";`.
 *
 * Usage:
 *   node utils/binary2hex.js path/to/rom.bin > rom_hex.txt
 *
 * The output will be a single line without 0x‑prefix or newlines.
 * You can then paste that into BasicRom.sol:
 *   bytes memory rom = hex"<PASTE_HERE>";
 *
 * NOTE: Solidity literal size limit is 24 KiB source characters. For larger
 * ROMs (>12 KiB) you may need to split across multiple hex"…" concatenations
 * or embed via assembly extcodecopy of an external contract (our current
 * approach).  TinyBASIC/EhBASIC images of 8–12 KiB fit fine.
 */

const fs = require('fs');

if (process.argv.length !== 3) {
  console.error('Usage: binary2hex.js <binary file>');
  process.exit(1);
}

const filePath = process.argv[2];

try {
  const data = fs.readFileSync(filePath);
  const hex = data.toString('hex');
  process.stdout.write(hex + '\n');
} catch (e) {
  console.error('Error:', e.message);
  process.exit(1);
} 