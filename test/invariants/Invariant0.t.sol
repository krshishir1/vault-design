// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, StdInvariant, console} from "forge-std/Test.sol";

contract ExampleContract1 {
    uint256 public val1;
    uint256 public val2;
    uint256 public val3;

    function addToA(uint256 amount) external {
        val1 += amount;
        val3 += amount;
    }

    function addToB(uint256 amount) external {
        val2 += amount;
        val3 += amount;
    }
}

contract InvariantExample1 is StdInvariant, Test {
    ExampleContract1 foo;

    function setUp() external {
        foo = new ExampleContract1();

        // bytes4[] memory excluded = new bytes4[](1);
        // excluded[0] = foo.addToB.selector;

        // excludeSelector(
        //     FuzzSelector({addr: address(foo), selectors: excluded})
        // );

        // excludeContract(address(foo));
    }

    function invariant_A() external view {
        assertEq(foo.val1() + foo.val2(), foo.val3());
    }

    function invariant_B() external view {
        assertGe(foo.val1() + foo.val2(), foo.val3());
    }
}
