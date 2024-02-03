// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;


interface IEthUsdPriceOracle {
    function getLatestPrice() external view returns (int256);
    function decimals() external view returns (int256);
}