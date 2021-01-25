/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

interface IBSWAPApprove {
    function claimTokens(address token,address who,address dest,uint256 amount) external;
    function getBSWAPProxy() external view returns (address);
}
