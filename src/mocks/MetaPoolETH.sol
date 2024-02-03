// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MetaPoolETH is ERC4626 {
    constructor(IERC20 _weth) ERC4626(_weth) ERC20("MetaPoolETH", "mpETH") {}
}