// SPDX-License-Identifier: MIT

/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity ^0.6.9;
pragma experimental ABIEncoderV2;


interface IBSWAPLpToken {
    function mint(address user, uint256 value) external;

    function burn(address user, uint256 value) external;

    function balanceOf(address owner) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
