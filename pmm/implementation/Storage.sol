/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {InitializableOwnable} from "../library/InitializableOwnable.sol";
import {SafeMath} from "../library/SafeMath.sol";
import {DecimalMath} from "../library/DecimalMath.sol";
import {ReentrancyGuard} from "../library/ReentrancyGuard.sol";
import {IOracle} from "../interface/IOracle.sol";
import {IBSWAPLpToken} from "../interface/IBSWAPLpToken.sol";
import {Types} from "../library/Types.sol";


/**
 * @title Storage
 * @author BSWAP Breeder
 *
 * @notice Local Variables
 */
contract Storage is InitializableOwnable, ReentrancyGuard {
    using SafeMath for uint256;

    // ============ Variables for Control ============

    bool internal _INITIALIZED_;
    bool public _CLOSED_;
    bool public _DEPOSIT_QUOTE_ALLOWED_;
    bool public _DEPOSIT_BASE_ALLOWED_;
    bool public _TRADE_ALLOWED_;
    uint256 public _GAS_PRICE_LIMIT_;

    // ============ Advanced Controls ============
    bool public _BUYING_ALLOWED_;
    bool public _SELLING_ALLOWED_;
    uint256 public _BASE_BALANCE_LIMIT_;
    uint256 public _QUOTE_BALANCE_LIMIT_;

    // ============ Core Address ============

    address public _SUPERVISOR_; // could freeze system in emergency
    address public _MAINTAINER_; // collect maintainer fee to buy food for BSWAP

    address public _BASE_TOKEN_;
    address public _QUOTE_TOKEN_;
    address public _ORACLE_;

    // ============ Variables for PMM Algorithm ============

    uint256 public _LP_FEE_RATE_;
    uint256 public _MT_FEE_RATE_;
    uint256 public _K_;

    Types.RStatus public _R_STATUS_;
    uint256 public _TARGET_BASE_TOKEN_AMOUNT_;
    uint256 public _TARGET_QUOTE_TOKEN_AMOUNT_;
    uint256 public _BASE_BALANCE_;
    uint256 public _QUOTE_BALANCE_;

    address public _BASE_CAPITAL_TOKEN_;
    address public _QUOTE_CAPITAL_TOKEN_;

    // ============ Variables for Final Settlement ============

    uint256 public _BASE_CAPITAL_RECEIVE_QUOTE_;
    uint256 public _QUOTE_CAPITAL_RECEIVE_BASE_;
    mapping(address => bool) public _CLAIMED_;

    // ============ Modifiers ============

    modifier onlySupervisorOrOwner() {
        require(msg.sender == _SUPERVISOR_ || msg.sender == _OWNER_, "NOT_SUPERVISOR_OR_OWNER");
        _;
    }

    modifier notClosed() {
        require(!_CLOSED_, "BSWAP_CLOSED");
        _;
    }

    // ============ Helper Functions ============

    function _checkBSWAPParameters() internal view returns (uint256) {
        require(_K_ < DecimalMath.ONE, "K>=1");
        require(_K_ > 0, "K=0");
        require(_LP_FEE_RATE_.add(_MT_FEE_RATE_) < DecimalMath.ONE, "FEE_RATE>=1");
    }

    function getOraclePrice() public view returns (uint256) {
        return IOracle(_ORACLE_).getPrice();
    }

    function getBaseCapitalBalanceOf(address lp) public view returns (uint256) {
        return IBSWAPLpToken(_BASE_CAPITAL_TOKEN_).balanceOf(lp);
    }

    function getTotalBaseCapital() public view returns (uint256) {
        return IBSWAPLpToken(_BASE_CAPITAL_TOKEN_).totalSupply();
    }

    function getQuoteCapitalBalanceOf(address lp) public view returns (uint256) {
        return IBSWAPLpToken(_QUOTE_CAPITAL_TOKEN_).balanceOf(lp);
    }

    function getTotalQuoteCapital() public view returns (uint256) {
        return IBSWAPLpToken(_QUOTE_CAPITAL_TOKEN_).totalSupply();
    }

    // ============ Version Control ============
    function version() external pure returns (uint256) {
        return 101; // 1.0.1
    }
}
