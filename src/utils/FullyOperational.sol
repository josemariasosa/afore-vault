// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IFullyOperational {
    error NotFullyOperational();

    function isFullyOperational() external view returns (bool);
}

abstract contract FullyOperational is IFullyOperational {
    bool public fullyOperational;

    modifier onlyFullyOperational() {
        if (!isFullyOperational()) { revert NotFullyOperational(); }
        _;
    }

    function isFullyOperational() public view returns (bool) {
        return fullyOperational;
    }

    /// *********************
    /// * Virtual functions *
    /// *********************

    function updateContractOperation(bool _isFullyOperational) public virtual;
}