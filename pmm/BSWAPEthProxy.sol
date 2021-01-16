/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {ReentrancyGuard} from "./library/ReentrancyGuard.sol";
import {SafeERC20} from "./library/SafeERC20.sol";
import {SafeMath} from "./library/SafeMath.sol";
import {IBSWAP} from "./interface/IBSWAP.sol";
import {IERC20} from "./interface/IERC20.sol";
import {IWETH} from "./interface/IWETH.sol";

interface IBSWAPFactory {
    function getBSWAP(address baseToken, address quoteToken) external view returns (address);
}

/**
 * @title BSWAP Eth Proxy
 * @author BSWAP Breeder
 *
 * @notice Handle ETH-WETH converting for users.
 */
contract BSWAPEthProxy is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public _BSWAP_FACTORY_;
    address payable public _WETH_;

    // ============ Events ============

    event ProxySellEthToToken(
        address indexed seller,
        address indexed quoteToken,
        uint256 payEth,
        uint256 receiveToken
    );

    event ProxyBuyEthWithToken(
        address indexed buyer,
        address indexed quoteToken,
        uint256 receiveEth,
        uint256 payToken
    );

    event ProxySellTokenToEth(
        address indexed seller,
        address indexed baseToken,
        uint256 payToken,
        uint256 receiveEth
    );

    event ProxyBuyTokenWithEth(
        address indexed buyer,
        address indexed baseToken,
        uint256 receiveToken,
        uint256 payEth
    );

    event ProxyDepositEthAsBase(address indexed lp, address indexed BSWAP, uint256 ethAmount);

    event ProxyWithdrawEthAsBase(address indexed lp, address indexed BSWAP, uint256 ethAmount);

    event ProxyDepositEthAsQuote(address indexed lp, address indexed BSWAP, uint256 ethAmount);

    event ProxyWithdrawEthAsQuote(address indexed lp, address indexed BSWAP, uint256 ethAmount);

    // ============ Functions ============

    constructor(address bswapFactory, address payable weth) public {
        _BSWAP_FACTORY_ = bswapFactory;
        _WETH_ = weth;
    }

    fallback() external payable {
        require(msg.sender == _WETH_, "WE_SAVED_YOUR_ETH_:)");
    }

    receive() external payable {
        require(msg.sender == _WETH_, "WE_SAVED_YOUR_ETH_:)");
    }

    function sellEthToToken(
        address quoteTokenAddress,
        uint256 ethAmount,
        uint256 minReceiveTokenAmount
    ) external payable preventReentrant returns (uint256 receiveTokenAmount) {
        require(msg.value == ethAmount, "ETH_AMOUNT_NOT_MATCH");
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(_WETH_, quoteTokenAddress);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        IWETH(_WETH_).deposit{value: ethAmount}();
        IWETH(_WETH_).approve(BSWAP, ethAmount);
        receiveTokenAmount = IBSWAP(BSWAP).sellBaseToken(ethAmount, minReceiveTokenAmount, "");
        _transferOut(quoteTokenAddress, msg.sender, receiveTokenAmount);
        emit ProxySellEthToToken(msg.sender, quoteTokenAddress, ethAmount, receiveTokenAmount);
        return receiveTokenAmount;
    }

    function buyEthWithToken(
        address quoteTokenAddress,
        uint256 ethAmount,
        uint256 maxPayTokenAmount
    ) external preventReentrant returns (uint256 payTokenAmount) {
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(_WETH_, quoteTokenAddress);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        payTokenAmount = IBSWAP(BSWAP).queryBuyBaseToken(ethAmount);
        _transferIn(quoteTokenAddress, msg.sender, payTokenAmount);
        IERC20(quoteTokenAddress).safeApprove(BSWAP, payTokenAmount);
        IBSWAP(BSWAP).buyBaseToken(ethAmount, maxPayTokenAmount, "");
        IWETH(_WETH_).withdraw(ethAmount);
        msg.sender.transfer(ethAmount);
        emit ProxyBuyEthWithToken(msg.sender, quoteTokenAddress, ethAmount, payTokenAmount);
        return payTokenAmount;
    }

    function sellTokenToEth(
        address baseTokenAddress,
        uint256 tokenAmount,
        uint256 minReceiveEthAmount
    ) external preventReentrant returns (uint256 receiveEthAmount) {
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(baseTokenAddress, _WETH_);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        IERC20(baseTokenAddress).safeApprove(BSWAP, tokenAmount);
        _transferIn(baseTokenAddress, msg.sender, tokenAmount);
        receiveEthAmount = IBSWAP(BSWAP).sellBaseToken(tokenAmount, minReceiveEthAmount, "");
        IWETH(_WETH_).withdraw(receiveEthAmount);
        msg.sender.transfer(receiveEthAmount);
        emit ProxySellTokenToEth(msg.sender, baseTokenAddress, tokenAmount, receiveEthAmount);
        return receiveEthAmount;
    }

    function buyTokenWithEth(
        address baseTokenAddress,
        uint256 tokenAmount,
        uint256 maxPayEthAmount
    ) external payable preventReentrant returns (uint256 payEthAmount) {
        require(msg.value == maxPayEthAmount, "ETH_AMOUNT_NOT_MATCH");
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(baseTokenAddress, _WETH_);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        payEthAmount = IBSWAP(BSWAP).queryBuyBaseToken(tokenAmount);
        IWETH(_WETH_).deposit{value: payEthAmount}();
        IWETH(_WETH_).approve(BSWAP, payEthAmount);
        IBSWAP(BSWAP).buyBaseToken(tokenAmount, maxPayEthAmount, "");
        _transferOut(baseTokenAddress, msg.sender, tokenAmount);
        uint256 refund = maxPayEthAmount.sub(payEthAmount);
        if (refund > 0) {
            msg.sender.transfer(refund);
        }
        emit ProxyBuyTokenWithEth(msg.sender, baseTokenAddress, tokenAmount, payEthAmount);
        return payEthAmount;
    }

    function depositEthAsBase(uint256 ethAmount, address quoteTokenAddress)
        external
        payable
        preventReentrant
    {
        require(msg.value == ethAmount, "ETH_AMOUNT_NOT_MATCH");
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(_WETH_, quoteTokenAddress);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        IWETH(_WETH_).deposit{value: ethAmount}();
        IWETH(_WETH_).approve(BSWAP, ethAmount);
        IBSWAP(BSWAP).depositBaseTo(msg.sender, ethAmount);
        emit ProxyDepositEthAsBase(msg.sender, BSWAP, ethAmount);
    }

    function withdrawEthAsBase(uint256 ethAmount, address quoteTokenAddress)
        external
        preventReentrant
        returns (uint256 withdrawAmount)
    {
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(_WETH_, quoteTokenAddress);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        address ethLpToken = IBSWAP(BSWAP)._BASE_CAPITAL_TOKEN_();

        // transfer all pool shares to proxy
        uint256 lpBalance = IERC20(ethLpToken).balanceOf(msg.sender);
        IERC20(ethLpToken).transferFrom(msg.sender, address(this), lpBalance);
        IBSWAP(BSWAP).withdrawBase(ethAmount);

        // transfer remain shares back to msg.sender
        lpBalance = IERC20(ethLpToken).balanceOf(address(this));
        IERC20(ethLpToken).transfer(msg.sender, lpBalance);

        // because of withdraw penalty, withdrawAmount may not equal to ethAmount
        // query weth amount first and than transfer ETH to msg.sender
        uint256 wethAmount = IERC20(_WETH_).balanceOf(address(this));
        IWETH(_WETH_).withdraw(wethAmount);
        msg.sender.transfer(wethAmount);
        emit ProxyWithdrawEthAsBase(msg.sender, BSWAP, wethAmount);
        return wethAmount;
    }

    function withdrawAllEthAsBase(address quoteTokenAddress)
        external
        preventReentrant
        returns (uint256 withdrawAmount)
    {
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(_WETH_, quoteTokenAddress);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        address ethLpToken = IBSWAP(BSWAP)._BASE_CAPITAL_TOKEN_();

        // transfer all pool shares to proxy
        uint256 lpBalance = IERC20(ethLpToken).balanceOf(msg.sender);
        IERC20(ethLpToken).transferFrom(msg.sender, address(this), lpBalance);
        IBSWAP(BSWAP).withdrawAllBase();

        // because of withdraw penalty, withdrawAmount may not equal to ethAmount
        // query weth amount first and than transfer ETH to msg.sender
        uint256 wethAmount = IERC20(_WETH_).balanceOf(address(this));
        IWETH(_WETH_).withdraw(wethAmount);
        msg.sender.transfer(wethAmount);
        emit ProxyWithdrawEthAsBase(msg.sender, BSWAP, wethAmount);
        return wethAmount;
    }

    function depositEthAsQuote(uint256 ethAmount, address baseTokenAddress)
        external
        payable
        preventReentrant
    {
        require(msg.value == ethAmount, "ETH_AMOUNT_NOT_MATCH");
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(baseTokenAddress, _WETH_);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        IWETH(_WETH_).deposit{value: ethAmount}();
        IWETH(_WETH_).approve(BSWAP, ethAmount);
        IBSWAP(BSWAP).depositQuoteTo(msg.sender, ethAmount);
        emit ProxyDepositEthAsQuote(msg.sender, BSWAP, ethAmount);
    }

    function withdrawEthAsQuote(uint256 ethAmount, address baseTokenAddress)
        external
        preventReentrant
        returns (uint256 withdrawAmount)
    {
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(baseTokenAddress, _WETH_);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        address ethLpToken = IBSWAP(BSWAP)._QUOTE_CAPITAL_TOKEN_();

        // transfer all pool shares to proxy
        uint256 lpBalance = IERC20(ethLpToken).balanceOf(msg.sender);
        IERC20(ethLpToken).transferFrom(msg.sender, address(this), lpBalance);
        IBSWAP(BSWAP).withdrawQuote(ethAmount);

        // transfer remain shares back to msg.sender
        lpBalance = IERC20(ethLpToken).balanceOf(address(this));
        IERC20(ethLpToken).transfer(msg.sender, lpBalance);

        // because of withdraw penalty, withdrawAmount may not equal to ethAmount
        // query weth amount first and than transfer ETH to msg.sender
        uint256 wethAmount = IERC20(_WETH_).balanceOf(address(this));
        IWETH(_WETH_).withdraw(wethAmount);
        msg.sender.transfer(wethAmount);
        emit ProxyWithdrawEthAsQuote(msg.sender, BSWAP, wethAmount);
        return wethAmount;
    }

    function withdrawAllEthAsQuote(address baseTokenAddress)
        external
        preventReentrant
        returns (uint256 withdrawAmount)
    {
        address BSWAP = IBSWAPFactory(_BSWAP_FACTORY_).getBSWAP(baseTokenAddress, _WETH_);
        require(BSWAP != address(0), "BSWAP_NOT_EXIST");
        address ethLpToken = IBSWAP(BSWAP)._QUOTE_CAPITAL_TOKEN_();

        // transfer all pool shares to proxy
        uint256 lpBalance = IERC20(ethLpToken).balanceOf(msg.sender);
        IERC20(ethLpToken).transferFrom(msg.sender, address(this), lpBalance);
        IBSWAP(BSWAP).withdrawAllQuote();

        // because of withdraw penalty, withdrawAmount may not equal to ethAmount
        // query weth amount first and than transfer ETH to msg.sender
        uint256 wethAmount = IERC20(_WETH_).balanceOf(address(this));
        IWETH(_WETH_).withdraw(wethAmount);
        msg.sender.transfer(wethAmount);
        emit ProxyWithdrawEthAsQuote(msg.sender, BSWAP, wethAmount);
        return wethAmount;
    }

    // ============ Helper Functions ============

    function _transferIn(
        address tokenAddress,
        address from,
        uint256 amount
    ) internal {
        IERC20(tokenAddress).safeTransferFrom(from, address(this), amount);
    }

    function _transferOut(
        address tokenAddress,
        address to,
        uint256 amount
    ) internal {
        IERC20(tokenAddress).safeTransfer(to, amount);
    }
}
