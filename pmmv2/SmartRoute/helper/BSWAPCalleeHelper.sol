/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {IBSWAPV2} from "../intf/IBSWAPV2.sol";
import {IERC20} from "../../intf/IERC20.sol";
import {IWETH} from "../../intf/IWETH.sol";
import {SafeERC20} from "../../lib/SafeERC20.sol";
import {ReentrancyGuard} from "../../lib/ReentrancyGuard.sol";

contract BSWAPCalleeHelper is ReentrancyGuard {
    using SafeERC20 for IERC20;
    address payable public immutable _WETH_;

    fallback() external payable {
        require(msg.sender == _WETH_, "WE_SAVED_YOUR_ETH");
    }

    receive() external payable {
        require(msg.sender == _WETH_, "WE_SAVED_YOUR_ETH");
    }

    constructor(address payable weth) public {
        _WETH_ = weth;
    }

    function BVMSellShareCall(
        address payable assetTo,
        uint256,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata
    ) external preventReentrant {
        address _baseToken = IBSWAPV2(msg.sender)._BASE_TOKEN_();
        address _quoteToken = IBSWAPV2(msg.sender)._QUOTE_TOKEN_();
        _withdraw(assetTo, _baseToken, baseAmount, _baseToken == _WETH_);
        _withdraw(assetTo, _quoteToken, quoteAmount, _quoteToken == _WETH_);
    }

    function CPCancelCall(
        address payable assetTo,
        uint256 amount,
        bytes calldata
    )external preventReentrant{
        address _quoteToken = IBSWAPV2(msg.sender)._QUOTE_TOKEN_();
        _withdraw(assetTo, _quoteToken, amount, _quoteToken == _WETH_);
    }

	function CPClaimBidCall(
        address payable assetTo,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata
    ) external preventReentrant {
        address _baseToken = IBSWAPV2(msg.sender)._BASE_TOKEN_();
        address _quoteToken = IBSWAPV2(msg.sender)._QUOTE_TOKEN_();
        _withdraw(assetTo, _baseToken, baseAmount, _baseToken == _WETH_);
        _withdraw(assetTo, _quoteToken, quoteAmount, _quoteToken == _WETH_);
    }

    function _withdraw(
        address payable to,
        address token,
        uint256 amount,
        bool isETH
    ) internal {
        if (isETH) {
            if (amount > 0) {
                IWETH(_WETH_).withdraw(amount);
                to.transfer(amount);
            }
        } else {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        }
    }
}
