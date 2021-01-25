/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;

import {IBSWAPV1} from "../intf/IBSWAPV1.sol";
import {IBSWAPSellHelper} from "./BSWAPSellHelper.sol";

contract BSWAPSwapCalcHelper {
    address public immutable _BSWAP_SELL_HELPER_;

    constructor(address bswapSellHelper) public {
        _BSWAP_SELL_HELPER_ = bswapSellHelper;
    }

    function calcReturnAmountV1(
        uint256 fromTokenAmount,
        address[] memory bswapPairs,
        uint8[] memory directions
    ) external view returns (uint256 returnAmount,uint256[] memory midPrices,uint256[] memory feeRates) {
        returnAmount = fromTokenAmount;
        midPrices = new uint256[](bswapPairs.length);
        feeRates = new uint256[](bswapPairs.length);
        for (uint256 i = 0; i < bswapPairs.length; i++) {
            address curBSwapPair = bswapPairs[i];
            if (directions[i] == 0) {
                returnAmount = IBSWAPV1(curBSwapPair).querySellBaseToken(returnAmount);
            } else {
                returnAmount = IBSWAPSellHelper(_BSWAP_SELL_HELPER_).querySellQuoteToken(
                    curBSwapPair,
                    returnAmount
                );
            }
            midPrices[i] = IBSWAPV1(curBSwapPair).getMidPrice();
            feeRates[i] = IBSWAPV1(curBSwapPair)._MT_FEE_RATE_() + IBSWAPV1(curBSwapPair)._LP_FEE_RATE_();
        }        
    }
}