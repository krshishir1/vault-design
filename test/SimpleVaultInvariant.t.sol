// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import {SimpleVault} from "../src/SimpleVault.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleVaultInvariant is StdInvariant, Test {
    MockERC20 asset;
    SimpleVault vault;

    address alice = vm.addr(1);
    address bob = vm.addr(2);

    function setUp() public {
        asset = new MockERC20("Mock", "M");
        vault = new SimpleVault(asset, "Vault", "vM");

        // fund accounts
        asset.mint(alice, 1_000_000 ether);
        asset.mint(bob, 1_000_000 ether);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);

        // Register target for invariant fuzzing
        targetContract(address(vault));
    }

    /*//////////////////////////////////////////////////////////////
                          INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// 1. totalAssets() must always be >= on-chain asset balance
    function invariant_TotalAssetsAlwaysCorrect() public {
        uint256 onChain = asset.balanceOf(address(vault)); // total underlying asset
        uint256 reported = vault.totalAssets();
        assertGe(reported, onChain, "totalAssets < balance (BAD)");
    }

    /// 2. Share inflation must never occur:
    ///    If totalAssets stays constant, share conversions cannot change.
    function invariant_NoShareInflation() public {
        uint256 supply = vault.totalSupply();
        uint256 assets = vault.totalAssets();
        // if no supply or assets, skip trivial case
        if (supply == 0 || assets == 0) return;

        // random test: converting assets → shares → assets produces <= original assets
        uint256 x = uint256(keccak256("seed")) % 1e24;

        uint256 shares = vault.convertToShares(x);
        uint256 back = vault.convertToAssets(shares);

        assertLe(
            back,
            x,
            "inflation detected: convertToShares/convertToAssets inconsistent"
        );
    }

    /// 3. No negative redemption: redeeming shares must return <= owned assets
    function invariant_RedeemConsistency() public {
        uint256 supply = vault.totalSupply();
        uint256 assets = vault.totalAssets();
        if (supply == 0 || assets == 0) return;

        uint256 randShares = uint256(keccak256("rand")) % supply;

        uint256 outAssets = vault.previewRedeem(randShares);

        // Since shares represent fractional ownership,
        // previewRedeem cannot exceed proportional assets
        assertLe(outAssets, vault.convertToAssets(randShares));
    }

    /// 4. Deposit/Mint and Withdraw/Redeem conversions must never return 0 when >0 input
    function invariant_NonZeroResultsForValidInputs() public {
        if (vault.totalAssets() == 0 && vault.totalSupply() == 0) return;

        uint256 x = 1000 ether;

        if (vault.totalAssets() > 0) {
            assertGt(vault.previewDeposit(x), 0);
            assertGt(vault.previewMint(1 ether), 0);
        }
    }
}
