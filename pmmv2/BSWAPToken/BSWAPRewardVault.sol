/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {Ownable} from "../lib/Ownable.sol";
import {SafeERC20} from "../lib/SafeERC20.sol";
import {IERC20} from "../intf/IERC20.sol";


interface IBSWAPRewardVault {
    function reward(address to, uint256 amount) external;
}


contract BSWAPRewardVault is Ownable {
    using SafeERC20 for IERC20;

    address public bswapToken;

    constructor(address _bswapToken) public {
        bswapToken = _bswapToken;
    }

    function reward(address to, uint256 amount) external onlyOwner {
        IERC20(bswapToken).safeTransfer(to, amount);
    }
}
