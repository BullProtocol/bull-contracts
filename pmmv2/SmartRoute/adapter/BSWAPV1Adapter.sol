/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;

import {IERC20} from "../../intf/IERC20.sol";
import {IBSWAPV1} from "../intf/IBSWAPV1.sol";
import {IBSWAPSellHelper} from "../helper/BSWAPSellHelper.sol";
import {UniversalERC20} from "../lib/UniversalERC20.sol";
import {SafeMath} from "../../lib/SafeMath.sol";
import {IBSWAPAdapter} from "../intf/IBSWAPAdapter.sol";

contract BSWAPV1Adapter is IBSWAPAdapter {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;

    address public immutable _BSWAP_SELL_HELPER_;

    constructor(address bswapSellHelper) public {
        _BSWAP_SELL_HELPER_ = bswapSellHelper;
    }
    
    function sellBase(address to, address pool) external override {
        address curBase = IBSWAPV1(pool)._BASE_TOKEN_();
        uint256 curAmountIn = IERC20(curBase).balanceOf(address(this));
        IERC20(curBase).universalApproveMax(pool, curAmountIn);
        IBSWAPV1(pool).sellBaseToken(curAmountIn, 0, "");
        if(to != address(this)) {
            address curQuote = IBSWAPV1(pool)._QUOTE_TOKEN_();
            IERC20(curQuote).transfer(to,IERC20(curQuote).balanceOf(address(this)));
        }
    }

    function sellQuote(address to, address pool) external override {
        address curQuote = IBSWAPV1(pool)._QUOTE_TOKEN_();
        uint256 curAmountIn = IERC20(curQuote).balanceOf(address(this));
        IERC20(curQuote).universalApproveMax(pool, curAmountIn);
        uint256 canBuyBaseAmount = IBSWAPSellHelper(_BSWAP_SELL_HELPER_).querySellQuoteToken(
            pool,
            curAmountIn
        );
        IBSWAPV1(pool).buyBaseToken(canBuyBaseAmount, curAmountIn, "");
        if(to != address(this)) {
            address curBase = IBSWAPV1(pool)._BASE_TOKEN_();
            IERC20(curBase).transfer(to,IERC20(curBase).balanceOf(address(this)));
        }
    }
}