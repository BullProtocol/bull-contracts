/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;

import {IERC20} from "../intf/IERC20.sol";
import {UniversalERC20} from "./lib/UniversalERC20.sol";
import {SafeMath} from "../lib/SafeMath.sol";
import {IBSWAPV1} from "./intf/IBSWAPV1.sol";
import {IBSWAPSellHelper} from "./helper/BSWAPSellHelper.sol";
import {IWETH} from "../intf/IWETH.sol";
import {IChi} from "./intf/IChi.sol";
import {IUni} from "./intf/IUni.sol";
import {IBSWAPApprove} from "../intf/IBSWAPApprove.sol";
import {IBSWAPV1Proxy02} from "./intf/IBSWAPV1Proxy02.sol";
import {InitializableOwnable} from "../lib/InitializableOwnable.sol";

/**
 * @title BSWAPV1Proxy03
 * @author BSWAP Breeder
 *
 * @notice Entrance of trading in BSWAP platform
 */
contract BSWAPV1Proxy03 is IBSWAPV1Proxy02, InitializableOwnable {
    using SafeMath for uint256;
    using UniversalERC20 for IERC20;

    // ============ Storage ============

    address constant _ETH_ADDRESS_ = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable _BSWAP_APPROVE_;
    address public immutable _BSWAP_SELL_HELPER_;
    address public immutable _WETH_;
    address public immutable _CHI_TOKEN_;
    uint256 public _GAS_BSWAP_MAX_RETURN_ = 10;
    uint256 public _GAS_EXTERNAL_RETURN_ = 5;
    mapping (address => bool) public isWhiteListed;

    // ============ Events ============

    event OrderHistory(
        address indexed fromToken,
        address indexed toToken,
        address indexed sender,
        uint256 fromAmount,
        uint256 returnAmount
    );

    // ============ Modifiers ============

    modifier judgeExpired(uint256 deadLine) {
        require(deadLine >= block.timestamp, "BSWAPV1Proxy03: EXPIRED");
        _;
    }

    constructor(
        address bswapApporve,
        address bswapSellHelper,
        address weth,
        address chiToken
    ) public {
        _BSWAP_APPROVE_ = bswapApporve;
        _BSWAP_SELL_HELPER_ = bswapSellHelper;
        _WETH_ = weth;
        _CHI_TOKEN_ = chiToken;
    }

    fallback() external payable {}

    receive() external payable {}

    function updateGasReturn(uint256 newBSwapGasReturn, uint256 newExternalGasReturn) public onlyOwner {
        _GAS_BSWAP_MAX_RETURN_ = newBSwapGasReturn;
        _GAS_EXTERNAL_RETURN_ = newExternalGasReturn;
    }

    function addWhiteList (address contractAddr) public onlyOwner {
        isWhiteListed[contractAddr] = true;
    }

    function removeWhiteList (address contractAddr) public onlyOwner {
        isWhiteListed[contractAddr] = false;
    }

    function bswapSwapV1(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory bswapPairs,
        uint256 directions,
        uint256 deadLine
    ) external override payable judgeExpired(deadLine) returns (uint256 returnAmount) {
        require(bswapPairs.length > 0, "BSWAPV1Proxy03: PAIRS_EMPTY");
        require(minReturnAmount > 0, "BSWAPV1Proxy03: RETURN_AMOUNT_ZERO");
        require(fromToken != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_SELL_CHI");
        require(toToken != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_BUY_CHI");

        uint256 originGas = gasleft();

        if (fromToken != _ETH_ADDRESS_) {
            IBSWAPApprove(_BSWAP_APPROVE_).claimTokens(
                fromToken,
                msg.sender,
                address(this),
                fromTokenAmount
            );
        } else {
            require(msg.value == fromTokenAmount, "BSWAPV1Proxy03: ETH_AMOUNT_NOT_MATCH");
            IWETH(_WETH_).deposit{value: fromTokenAmount}();
        }

        for (uint256 i = 0; i < bswapPairs.length; i++) {
            address curBSwapPair = bswapPairs[i];
            if (directions & 1 == 0) {
                address curBSwapBase = IBSWAPV1(curBSwapPair)._BASE_TOKEN_();
                require(curBSwapBase != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_CHI");
                uint256 curAmountIn = IERC20(curBSwapBase).balanceOf(address(this));
                IERC20(curBSwapBase).universalApproveMax(curBSwapPair, curAmountIn);
                IBSWAPV1(curBSwapPair).sellBaseToken(curAmountIn, 0, "");
            } else {
                address curBSwapQuote = IBSWAPV1(curBSwapPair)._QUOTE_TOKEN_();
                require(curBSwapQuote != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_CHI");
                uint256 curAmountIn = IERC20(curBSwapQuote).balanceOf(address(this));
                IERC20(curBSwapQuote).universalApproveMax(curBSwapPair, curAmountIn);
                uint256 canBuyBaseAmount = IBSWAPSellHelper(_BSWAP_SELL_HELPER_).querySellQuoteToken(
                    curBSwapPair,
                    curAmountIn
                );
                IBSWAPV1(curBSwapPair).buyBaseToken(canBuyBaseAmount, curAmountIn, "");
            }
            directions = directions >> 1;
        }

        if (toToken == _ETH_ADDRESS_) {
            returnAmount = IWETH(_WETH_).balanceOf(address(this));
            IWETH(_WETH_).withdraw(returnAmount);
        } else {
            returnAmount = IERC20(toToken).tokenBalanceOf(address(this));
        }
        
        require(returnAmount >= minReturnAmount, "BSWAPV1Proxy03: Return amount is not enough");
        IERC20(toToken).universalTransfer(msg.sender, returnAmount);
        
        emit OrderHistory(fromToken, toToken, msg.sender, fromTokenAmount, returnAmount);
        
        uint256 _gasBSwapMaxReturn = _GAS_BSWAP_MAX_RETURN_;
        if(_gasBSwapMaxReturn > 0) {
            uint256 calcGasTokenBurn = originGas.sub(gasleft()) / 65000;
            uint256 gasTokenBurn = calcGasTokenBurn > _gasBSwapMaxReturn ? _gasBSwapMaxReturn : calcGasTokenBurn;
            if(gasleft() > 27710 + gasTokenBurn * 6080)
                IChi(_CHI_TOKEN_).freeUpTo(gasTokenBurn);
        }
    }

    function externalSwap(
        address fromToken,
        address toToken,
        address approveTarget,
        address swapTarget,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        bytes memory callDataConcat,
        uint256 deadLine
    ) external override payable judgeExpired(deadLine) returns (uint256 returnAmount) {
        require(minReturnAmount > 0, "BSWAPV1Proxy03: RETURN_AMOUNT_ZERO");
        require(fromToken != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_SELL_CHI");
        require(toToken != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_BUY_CHI");

        address _fromToken = fromToken;
        address _toToken = toToken;
        
        uint256 toTokenOriginBalance = IERC20(_toToken).universalBalanceOf(msg.sender);

        if (_fromToken != _ETH_ADDRESS_) {
            IBSWAPApprove(_BSWAP_APPROVE_).claimTokens(
                _fromToken,
                msg.sender,
                address(this),
                fromTokenAmount
            );
            IERC20(_fromToken).universalApproveMax(approveTarget, fromTokenAmount);
        }

        require(isWhiteListed[swapTarget], "BSWAPV1Proxy03: Not Whitelist Contract");
        (bool success, ) = swapTarget.call{value: _fromToken == _ETH_ADDRESS_ ? msg.value : 0}(callDataConcat);

        require(success, "BSWAPV1Proxy03: External Swap execution Failed");

        IERC20(_toToken).universalTransfer(
            msg.sender,
            IERC20(_toToken).universalBalanceOf(address(this))
        );
        returnAmount = IERC20(_toToken).universalBalanceOf(msg.sender).sub(toTokenOriginBalance);
        require(returnAmount >= minReturnAmount, "BSWAPV1Proxy03: Return amount is not enough");

        emit OrderHistory(_fromToken, _toToken, msg.sender, fromTokenAmount, returnAmount);
        
        uint256 _gasExternalReturn = _GAS_EXTERNAL_RETURN_;
        if(_gasExternalReturn > 0) {
            if(gasleft() > 27710 + _gasExternalReturn * 6080)
                IChi(_CHI_TOKEN_).freeUpTo(_gasExternalReturn);
        }
    }


    function mixSwapV1(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        uint256 minReturnAmount,
        address[] memory mixPairs,
        uint256[] memory directions,
        address[] memory portionPath,
        uint256 deadLine
    ) external override payable judgeExpired(deadLine) returns (uint256 returnAmount) {
        require(mixPairs.length == directions.length, "BSWAPV1Proxy03: PARAMS_LENGTH_NOT_MATCH");
        require(mixPairs.length > 0, "BSWAPV1Proxy03: PAIRS_EMPTY");
        require(minReturnAmount > 0, "BSWAPV1Proxy03: RETURN_AMOUNT_ZERO");
        require(fromToken != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_SELL_CHI");
        require(toToken != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_BUY_CHI");

        uint256 toTokenOriginBalance = IERC20(toToken).universalBalanceOf(msg.sender);

        if (fromToken != _ETH_ADDRESS_) {
            IBSWAPApprove(_BSWAP_APPROVE_).claimTokens(
                fromToken,
                msg.sender,
                address(this),
                fromTokenAmount
            );
        } else {
            require(msg.value == fromTokenAmount, "BSWAPV1Proxy03: ETH_AMOUNT_NOT_MATCH");
            IWETH(_WETH_).deposit{value: fromTokenAmount}();
        }

        for (uint256 i = 0; i < mixPairs.length; i++) {
            address curPair = mixPairs[i];
            if (directions[i] == 0) {
                address curBSwapBase = IBSWAPV1(curPair)._BASE_TOKEN_();
                require(curBSwapBase != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_CHI");
                uint256 curAmountIn = IERC20(curBSwapBase).balanceOf(address(this));
                IERC20(curBSwapBase).universalApproveMax(curPair, curAmountIn);
                IBSWAPV1(curPair).sellBaseToken(curAmountIn, 0, "");
            } else if(directions[i] == 1){
                address curBSwapQuote = IBSWAPV1(curPair)._QUOTE_TOKEN_();
                require(curBSwapQuote != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_CHI");
                uint256 curAmountIn = IERC20(curBSwapQuote).balanceOf(address(this));
                IERC20(curBSwapQuote).universalApproveMax(curPair, curAmountIn);
                uint256 canBuyBaseAmount = IBSWAPSellHelper(_BSWAP_SELL_HELPER_).querySellQuoteToken(
                    curPair,
                    curAmountIn
                );
                IBSWAPV1(curPair).buyBaseToken(canBuyBaseAmount, curAmountIn, "");
            } else {
                require(portionPath[0] != _CHI_TOKEN_, "BSWAPV1Proxy03: NOT_SUPPORT_CHI");
                uint256 curAmountIn = IERC20(portionPath[0]).balanceOf(address(this));
                IERC20(portionPath[0]).universalApproveMax(curPair, curAmountIn);
                IUni(curPair).swapExactTokensForTokens(curAmountIn,0,portionPath,address(this),deadLine);
            }
        }

        IERC20(toToken).universalTransfer(
            msg.sender,
            IERC20(toToken).universalBalanceOf(address(this))
        );

        returnAmount = IERC20(toToken).universalBalanceOf(msg.sender).sub(toTokenOriginBalance);
        require(returnAmount >= minReturnAmount, "BSWAPV1Proxy03: Return amount is not enough");

        emit OrderHistory(fromToken, toToken, msg.sender, fromTokenAmount, returnAmount);
        
        uint256 _gasExternalReturn = _GAS_EXTERNAL_RETURN_;
        if(_gasExternalReturn > 0) {
            if(gasleft() > 27710 + _gasExternalReturn * 6080)
                IChi(_CHI_TOKEN_).freeUpTo(_gasExternalReturn);
        }
    }
}
