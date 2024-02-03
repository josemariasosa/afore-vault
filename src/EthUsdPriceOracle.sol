// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IEthUsdPriceOracle {
    function getLatestPrice() external view returns (int256);
    function decimals() external view returns (int256);
}

contract EthUsdPriceOracle {
    // AggregatorV3Interface internal priceFeed;

    /**
     * Network: Ethereum Mainnet
     * Aggregator: ETH/USD
     * Address: See Chainlink documentation for the most recent address
     */
    constructor() {
        // priceFeed = AggregatorV3Interface("<Chainlink ETH/USD Price Feed Address>");
    }

    /**
     * Returns the latest price
     */
    function getLatestPrice() public view returns (int) {
        // (
        //     /*uint80 roundID*/,
        //     int price,
        //     /*uint startedAt*/,
        //     /*uint timeStamp*/,
        //     /*uint80 answeredInRound*/
        // ) = priceFeed.latestRoundData();
        // return price;
        return 230489902662;
    }

    function decimals() public view returns (int) {
        return 8;
    }
}
