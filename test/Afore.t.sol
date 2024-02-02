// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "../src/Afore.sol";
import "../src/mocks/Token.sol";
import "ds-test/test.sol";
import "forge-std/Test.sol";
import "forge-std/VM.sol";

contract AforeTest is Test, DSTest {
    Vm vm = Vm(HEVM_ADDRESS);
    TimeBasedMessage timeBasedMessage;

    // Timestamps
    uint32 startTimestamp;

    Afore public afore;
    Token public usdc;
    Token public mpEth;

    address public safeWallet = address(10);

    function setUp(uint32 _pensionPercent) public {
        timeBasedMessage = new TimeBasedMessage();
        startTimestamp = block.timestamp;
        cliffTimestamp = startTimestamp + 1 days;
        endTimestamp = cliffTimestamp + 30 days;


        usdc = new Token("Stable coin", "USDC");
        mpEth = new Token("Staked ETH", "mpETH");
        afore = new Afore(
            cliffTimestamp,
            endTimestamp,
            _pensionPercent,
            safeWallet,
            [address(11), address(12), address(13)],
            [address(usdc), address(mpEth)]
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
