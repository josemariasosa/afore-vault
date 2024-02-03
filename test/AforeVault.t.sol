// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../src/AforeVault.sol";
import "../src/mocks/Token.sol";
import "../src/mocks/MetaPoolETH.sol";
import "../src/AforeLiquidPool.sol";
import "../src/mocks/EthUsdPriceOracle.sol";
import "forge-std/Test.sol";

import {IEthUsdPriceOracle} from "../src/interfaces/IEthUsdPriceOracle.sol";

contract AforeTest is Test {

    // Timestamps
    uint256 startTimestamp;

    // Contracts
    AforeVault public vault;
    Token public usdc;
    MetaPoolETH public mpEth;
    Token public weth;

    AforeLiquidPool public lp;
    EthUsdPriceOracle public oracle;

    address public safeWallet = address(10);

    function setUp() public {

        startTimestamp = block.timestamp;

        usdc = new Token("Stable coin", "USDC");
        weth = new Token("Wrapped ETH", "wETH");
        mpEth = new MetaPoolETH(IERC20(weth), "Staked ETH", "mpETH");

        vault = new AforeVault(
            IMetaPoolETH(address(mpEth)),
            IERC20(address(usdc))
        );

        oracle = new EthUsdPriceOracle();
        lp = new AforeLiquidPool(
            address(vault),
            address(usdc),
            IMetaPoolETH(address(mpEth)),
            IEthUsdPriceOracle(address(oracle)),
            "mpETH USDC Liquid Pool",
            "mpETH/USDC LP",
            5000
        );

        vault.updateLp(IAforeLiquidPool(address(lp)));
    }

    function testCreateAfore(uint32 _pensionPercent, uint256 _amountEth) public {
        vm.assume(_pensionPercent <= 100000);
        vm.assume(_amountEth <= msg.sender.balance);

        uint256 cliffTimestamp = startTimestamp + 1 days;
        uint256 endTimestamp = cliffTimestamp + 30 days;

        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = address(11);
        beneficiaries[1] = address(12);
        beneficiaries[2] = address(13);

        vault.createAfore{value: _amountEth}(
            cliffTimestamp,
            endTimestamp,
            _pensionPercent,
            safeWallet,
            beneficiaries
        );
        Afore memory _afore = vault.getAfore(0);

        // Expect this due 1:1 ETH and MPETH
        assertEq(_afore.mpEthBalance, _amountEth);
        assertEq(vault.getTotalAfores(), 1);
    }

    function testOracle() public {
        console.log(lp.convertMpEth2Usd(1 ether));
        console.log(230489902662);
        console.log("JOOOOSE");
        assertEq(lp.convertMpEth2Usd(1 ether), 230489902662);
    }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
