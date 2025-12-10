// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SimpleVault} from "../src/SimpleVault.sol";
import {MockERC20} from "../src/MockERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleVaultTest is Test {
    MockERC20 private asset;
    SimpleVault private vault;

    address private ALICE = vm.addr(1);
    address private BOB = vm.addr(2);

    function setUp() public {
        asset = new MockERC20("MyToken", "MTK");
        vault = new SimpleVault(asset, "VaultShare", "VSK");

        asset.mint(ALICE, 1000 ether);
        asset.mint(BOB, 1000 ether);

        vm.prank(ALICE);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(BOB);
        asset.approve(address(vault), type(uint256).max);
    }

    function checkAllowance(address who) internal {
        console.log("Allowance for:", who);
        console.log(asset.allowance(who, address(vault)));
    }

    modifier runPrintOps() {
        console.log("Underlying Asset address:", address(asset));
        console.log("Vault address:", address(vault));

        checkAllowance(ALICE);
        checkAllowance(BOB);

        _;
    }

    function testDeposit() public runPrintOps {
        vm.prank(ALICE);
        uint256 shares1 = vault.deposit(100 ether, ALICE);

        vm.prank(BOB);
        uint256 shares2 = vault.deposit(200 ether, BOB);

        console.log(shares1 / 1e18);
        console.log(shares2 / 1e18);

        console.log(vault.balanceOf(ALICE));
        console.log(vault.balanceOf(BOB));

        console.log("Total assets:", vault.totalAssets()); // total number of underlying assets
        console.log("Total supply:", vault.totalSupply()); // total number of shares

        assertEq(shares1 + shares2, 300 ether);
        // assertEq(vault.balanceOf(ALICE), 100 ether);
        // assertEq(vault.totalSupply(), 100 ether);
        // assertEq(vault.totalAssets(), 100 ether);
    }
}
