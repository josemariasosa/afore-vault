// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../src/AforeVault.sol";
import "../src/mocks/Token.sol";
import "forge-std/Test.sol";

contract AforeTest is Test {

    // Timestamps
    uint256 startTimestamp;

    // Contracts
    AforeVault public afore;
    Token public usdc;
    Token public mpEth;

    address public safeWallet = address(10);

    function setUp(uint32 _pensionPercent) public {
        vm.assume(_pensionPercent <= 100000);

        startTimestamp = block.timestamp;
        uint256 cliffTimestamp = startTimestamp + 1 days;
        uint256 endTimestamp = cliffTimestamp + 30 days;

        usdc = new Token("Stable coin", "USDC");
        mpEth = new Token("Staked ETH", "mpETH");

        address[] memory beneficiaries = new address[](3);
        beneficiaries[0] = address(11);
        beneficiaries[1] = address(12);
        beneficiaries[2] = address(13);

        IERC20[] memory erc20s = new IERC20[](2);
        erc20s[0] = IERC20(usdc);
        erc20s[0] = IERC20(mpEth);

        afore = new AforeVault(
            uint32(cliffTimestamp),
            uint32(endTimestamp),
            _pensionPercent,
            safeWallet,
            beneficiaries,
            erc20s
        );
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
