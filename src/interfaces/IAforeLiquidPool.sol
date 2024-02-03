// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;


interface IAforeLiquidPool {
    function swapUsd2MpEth(uint256 _amount) external returns (uint256);
}