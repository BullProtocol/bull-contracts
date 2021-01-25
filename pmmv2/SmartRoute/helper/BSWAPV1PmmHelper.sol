/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {IBSWAPV1} from "../intf/IBSWAPV1.sol";

contract BSWAPV1PmmHelper {
    
    struct PairDetail {
        uint256 i;
        uint256 K;
        uint256 B;
        uint256 Q;
        uint256 B0;
        uint256 Q0;
        uint256 R;
        uint256 lpFeeRate;
        uint256 mtFeeRate;
        address baseToken;
        address quoteToken;
        address curPair;
        uint256 pairVersion;
    }

    function getPairDetail(address pool) external view returns (PairDetail[] memory res) {
        res = new PairDetail[](1);
        PairDetail memory curRes = PairDetail(0,0,0,0,0,0,0,0,0,address(0),address(0),pool,1);
        curRes.i = IBSWAPV1(pool).getOraclePrice();
        curRes.K = IBSWAPV1(pool)._K_();
        curRes.B = IBSWAPV1(pool)._BASE_BALANCE_();
        curRes.Q = IBSWAPV1(pool)._QUOTE_BALANCE_();
        (curRes.B0,curRes.Q0) = IBSWAPV1(pool).getExpectedTarget();
        curRes.R = IBSWAPV1(pool)._R_STATUS_();
        curRes.lpFeeRate = IBSWAPV1(pool)._LP_FEE_RATE_();
        curRes.mtFeeRate = IBSWAPV1(pool)._MT_FEE_RATE_();
        curRes.baseToken = IBSWAPV1(pool)._BASE_TOKEN_();
        curRes.quoteToken =  IBSWAPV1(pool)._QUOTE_TOKEN_();
        res[0] = curRes;
    }
}