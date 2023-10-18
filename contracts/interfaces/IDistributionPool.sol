// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDistributionPool {
    function claim(address user, uint256 _pid, uint256 rewards) external;
}