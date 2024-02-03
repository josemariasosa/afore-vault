// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../src/AforeVault.sol";
import "../src/mocks/Token.sol";
import "../src/mocks/MetaPoolETH.sol";
import "forge-std/Test.sol";

contract AforeTest is Test {

    // Timestamps
    uint256 startTimestamp;

    // Contracts
    AforeVault public vault;
    Token public usdc;
    MetaPoolETH public mpEth;
    Token public weth;

    address public safeWallet = address(10);

    function setUp() public {

        startTimestamp = block.timestamp;


        usdc = new Token("Stable coin", "USDC");
        weth = new Token("Wrapped ETH", "wETH");
        mpEth = new MetaPoolETH(IERC20(weth), "Staked ETH", "mpETH");



        vault = new AforeVault(IMetaPoolETH(address(mpEth)));
    }

    function testCreateAfore(uint32 _pensionPercent) public {
        vm.assume(_pensionPercent <= 100000);

        uint256 cliffTimestamp = startTimestamp + 1 days;
        uint256 endTimestamp = cliffTimestamp + 30 days;

        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = address(11);
        beneficiaries[1] = address(12);
        beneficiaries[2] = address(13);

        vault.createAfore{value: 1.2424 ether}(
            cliffTimestamp,
            endTimestamp,
            _pensionPercent,
            safeWallet,
            beneficiaries
        );

        Afore memory _afore = vault.getAfore(0);
        // console.log(_afore);
        console.log(_afore.mpEthBalance);
        console.log("JOSE ACA");
    }

    // function testIncrement() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
