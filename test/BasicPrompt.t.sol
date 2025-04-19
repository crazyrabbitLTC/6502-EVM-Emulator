// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

/// @title BasicPromptTest – placeholder to be filled once real BASIC ROM is embedded
contract BasicPromptTest is Test {
    function testSkipUntilRealRom() public {
        vm.skip(true, "Real BASIC ROM not yet embedded - enable once hex pasted");
    }
} 