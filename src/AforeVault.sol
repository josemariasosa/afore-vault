// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";

interface IMpEth is IERC4626 {
    function depositETH(address _receiver) external payable returns (uint256);
}

// Pension start and fully-delivered dates, in seconds.
// Only a percentage of the funds will be released during this period.
// The rest of the funds will be delivered after the end-timestamp.
struct Afore {
    uint256 cliffTimestamp;
    uint256 endTimestamp;
    uint256 pensionPercent;
    uint256 mpEthBalance;
    uint256 mpEthWithdraw;
    address owner;
    address beneficiary1;
    address beneficiary2;
    address beneficiary3;
}

library AforeLib {
    error ExceededBeneficiariesNumber();
    uint32 public constant BASIS_POINTS = 10000;

    function setBeneficiaries(Afore storage self, address[] memory _beneficiaries) public {
        if (_beneficiaries.length > 3) revert ExceededBeneficiariesNumber();
        // Reset state variables
        self.beneficiary1 = address(0);
        self.beneficiary2 = address(0);
        self.beneficiary3 = address(0);

        uint256 beneficiariesCount = 0; // Counter to track unique, non-zero addresses assigned

        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            // Check if the current address is not zero and is unique in the given context
            if (_beneficiaries[i] != address(0) && isUniqueAddress(self, _beneficiaries[i], beneficiariesCount)) {
                // Increment counter for each unique, non-zero address
                beneficiariesCount++;

                // Assign the address to the corresponding state variable based on the counter
                if (beneficiariesCount == 1) {
                    self.beneficiary1 = _beneficiaries[i];
                } else if (beneficiariesCount == 2) {
                    self.beneficiary2 = _beneficiaries[i];
                } else if (beneficiariesCount == 3) {
                    self.beneficiary3 = _beneficiaries[i];
                }

                // If three unique, non-zero addresses have been assigned, exit loop
                if (beneficiariesCount == 3) break;
            }
        }
    }

    // Helper function to check if the address is unique among the first few beneficiaries
    function isUniqueAddress(Afore storage self, address _address, uint256 beneficiariesCount) private view returns (bool) {
        if (beneficiariesCount >= 1 && _address == self.beneficiary1) return false;
        if (beneficiariesCount >= 2 && _address == self.beneficiary2) return false;
        if (beneficiariesCount >= 3 && _address == self.beneficiary3) return false;

        return true;
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

    // Values are in mpETH
    function getAvailable(Afore memory self) external view returns (uint256 _available) {
        uint256 _progress = _getPensionProgress(self.cliffTimestamp, self.endTimestamp, block.timestamp);
        if (_progress == 0) return 0;

        uint256 totalMpEth = self.mpEthWithdraw + self.mpEthBalance;
        uint256 pensionMpEth = totalMpEth * self.pensionPercent / BASIS_POINTS;
        uint256 finalMpEth = totalMpEth - pensionMpEth;

        uint256 pensionAtThisMoment = pensionMpEth * _progress / BASIS_POINTS;
        _available = pensionAtThisMoment - self.mpEthWithdraw;

        // only if there is available balance.
        if (_progress == BASIS_POINTS && (self.mpEthBalance >= finalMpEth)) _available += finalMpEth;
    }

}



contract AforeVault {
    using SafeERC20 for IMpEth;
    using AforeLib for Afore;

    Afore[] private afores;

    uint32 public constant MAX_VALID_TOKENS = 15;
    uint32 public constant MONTH_DAYS = 30;

    // EnumerableSet.AddressSet private beneficiaries;


    // uint256 public immutable cliffTimestamp;
    // uint256 public immutable endTimestamp;
    // uint256 public immutable pensionPercent;

    IMpEth public immutable mpEth;

    // uint256 public ethWithdraw;
    // uint256 public mpEthWithdraw;
    // mapping(IERC20 => uint256) public erc20Withdraws;


    error InvalidTimestamp();
    error NotTheOwner();
    error InvalidArray();
    error InvalidBasisPoints();
    error InvalidBeneficiary();
    error DuplicatedAddress(address _beneficiary);
    error OnlyBeneficiary();
    error PensionNotAvailable();
    error InvalidIndex();
    error InvalidAmount();

    // modifier onlyBene {
    //     if (containsBeneficiary(msg.sender)) {
    //         _;
    //     }
    //     revert OnlyBeneficiary();
    // }

    modifier validIndex(uint256 _index) {
        if (_index >= afores.length) revert InvalidIndex();
        _;
    }

    modifier onlyOwner(uint256 _index) {
        if (afores[_index].owner == msg.sender) {
            _;
        }
        revert NotTheOwner();
    }

    modifier validBP(uint256 _bp) {
        if (_bp > 100000) revert InvalidBasisPoints();
        _;
    }

    constructor(IMpEth _mpEth) {
        mpEth = _mpEth;
    }

    // receive() extessnal payable {}

    function createAfore(
        uint256 _cliff,
        uint256 _end,
        uint256 _pensionPercent,
        address _owner,
        address[] memory _beneficiaries
    ) external payable validBP(_pensionPercent) {
        if (_cliff >= _end) revert InvalidTimestamp();
        if (_cliff <= block.timestamp) revert InvalidTimestamp();
        
        Afore memory _afore;
        _afore.cliffTimestamp = _cliff;
        _afore.endTimestamp = _end;
        _afore.pensionPercent = _pensionPercent;
        _afore.owner = _owner;
        afores.push(_afore);

        // Set the beneficiaries for the Storage Afore.
        afores[afores.length - 1].setBeneficiaries(_beneficiaries);
    }

    // ***********************
    // * Beneficiaries Admin *
    // ***********************

    function setBeneficiaries(uint256 _index, address[] memory _beneficiaries) external validIndex(_index) onlyOwner(_index) {
        Afore storage _afore = afores[_index];
        _afore.setBeneficiaries(_beneficiaries);
    }

    function containsBeneficiary(uint256 _index, address _address) public view validIndex(_index) returns (bool) {
        Afore memory _afore = afores[_index];
        return _afore.beneficiary1 == _address
            || _afore.beneficiary2 == _address
            || _afore.beneficiary3 == _address;
    }

    // Deposit mpETH

    function deposit(uint256 _index, uint256 _mpEthAmount) public payable validIndex(_index) {
        uint256 _totalDeposit;

        if (msg.value > 0) {
            // depositETH returns the amount of "shares" mpETH.
            _totalDeposit += mpEth.depositETH{value: msg.value}(address(this));
        }

        if (_mpEthAmount > 0) {
            mpEth.safeTransferFrom(msg.sender, address(this), _mpEthAmount);
            _totalDeposit += _mpEthAmount;
        }

        if (_totalDeposit == 0) revert InvalidAmount();

        Afore storage _afore = afores[_index];
        _afore.mpEthBalance += _totalDeposit;
    }


    function getAvailable(uint256 _index) public validIndex(_index) view returns (uint256) {
        Afore memory _afore = afores[_index];
        return _afore.getAvailable();
        // return _getAvailableEth(
        //     _getPensionProgress(_afore.cliffTimestamp, _afore.endTimestamp, block.timestamp),
        //     _afore
        // );
    }

    function getAvailableEth(uint256 _index) public validIndex(_index) view returns (uint256) {
        Afore memory _afore = afores[_index];
        return mpEth.convertToAssets(_afore.getAvailable());
    }


    // function getTotalEth() private returns (uint256) {
    //     ethWithdraw + address(this).balance;
    //     mpEthWithdraw + mpEth.balanceOf(address(this));


    // }












    

    // function _getAvailableEth(uint256 _progress, Afore memory _afore) private view returns (uint256 _availableMpEth) {
    //     if (_progress == 0) return 0;

    //     uint256 totalMpEth = _afore.mpEthWithdraw + _afore.mpEthBalance;
    //     uint256 pensionMpEth = totalMpEth * _afore.pensionPercent / BASIS_POINTS;
    //     uint256 finalMpEth = totalMpEth - pensionMpEth;

    //     uint256 pensionAtThisMoment = pensionMpEth * _progress / BASIS_POINTS;
    //     _availableMpEth = pensionAtThisMoment - _afore.mpEthWithdraw;

    //     // only if there is available balance.
    //     if (_progress == BASIS_POINTS && (_afore.mpEthBalance >= finalMpEth)) _availableMpEth += finalMpEth;
    // }

    // function getAvailableErc20(IERC20 _token, uint256 _progress) internal view returns (uint256 _available) {
    //     uint256 erc20Withdraw = erc20Withdraws[_token];
    //     uint256 total = erc20Withdraw + _token.balanceOf(address(this));
    //     uint256 pension = total * pensionPercent / BASIS_POINTS;
    //     uint256 finalErc20 = total - pension;

    //     uint256 pensionAtThisMoment = pension * _progress / BASIS_POINTS;
    //     _available = pensionAtThisMoment - erc20Withdraw;

    //     if (_progress == BASIS_POINTS) {
    //         _available += finalErc20;
    //     }
    // }

    // function withdraw() public onlyBene {
    //     if (block.timestamp < cliffTimestamp) revert PensionNotAvailable();

    //     uint256 _progress = getPensionProgress(
    //         cliffTimestamp,
    //         endTimestamp,
    //         block.timestamp
    //     );

    //     uint256 availableEth = _getAvailableEth(_progress);
    //     ethWithdraw += availableEth;
    //     if (availableEth > 0) payable(msg.sender).transfer(availableEth);

    //     uint256 available;
    //     for (uint i; i < erc20s.length; ++i) {
    //         available = _getAvailableErc20(erc20s[i], _progress);
    //         erc20Withdraws[erc20s[i]] += available;
    //         if (available > 0) erc20s[i].transfer(msg.sender, available);

    //     }
    // }

}
