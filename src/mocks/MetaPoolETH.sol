// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MetaPoolETH is ERC4626 {
    constructor(IERC20 _weth, string memory _data, string memory _name) ERC4626(_weth) ERC20(_data, _name) {}

    function depositETH(address _receiver) public payable returns (uint256) {
        uint256 _shares = previewDeposit(msg.value);
        _deposit(msg.sender, _receiver, msg.value, _shares);
        return _shares;
    }

    function _deposit(
        address _caller,
        address _receiver,
        uint256 _assets,
        uint256 _shares
    ) internal override {
        _mint(_receiver, _shares);
        emit Deposit(_caller, _receiver, _assets, _shares);
    }
}