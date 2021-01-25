// SPDX-License-Identifier: MIT

/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {IBSWAP} from "../interface/IBSWAP.sol";
import {IERC20} from "../interface/IERC20.sol";
import {SafeMath} from "../library/SafeMath.sol";


interface IBSWAPMine {
    function getUserLpBalance(address _lpToken, address _user) external view returns (uint256);
}


contract BSWAPMineReader {
    using SafeMath for uint256;

    function getUserStakedBalance(
        address _bswapMine,
        address _bswap,
        address _user
    ) external view returns (uint256 baseBalance, uint256 quoteBalance) {
        address baseLpToken = IBSWAP(_bswap)._BASE_CAPITAL_TOKEN_();
        address quoteLpToken = IBSWAP(_bswap)._QUOTE_CAPITAL_TOKEN_();

        uint256 baseLpBalance = IBSWAPMine(_bswapMine).getUserLpBalance(baseLpToken, _user);
        uint256 quoteLpBalance = IBSWAPMine(_bswapMine).getUserLpBalance(quoteLpToken, _user);

        uint256 baseLpTotalSupply = IERC20(baseLpToken).totalSupply();
        uint256 quoteLpTotalSupply = IERC20(quoteLpToken).totalSupply();

        (uint256 baseTarget, uint256 quoteTarget) = IBSWAP(_bswap).getExpectedTarget();
        baseBalance = baseTarget.mul(baseLpBalance).div(baseLpTotalSupply);
        quoteBalance = quoteTarget.mul(quoteLpBalance).div(quoteLpTotalSupply);

        return (baseBalance, quoteBalance);
    }
}
