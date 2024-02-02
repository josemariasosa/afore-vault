// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";



contract Afore is Ownable {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint32 public constant BASIS_POINTS = 10000;
    uint32 public constant MAX_VALID_TOKENS = 15;
    uint32 public constant MONTH_DAYS = 30;

    EnumerableSet.AddressSet private beneficiaries;

    // Pension start and fully-delivered dates, in seconds.
    // Only a percentage of the funds will be released during this period.
    // The rest of the funds will be delivered after the end-timestamp.
    uint256 public immutable cliffTimestamp;
    uint256 public immutable endTimestamp;
    uint256 public immutable pensionPercent;

    IERC4626 public immutable mpEth;

    uint256 public ethWithdraw;
    uint256 public mpEthWithdraw;
    // mapping(IERC20 => uint256) public erc20Withdraws;


    error InvalidTimestamp();
    error InvalidArray();
    error InvalidBasisPoints();
    error InvalidBeneficiary();
    error DuplicatedAddress(address _beneficiary);
    error OnlyBeneficiary();
    error PensionNotAvailable();
    error InvalidIndex();
    error InvalidAmount();

    modifier onlyBene {
        if (containsBeneficiary(msg.sender)) {
            _;
        }
        revert OnlyBeneficiary();
    }

    modifier validBP(uint256 _bp) {
        if (_bp > 100000) revert InvalidBasisPoints();
        _;
    }

    constructor(
        uint256 _cliff,
        uint256 _end,
        uint256 _pensionPercent,
        address _owner,
        IERC4626 _mpEth,
        address[] memory _beneficiaries
    ) Ownable(_owner) validBP(_pensionPercent) payable {
        if (_cliff >= _end) revert InvalidTimestamp();
        if (_cliff <= block.timestamp) revert InvalidTimestamp();
        
        for (uint i; i < _beneficiaries.length; i++) {
            if (beneficiaries.contains(_beneficiaries[i])) {
                revert DuplicatedAddress(_beneficiaries[i]);
            } else {
                beneficiaries.add(_beneficiaries[i]);
            }
        }

        pensionPercent = _pensionPercent;
        mpEth = _mpEth;
        cliffTimestamp = _cliff;
        endTimestamp = _end;
    }

    receive() external payable {}

    // ***********************
    // * Beneficiaries Admin *
    // ***********************

    function addBeneficiary(address _address) external onlyOwner {
        if (!beneficiaries.add(_address)) revert InvalidBeneficiary();
    }

    function removeBeneficiary(address _address) external onlyOwner {
        if (!beneficiaries.remove(_address)) revert InvalidBeneficiary();
    }

    function containsBeneficiary(address _address) public view returns (bool) {
        return beneficiaries.contains(_address);
    }

    function getBeneficiaryAtIndex(uint256 index) external view returns (address) {
        if (index >= beneficiaries.length()) revert InvalidIndex();
        return beneficiaries.at(index);
    }

    // Deposit mpETH

    function depositMpEth(uint256 _amount) public {
        if (_amount == 0) revert InvalidAmount();
        mpEth.safeTransferFrom(msg.sender, address(this), _amount);
    }


    function getAvailableEth() public view returns (uint256 _availableEth) {
        return _getAvailableEth(
            _getPensionProgress(cliffTimestamp, endTimestamp, block.timestamp)
        );
    }


    function getTotalEth() private returns (uint256) {
        ethWithdraw + address(this).balance;
        mpEthWithdraw + mpEth.balanceOf(address(this));


    }










    /// @notice that _cliff should be less than (<) _end.
    /// @param _cliff is the start date.
    /// @param _end is when the tokens are fully delivered to the beneficiaries.
    /// @param _now is an arbitrarily date..
    function _getPensionProgress(
        uint256 _cliff,
        uint256 _end,
        uint256 _now
    ) private pure returns (uint256) {
        if (_now < _cliff) {
            return 0;
        } else if (_now < _end) {
            return BASIS_POINTS * (_now - _cliff) / (_end - _cliff);
        } else {
            return BASIS_POINTS;
        }
    }

    

    function _getAvailableEth(uint256 _progress) private view returns (uint256 _availableEth) {
        if (_progress == 0) return 0;

        uint256 totalEth = ethWithdraw + address(this).balance;
        uint256 pensionEth = totalEth * pensionPercent / BASIS_POINTS;
        uint256 finalEth = totalEth - pensionEth;

        uint256 pensionAtThisMoment = pensionEth * _progress / BASIS_POINTS;
        _availableEth = pensionAtThisMoment - ethWithdraw;

        if (_progress == BASIS_POINTS) _availableEth += finalEth;
    }

    function getAvailableErc20(IERC20 _token, uint256 _progress) internal view returns (uint256 _available) {
        uint256 erc20Withdraw = erc20Withdraws[_token];
        uint256 total = erc20Withdraw + _token.balanceOf(address(this));
        uint256 pension = total * pensionPercent / BASIS_POINTS;
        uint256 finalErc20 = total - pension;

        uint256 pensionAtThisMoment = pension * _progress / BASIS_POINTS;
        _available = pensionAtThisMoment - erc20Withdraw;

        if (_progress == BASIS_POINTS) {
            _available += finalErc20;
        }
    }

    function withdraw() public onlyBene {
        if (block.timestamp < cliffTimestamp) revert PensionNotAvailable();

        uint256 _progress = getPensionProgress(
            cliffTimestamp,
            endTimestamp,
            block.timestamp
        );

        uint256 availableEth = _getAvailableEth(_progress);
        ethWithdraw += availableEth;
        if (availableEth > 0) payable(msg.sender).transfer(availableEth);

        uint256 available;
        for (uint i; i < erc20s.length; ++i) {
            available = _getAvailableErc20(erc20s[i], _progress);
            erc20Withdraws[erc20s[i]] += available;
            if (available > 0) erc20s[i].transfer(msg.sender, available);

        }
    }

}
