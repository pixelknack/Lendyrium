// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LendyriumGovernanceToken is ERC20 {
    constructor() ERC20("LendyriumGovernanceToken", "LGT") {
        _mint(msg.sender, 1000000 * 10 ** decimals()); // 1 million tokens
    }
}