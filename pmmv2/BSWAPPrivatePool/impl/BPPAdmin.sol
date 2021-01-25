/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {IBPP} from "../intf/IBPP.sol";
import {IBSWAPApprove} from "../../intf/IBSWAPApprove.sol";
import {InitializableOwnable} from "../../lib/InitializableOwnable.sol";

/**
 * @title BPPAdmin
 * @author BSWAP Breeder
 *
 * @notice Admin of BSWAPPrivatePool
 */
contract BPPAdmin is InitializableOwnable {
    address public _BPP_;
    address public _OPERATOR_;
    address public _BSWAP_APPROVE_;
    uint256 public _FREEZE_TIMESTAMP_;


    modifier notFreezed() {
        require(block.timestamp >= _FREEZE_TIMESTAMP_, "ADMIN_FREEZED");
        _;
    }

    function init(
        address owner,
        address bpp,
        address operator,
        address bswapApprove
    ) external {
        initOwner(owner);
        _BPP_ = bpp;
        _OPERATOR_ = operator;
        _BSWAP_APPROVE_ = bswapApprove;
    }

    function sync() external notFreezed onlyOwner {
        IBPP(_BPP_).ratioSync();
    }

    function setFreezeTimestamp(uint256 timestamp) external notFreezed onlyOwner {
        _FREEZE_TIMESTAMP_ = timestamp;
    }

    function setOperator(address newOperator) external notFreezed onlyOwner {
        _OPERATOR_ = newOperator;
    }

    function retrieve(
        address payable to,
        address token,
        uint256 amount
    ) external notFreezed onlyOwner {
        IBPP(_BPP_).retrieve(to, token, amount);
    }

    function reset(
        address operator,
        uint256 newLpFeeRate,
        uint256 newI,
        uint256 newK,
        uint256 baseOutAmount,
        uint256 quoteOutAmount,
        uint256 minBaseReserve,
        uint256 minQuoteReserve
    ) external notFreezed returns (bool) {
        require(
            msg.sender == _OWNER_ ||
                (msg.sender == IBSWAPApprove(_BSWAP_APPROVE_).getBSWAPProxy() &&
                    operator == _OPERATOR_),
            "RESET FORBIDDEN！"
        );
        return
            IBPP(_BPP_).reset(
                msg.sender,
                newLpFeeRate,
                newI,
                newK,
                baseOutAmount,
                quoteOutAmount,
                minBaseReserve,
                minQuoteReserve
            );
    }

    // ============ Admin Version Control ============

    function version() external pure returns (string memory) {
        return "BPPAdmin 1.0.0"; // 1.0.0
    }
}
