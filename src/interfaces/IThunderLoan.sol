// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IThunderLoan {
    // @audit-low- the pramaters are incorrect 
    function repay(address token, uint256 amount) external;
}
