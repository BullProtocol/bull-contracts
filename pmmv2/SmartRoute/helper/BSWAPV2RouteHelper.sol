/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {IBSWAPV2} from "../intf/IBSWAPV2.sol";

contract BSWAPV2RouteHelper {
    address public immutable _DVM_FACTORY_;
    address public immutable _BPP_FACTORY_;

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

    constructor(address dvmFactory,address bppFactory) public {
        _DVM_FACTORY_ = dvmFactory;
        _BPP_FACTORY_ = bppFactory;
    }

    function getPairDetail(address token0,address token1,address userAddr) external view returns (PairDetail[] memory res) {
        (address[] memory baseToken0DVM, address[] memory baseToken1DVM) = IBSWAPV2(_DVM_FACTORY_).getBSWAPPoolBidirection(token0,token1);
        (address[] memory baseToken0BPP, address[] memory baseToken1BPP) = IBSWAPV2(_BPP_FACTORY_).getBSWAPPoolBidirection(token0,token1);
        uint256 len = baseToken0DVM.length + baseToken1DVM.length + baseToken0BPP.length + baseToken1BPP.length;
        res = new PairDetail[](len);
        for(uint8 i = 0; i < len; i++) {
            PairDetail memory curRes = PairDetail(0,0,0,0,0,0,0,0,0,address(0),address(0),address(0),2);
            address cur;
            if(i < baseToken0DVM.length) {
                cur = baseToken0DVM[i];
                curRes.baseToken = token0;
                curRes.quoteToken = token1;
            } else if(i < baseToken0DVM.length + baseToken1DVM.length) {
                cur = baseToken1DVM[i - baseToken0DVM.length];
                curRes.baseToken = token1;
                curRes.quoteToken = token0;
            } else if(i < baseToken0DVM.length + baseToken1DVM.length + baseToken0BPP.length) {
                cur = baseToken0BPP[i - baseToken0DVM.length - baseToken1DVM.length];
                curRes.baseToken = token0;
                curRes.quoteToken = token1;
            } else {
                cur = baseToken1BPP[i - baseToken0DVM.length - baseToken1DVM.length - baseToken0BPP.length];
                curRes.baseToken = token1;
                curRes.quoteToken = token0;
            }

            (            
                curRes.i,
                curRes.K,
                curRes.B,
                curRes.Q,
                curRes.B0,
                curRes.Q0,
                curRes.R
            ) = IBSWAPV2(cur).getPMMStateForCall();

            (curRes.lpFeeRate, curRes.mtFeeRate) = IBSWAPV2(cur).getUserFeeRate(userAddr);
            curRes.curPair = cur;
            res[i] = curRes;
        }
    }
}