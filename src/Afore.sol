// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";


contract Afore is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint32 public constant BASIS_POINTS = 10000;
    uint32 public constant MAX_VALID_TOKENS = 15;
    uint32 public constant MONTH_DAYS = 30;

    EnumerableSet.AddressSet private beneficiaries;

    // Pension start and fully-delivered in seconds.
    // Only a percentage of the funds will be released during this period.
    // The rest of the funds will be delivered after the end-timestamp.
    uint32 public cliffTimestamp;
    uint32 public endTimestamp;
    uint32 public pensionPercent;

    IERC20[] public erc20s;

    uint256 public ethWithdraw;
    mapping(IERC20 => uint256) public erc20Withdraws;


    error InvalidTimestamp();
    error InvalidArray();
    error InvalidBasisPoints();
    error DuplicatedAddress(address _beneficiary);
    error OnlyBeneficiary();
    error PensionNotAvailable();

    modifier onlyBene {
        if (containsAddress(msg.sender)) {
            _;
        }
        revert OnlyBeneficiary();
    }

    modifier validBP(uint32 _bp) {
        if (_bp > 100000) revert InvalidBasisPoints();
        _;
    }

    constructor(
        uint32 _cliff,
        uint32 _end,
        uint32 _pensionPercent,
        address _owner,
        address[] memory _beneficiaries,
        IERC20[] memory _erc20s
    ) Ownable(_owner) validBP(_pensionPercent) payable {
        if (_cliff >= _end) revert InvalidTimestamp();
        if (_cliff <= block.timestamp) revert InvalidTimestamp();
        if (_erc20s.length > MAX_VALID_TOKENS) revert InvalidArray();
        

        for (uint i; i < _beneficiaries.length; i++) {
            if (beneficiaries.contains(_beneficiaries[i])) {
                revert DuplicatedAddress(_beneficiaries[i]);
            } else {
                beneficiaries.add(_beneficiaries[i]);
            }
        }

        pensionPercent = _pensionPercent;
        erc20s = _erc20s;
        cliffTimestamp = _cliff;
        endTimestamp = _end;
    }

    receive() external payable {}

    // ***********************
    // * Beneficiaries Admin *
    // ***********************

    function addBeneficiary(address _address) external onlyOwner {
        // Add returns true if the _address was added to the set,
        // false if it was already in the set
        require(beneficiaries.add(_address), "Address already exists in set");
    }

    // Function to remove an address from the set
    function removeAddress(address _address) public {
        // Remove returns true if the _address was removed from the set,
        // false if it wasn't in the set to begin with
        require(beneficiaries.remove(_address), "Address does not exist in set");
    }

    // Function to check if an address is in the set
    function containsAddress(address _address) public view returns (bool) {
        return beneficiaries.contains(_address);
    }

    // Function to get the number of elements in the set
    function addressCount() public view returns (uint256) {
        return beneficiaries.length();
    }

    // Function to get an address by index from the set
    function getAddressAtIndex(uint256 index) public view returns (address) {
        require(index < beneficiaries.length(), "Index out of bounds");
        return beneficiaries.at(index);
    }

    function getPensionProgress(uint32 _cliff, uint32 _end) public view returns (uint32) {
        uint _pensionDuration = _end - _cliff;

        if (block.timestamp < _cliff) {
            return 0;
        } else if (block.timestamp < _end) {
            return uint32(BASIS_POINTS * (block.timestamp - _cliff) / _pensionDuration);
        } else {
            return BASIS_POINTS;
        }
    }


    function getAvailableEth(uint32 _progress) internal view returns (uint256 _availableEth) {
        uint256 totalEth = ethWithdraw + address(this).balance;
        uint256 pensionEth = totalEth * pensionPercent / BASIS_POINTS;
        uint256 finalEth = totalEth - pensionEth;

        uint256 pensionAtThisMoment = pensionEth * _progress / BASIS_POINTS;
        _availableEth = pensionAtThisMoment - ethWithdraw;

        if (_progress == BASIS_POINTS) {
            _availableEth += finalEth;
        }
    }

    function getAvailableErc20(IERC20 _token, uint32 _progress) internal view returns (uint256 _available) {
        uint256 withdraw = erc20Withdraws[_token];
        uint256 total = withdraw + _token.balanceOf(address(this));
        uint256 pension = total * pensionPercent / BASIS_POINTS;
        uint256 finalErc20 = total - pension;

        uint256 pensionAtThisMoment = pension * _progress / BASIS_POINTS;
        _available = pensionAtThisMoment - withdraw;

        if (_progress == BASIS_POINTS) {
            _available += _finalErc20;
        }
    }
    

    function withdraw() public onlyBene {
        if (block.timestamp < cliffTimestamp) revert PensionNotAvailable();

        uint32 _progress = getPensionProgress(cliffTimestamp, endTimestamp);

        uint256 availableEth = getAvailableEth(_progress);
        ethWithdraw += availableEth;
        if (availableEth > 0) payable(msg.sender).transfer(availableEth);

        uint256 available;
        for (uint i; i < erc20s.length; ++i) {
            available = getAvailableErc20(erc20s[i], _progress);
            erc20Withdraws[erc20s[i]] += available;
            if (available > 0) erc20s[i].transfer(msg.sender, available);

        }
        


        uint32 _cliff = cliffTimestamp;
        uint32 _end = endTimestamp;


         


    }

}
