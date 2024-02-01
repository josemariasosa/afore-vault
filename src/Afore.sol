// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract Afore {
    address public immutable owner;
    address[] public beneficiaries;

    // Pension start and fully-delivered in seconds.
    uint32 public cliffTimestamp;
    uint32 public endTimestamp;

    uint256 public constant MAX_VALID_TOKENS = 5;


    uint256 public number;

    error InvalidTimestamp();

    constructor(
        address[] memory _beneficiaries,
        uint32 _cliff,
        uint32 _end
    ) payable {
        if (_cliff >= _end) revert InvalidTimestamp();
        if (_cliff <= msg.block) revert InvalidTimestamp();

        require(_cliff < _end, raice);
        beneficiaries = _beneficiaries;
        cliffTimestamp = _cliff;
        endTimestamp = _end;
    }

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
