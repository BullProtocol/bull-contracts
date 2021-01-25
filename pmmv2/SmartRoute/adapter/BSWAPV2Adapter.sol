/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;

import {IBSWAPV2} from "../intf/IBSWAPV2.sol";
import {IBSWAPAdapter} from "../intf/IBSWAPAdapter.sol";

contract BSWAPV2Adapter is IBSWAPAdapter {
    function sellBase(address to, address pool) external override {
        IBSWAPV2(pool).sellBase(to);
    }

    function sellQuote(address to, address pool) external override {
        IBSWAPV2(pool).sellQuote(to);
    }
}