/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {Ownable} from "../../lib/Ownable.sol";
import {IMemSource} from "./MemAggregator.sol";
import {IERC20} from "../../intf/IERC20.sol";

contract MemSourceHold is Ownable, IMemSource {
    address public _BSWAP_TOKEN_;

    constructor(address bswapToken) public {
        _BSWAP_TOKEN_ = bswapToken;
    }

    // ============ View Function ============

    function getMemLevel(address user) external override returns (uint256) {
        return IERC20(_BSWAP_TOKEN_).balanceOf(user);
    }
}
