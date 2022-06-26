// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
