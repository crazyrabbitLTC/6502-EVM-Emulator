// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Emulator6502.sol";

library OpcodeTable {
    struct OpInfo {
        function(Emulator6502) internal handler;
        uint8 length;      // bytes in instruction (for future use)
    }

    // Forward declaration of unimplemented handler so we can reference it in TABLE constant
    function unimplemented(Emulator6502) internal pure {
        revert("OpcodeNotImplemented");
    }

    /// @notice Returns a dummy OpInfo that always reverts – placeholder until table implemented
    function info(uint8 /*opcode*/) internal pure returns (OpInfo memory) {
        return OpInfo({handler: unimplemented, length: 0});
    }
} 