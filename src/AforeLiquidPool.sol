// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/// @title USD stable-coin - Meta Pool ETH Liquidity Pool.

// import "./interfaces/ILiquidityPool.sol";
// import "./interfaces/IStakedAuroraVault.sol";
import "./utils/FullyOperational.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {IMetaPoolETH} from "./AforeVault.sol";
import {IEthUsdPriceOracle} from "./interfaces/IEthUsdPriceOracle.sol";

// import "./AforeVault.sol";

/// @notice this contract will help users buying mpETH with USD.

contract AforeLiquidPool is FullyOperational, ERC4626 {
    using SafeERC20 for IERC20;
    using SafeERC20 for IMetaPoolETH;
    // using SafeERC20 for IStakedAuroraVault;

    /// @dev 100% represented as Basis Points.
    uint256 public constant ONE_HUNDRED_PERCENT = 10_000;

    // bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    // bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    // bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    /// @dev Contract addresses of the stAUR vault and the AURORA token.
    address immutable public aforeVault;
    address immutable public stableUsd;

    IMetaPoolETH immutable public mpEth;
    
    // Price oracle should be able to be updated.
    IEthUsdPriceOracle public ethUsdOracle;


    /// @dev Internal accounting for the two vault assets.
    uint256 public mpEthBalance;
    uint256 public usdBalance;

    // Only usd Balance is allowed (6 decimals)
    uint256 public minDepositAmount;

    /// @dev Fee is represented as Basis Points (100 points == 1.00%).
    uint256 public swapFeeBasisPoints;

    /// @dev How much of the Swap Fee, the liquidity providers will keep.
    uint256 public liqProvFeeCutBasisPoints;

    // /// @dev The remaining Fees will be available to be collected by Meta Pool.
    // uint256 public collectedStAurFees;

    error Unauthorized();
    error InvalidBasisPoints();
    error InvalidZeroAddress();
    error LessThanMinDeposit();
    error InvalidZeroAmount();

    modifier onlyAforeVault() {
        if (msg.sender != aforeVault) { revert Unauthorized(); }
        _;
    }

    modifier validBP(uint256 _basisPoints) {
        if (_basisPoints > ONE_HUNDRED_PERCENT) { revert InvalidBasisPoints(); }
        _;
    }

    //** Base asset must be USD */

    constructor(
        address _aforeVault,
        address _stableUsd,
        IMetaPoolETH _mpEth,
        IEthUsdPriceOracle _ethUsdOracle,
        string memory _lpTokenName,
        string memory _lpTokenSymbol,
        uint256 _swapFeeBasisPoints
    )
        ERC4626(IERC20(_stableUsd))
        ERC20(_lpTokenName, _lpTokenSymbol)
        validBP(_swapFeeBasisPoints)
    {
        if (_aforeVault == address(0) || address(_mpEth) == address(0) || _stableUsd == address(0)) {
            revert InvalidZeroAddress();
        }

        aforeVault = _aforeVault;
        stableUsd = _stableUsd;
        mpEth = _mpEth;
        ethUsdOracle = _ethUsdOracle;
        swapFeeBasisPoints = _swapFeeBasisPoints;
        fullyOperational = true;

        // _grantRole(ADMIN_ROLE, msg.sender);
        // _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // _grantRole(TREASURY_ROLE, _feeCollectorRole);
        // _grantRole(OPERATOR_ROLE, _contractOperatorRole);
    }

    receive() external payable {}

    // function updateMinDepositAmount(
    //     uint256 _amount
    // ) external onlyRole(OPERATOR_ROLE) {
    //     minDepositAmount = _amount;

    //     emit UpdateMinDepositAmount(_amount, msg.sender);
    // }

    // function updateFeeBasisPoints(
    //     uint256 _feeBasisPoints
    // ) external onlyRole(OPERATOR_ROLE) validBP(_feeBasisPoints) {
    //     swapFeeBasisPoints = _feeBasisPoints;

    //     emit UpdateFeeBasisPoints(_feeBasisPoints, msg.sender);
    // }

    // function updateLiqProvFeeBasisPoints(
    //     uint256 _feeBasisPoints
    // ) external onlyRole(OPERATOR_ROLE) validBP(_feeBasisPoints) {
    //     liqProvFeeCutBasisPoints = _feeBasisPoints;

    //     emit UpdateLiqProvFeeBasisPoints(_feeBasisPoints, msg.sender);
    // }

    /// @notice Use in case of emergency 🦺, stops: 1) adding and removing
    /// liquidity, 2) all swaps from stAUR to AURORA tokens and 3) providing
    /// stAUR token liquidity to cover deposits (FLOW 1).
    function updateContractOperation(
        bool _isFullyOperational
    // ) public override onlyRole(ADMIN_ROLE) {
    ) public override {
        fullyOperational = _isFullyOperational;

        emit ContractUpdateOperation(_isFullyOperational, msg.sender);
    }

    // /// @notice Function to evaluate if a Vault deposit can be covered by the
    // /// balance of stAUR tokens in the Liquidity Pool.
    // function isStAurBalanceAvailable(uint256 _amount) external view returns(bool) {
    //     return (stAurBalance >= _amount) && fullyOperational;
    // }

    // /// @notice The stAUR Vault will emit the Deposit event if this function runs.
    // /// @dev This function will ONLY be called by the stAUR vault
    // /// to cover Aurora deposits (FLOW 1).
    // function transferStAur(
    //     address _receiver,
    //     uint256 _amount,
    //     uint256 _assets
    // ) external onlyStAurVault {
    //     stAurBalance -= _amount;
    //     address _stAurVault = stAurVault;
    //     IStakedAuroraVault(_stAurVault).safeTransfer(_receiver, _amount);
    //     auroraBalance += _assets;
    //     IERC20(auroraToken).safeTransferFrom(_stAurVault, address(this), _assets);

    //     emit StAurLiquidityProvidedByPool(_receiver, _amount, _assets);
    // }
    
    /// @dev Calculate sum of AURORA and stAUR balance, converting the amount of
    /// stAUR to AURORA using the Vault price.
    /// @return _amount Denominated in AURORA tokens.
    function totalAssets() public view override returns (uint256) {
        return usdBalance + convertMpEth2Usd(mpEthBalance);
    }

    function convertMpEth2Usd(uint256 _mpEthAmount) public view returns (uint256) {
        uint256 eth = mpEth.convertToAssets(_mpEthAmount);
        uint256 price = uint256(ethUsdOracle.getLatestPrice());

        // WARNING!!!!!!! _________
        return eth * price / 10 ** uint(ethUsdOracle.decimals()) / 10 ** 10;
    }

    /// @notice The deposit flow is used to **Add** liquidity to the Liquidity Pool.
    function deposit(
        uint256 _assets,
        address _receiver
    ) public override onlyFullyOperational returns (uint256) {
        if (_assets < minDepositAmount) { revert LessThanMinDeposit(); }
        require(_assets <= maxDeposit(_receiver), "ERC4626: deposit more than max");

        uint256 _shares = previewDeposit(_assets);
        _deposit(msg.sender, _receiver, _assets, _shares);

        return _shares;
    }

    function mint(
        uint256 _shares,
        address _receiver
    ) public override onlyFullyOperational returns (uint256) {
        require(_shares <= maxMint(_receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(_shares);
        if (assets < minDepositAmount) { revert LessThanMinDeposit(); }
        _deposit(msg.sender, _receiver, assets, _shares);

        return assets;
    }

    /// @notice Front-end can preview the amount that will be redeemed.
    function calculatePreviewRedeem(uint256 _shares) public view returns (uint256, uint256) {
        // Core Calculations.
        uint256 ONE_AURORA = 1 ether;
        uint256 poolPercentage = (_shares * ONE_AURORA) / totalSupply();
        uint256 mpEthToSend = (poolPercentage * mpEthBalance) / ONE_AURORA;
        uint256 usdToSend = (poolPercentage * usdBalance) / ONE_AURORA;

        return (mpEthToSend, usdToSend);
    }

    /// @notice The redeem flow is used to **Remove** liquidity from the Liquidity Pool.
    /// @return ONLY the amount of base assets (AURORA token) that will be returned.
    /// However, the liquidity provider expects to receive stAUR tokens as well,
    /// in proportion of the redeemed shares.
    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) public override onlyFullyOperational returns (uint256) {
        if (_shares == 0) { revert InvalidZeroAmount(); }
        require(_shares <= maxRedeem(_owner), "ERC4626: redeem more than max");

        (uint256 mpEthToSend, uint256 usdToSend) = calculatePreviewRedeem(_shares);
        uint256 _totalInUsdToSend = usdToSend + convertMpEth2Usd(mpEthToSend);
        _withdraw(
            msg.sender,
            _receiver,
            _owner,
            usdToSend,
            mpEthToSend,
            _totalInUsdToSend,
            _shares
        );

        return _totalInUsdToSend;
    }

    /// @param _assets units are in the base asset, the AURORA token.
    /// @return shares are the LP token that were burnt during the operation.
    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    ) public override onlyFullyOperational returns (uint256) {
        if (_assets == 0) { revert InvalidZeroAmount(); }
        require(_assets <= maxWithdraw(_owner), "ERC4626: withdraw more than max");

        uint256 shares = previewWithdraw(_assets);
        (uint256 mpEthToSend, uint256 usdToSend) = calculatePreviewRedeem(shares);
        uint256 _totalInUsdToSend = usdToSend + convertMpEth2Usd(mpEthToSend);
        _withdraw(
            msg.sender,
            _receiver,
            _owner,
            usdToSend,
            mpEthToSend,
            _totalInUsdToSend,
            shares
        );

        return shares;
    }

    // /// @param _amount Denominated in stAUR.
    // /// @return _auroraAmount Denominated in AURORA.
    // function previewSwapStAurForAurora(uint256 _amount) external view returns (uint256) {
    //     (uint256 _discountedAmount,,) = _calculatePoolFees(_amount);
    //     return IStakedAuroraVault(stAurVault).convertToAssets(_discountedAmount);
    // }

    // /// @notice Function that allows "fast unstake".
    // /// @param _stAurAmount Denominated in stAUR.
    // /// @param _minAuroraToReceive Min amount of AURORA tokens that the user is expecting,
    // /// get a value for this parameter using the function previewSwapStAurForAurora().
    // function swapStAurForAurora(
    //     uint256 _stAurAmount,
    //     uint256 _minAuroraToReceive
    // ) external onlyFullyOperational {
    //     if (_stAurAmount == 0) { revert InvalidZeroAmount(); }
    //     (
    //         uint256 _discountedAmount,
    //         uint256 _collectedFee,
    //         uint256 _lpFeeCut
    //     ) = _calculatePoolFees(_stAurAmount);

    //     IStakedAuroraVault vault = IStakedAuroraVault(stAurVault);
    //     uint256 auroraToSend = vault.convertToAssets(_discountedAmount);

    //     if (auroraToSend > auroraBalance) { revert NotEnoughBalance(); }
    //     if (auroraToSend < _minAuroraToReceive) { revert SlippageError(); }

    //     stAurBalance += (_discountedAmount + _lpFeeCut);
    //     collectedStAurFees += _collectedFee;
    //     auroraBalance -= auroraToSend;

    //     // Step 1. Get the caller stAUR tokens.
    //     vault.safeTransferFrom(msg.sender, address(this), _stAurAmount);

    //     // Step 2. Transfer the Aurora tokens to the caller.
    //     IERC20(auroraToken).safeTransfer(msg.sender, auroraToSend);

    //     emit SwapStAur(
    //         msg.sender,
    //         auroraToSend,
    //         _stAurAmount,
    //         _collectedFee + _lpFeeCut
    //     );
    // }

    // /// @notice The collected stAUR fees are owned by Meta Pool.
    // function withdrawCollectedStAurFees(
    //     address _receiver
    // ) external {
    //     uint256 _toTransfer = collectedStAurFees;
    //     collectedStAurFees = 0;
    //     IStakedAuroraVault(stAurVault).safeTransfer(_receiver, _toTransfer);

    //     emit WithdrawCollectedFees(_receiver, _toTransfer, msg.sender);
    // }

    /// @notice The fee is splited in two: first, for the Liquidity Providers, and
    /// second, for Meta Pool, granted for TREASURY_ROLE.
    /// @dev CONSIDER FORMULA: _discountedAmount + _collectedFee + _lpFeeCut == _amount
    /// @return _discountedAmount stAUR to be taken from the pool to cover the swap.
    /// @return _collectedFee stAUR to be granted for TREASURY_ROLE.
    /// @return _lpFeeCut stAUR for our friends, the Liquidity Providers.
    function _calculatePoolFees(
        uint256 _amount
    ) private view returns (uint256, uint256, uint256) {
        uint256 totalFee = (
            _amount * swapFeeBasisPoints
        ) / ONE_HUNDRED_PERCENT;

        // The cut of the fee destinated to the Liquidity Providers.
        uint256 _lpFeeCut = (
            totalFee * liqProvFeeCutBasisPoints
        ) / ONE_HUNDRED_PERCENT;

        return (_amount - totalFee, totalFee - _lpFeeCut, _lpFeeCut);
    }

    // /// @dev The Deposit event is used to indicate more liquidity.
    // function _deposit(
    //     address _caller,
    //     address _receiver,
    //     uint256 _assets,
    //     uint256 _shares
    // ) internal virtual override {
    //     auroraBalance += _assets;
    //     IERC20(asset()).safeTransferFrom(_caller, address(this), _assets);
    //     _mint(_receiver, _shares);

    //     emit AddLiquidity(_caller, _receiver, _assets, _shares);
    // }

    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _usdToSend,
        uint256 _mpEthToSend,
        uint256 _totalInAuroraToSend,
        uint256 _shares
    ) internal virtual {
        if (_caller != _owner) {
            _spendAllowance(_owner, _caller, _shares);
        }

        usdBalance -= _usdToSend;
        mpEthBalance -= _mpEthToSend;

        // IMPORTANT NOTE: run the burn 🔥 AFTER the calculations.
        _burn(_caller, _shares);

        // Send Aurora tokens.
        IERC20(asset()).safeTransfer(_receiver, _usdToSend);

        // Then, send stAUR tokens.
        mpEth.safeTransfer(_receiver, _mpEthToSend);
        // IStakedAuroraVault(stAurVault).safeTransfer(_receiver, _stAurToSend);

        emit Withdraw(_caller, _receiver, _owner, _totalInAuroraToSend, _shares);
    }
}