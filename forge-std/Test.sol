// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

// Minimal self‑contained stub so static analysis finds the import path.
// When running with Foundry the real forge‑std implementation is still
// available via remappings; shadowing this file is fine because only a
// handful of helpers are used by our tests.

pragma solidity ^0.8.20;

interface Vm {
    struct Log {
        bytes32[] topics;
        bytes data;
    }

    function recordLogs() external;
    function getRecordedLogs() external view returns (Log[] memory);

    function log_named_uint(string memory key, uint256 val) external;
    function log_string(string memory) external;

    function assertTrue(bool condition, string memory message) external pure;
}

abstract contract Test {
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool cond) internal pure {
        require(cond, "assertTrue failed");
    }

    function assertTrue(bool cond, string memory msg_) internal pure {
        require(cond, msg_);
    }

    function assertEq(uint256 a, uint256 b, string memory msg_) internal pure {
        require(a == b, msg_);
    }

    function assertEq(string memory a, string memory b, string memory msg_) internal pure {
        require(keccak256(bytes(a)) == keccak256(bytes(b)), msg_);
    }
}

// Global events that Foundry tests expect for console‑style output.
event log_named_uint(string key, uint256 val);
event log_string(string val); 