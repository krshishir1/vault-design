// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract SimpleVault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset; // underlying token
    uint8 private immutable _decimals; // decimals of vault shares

    uint256 internal _virtualAssets;

    constructor(
        IERC20 _asset,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        asset = _asset;
        _decimals = 18; // shares use same decimals as underlying
    }

    /// @notice Total assets managed by vault = token balance + strategy balances
    function totalAssets() public view virtual returns (uint256) {
        return asset.balanceOf(address(this)) + _virtualAssets;
    }

    /*//////////////////////////////////////////////////////////////
                        CONVERSION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Convert assets -> shares (floor)
    function convertToShares(
        uint256 assets
    ) public view virtual returns (uint256) {
        uint256 _supply = totalSupply();
        uint256 _assets = totalAssets();

        return
            (_supply == 0 || _assets == 0)
                ? assets
                : (assets * _supply) / _assets;
    }

    /// @notice Convert shares -> assets (floor)
    function convertToAssets(
        uint256 shares
    ) public view virtual returns (uint256) {
        uint256 _supply = totalSupply();
        uint256 _assets = totalAssets();

        return
            (_supply == 0 || _assets == 0) ? 0 : (shares * _assets) / _supply;
    }

    /*//////////////////////////////////////////////////////////////
                            PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 _supply = totalSupply();
        uint256 _assets = totalAssets();

        if (_supply == 0 || _assets == 0) return shares;

        // ceil(shares * totalAssets / totalSupply)
        return Math.ceilDiv(shares * _assets, _supply);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 _supply = totalSupply();
        uint256 _assets = totalAssets();

        if (_supply == 0 || _assets == 0) return assets;

        // ceil(assets * totalSupply / totalAssets)
        return Math.ceilDiv(assets * _supply, _assets);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                      MAX DEPOSIT / REDEEM LIMITS
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT / MINT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit assets and mint shares
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        require(assets > 0, "ZERO_ASSETS");

        shares = previewDeposit(assets);
        require(shares > 0, "ZERO_SHARES");

        // pull underlying tokens
        asset.safeTransferFrom(msg.sender, address(this), assets);

        afterDeposit(assets, shares);

        _mint(receiver, shares);
    }

    /// @notice Mint shares by depositing required assets
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets) {
        require(shares > 0, "ZERO_SHARES");

        assets = previewMint(shares);
        require(assets > 0, "ZERO_ASSETS");

        asset.safeTransferFrom(msg.sender, address(this), assets);

        afterDeposit(assets, shares);

        _mint(receiver, shares);
    }

    /*//////////////////////////////////////////////////////////////
                       WITHDRAW / REDEEM
    //////////////////////////////////////////////////////////////*/

    /// @notice Withdraw assets by burning enough shares
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares) {
        require(assets > 0, "ZERO_ASSETS");

        shares = previewWithdraw(assets);
        require(shares > 0, "ZERO_SHARES");

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        asset.safeTransfer(receiver, assets);
    }

    /// @notice Redeem shares for assets
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets) {
        require(shares > 0, "ZERO_SHARES");

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        assets = previewRedeem(shares);
        require(assets > 0, "ZERO_ASSETS");

        beforeWithdraw(assets, shares);

        _burn(owner, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                          STRATEGY HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook after assets enter the vault (e.g., deposit into strategy)
    function afterDeposit(uint256 assets, uint256 shares) internal virtual {
        // override to integrate yield strategies
    }

    /// @notice Hook before assets leave the vault (e.g., withdraw from strategy)
    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {
        // override to ensure liquidity
    }
}

// previewDeposit → floor
// previewRedeem → floor
// previewMint → ceil
// previewWithdraw → ceil
