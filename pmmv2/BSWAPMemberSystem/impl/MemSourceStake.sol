/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {Ownable} from "../../lib/Ownable.sol";
import {IMemSource} from "./MemAggregator.sol";
import {IERC20} from "../../intf/IERC20.sol";
import {SafeMath} from "../../lib/SafeMath.sol";
import {SafeERC20} from "../../lib/SafeERC20.sol";
import {DecimalMath} from "../../lib/DecimalMath.sol";

contract MemSourceStake is Ownable, IMemSource {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public _BSWAP_TOKEN_;
    uint256 public _BSWAP_RESERVE_;
    uint256 public _COLD_DOWN_DURATION_;

    mapping(address => uint256) internal _STAKED_BSWAP_;
    mapping(address => uint256) internal _PENDING_BSWAP_;
    mapping(address => uint256) internal _EXECUTE_TIME_;

    constructor(address bswapToken) public {
        _BSWAP_TOKEN_ = bswapToken;
    }

    // ============ Owner Function ============

    function setColdDownDuration(uint256 coldDownDuration) external onlyOwner {
        _COLD_DOWN_DURATION_ = coldDownDuration;
    }

    // ============ BSWAP Function ============

    function admitStakedBSWAP(address to) external {
        uint256 bswapInput = IERC20(_BSWAP_TOKEN_).balanceOf(address(this)).sub(_BSWAP_RESERVE_);
        _STAKED_BSWAP_[to] = _STAKED_BSWAP_[to].add(bswapInput);
        _sync();
    }

    function stakeBSWAP(uint256 amount) external {
        _transferBSWAPIn(msg.sender, amount);
        _STAKED_BSWAP_[msg.sender] = _STAKED_BSWAP_[msg.sender].add(amount);
        _sync();
    }

    function requestBSWAPWithdraw(uint256 amount) external {
        _STAKED_BSWAP_[msg.sender] = _STAKED_BSWAP_[msg.sender].sub(amount);
        _PENDING_BSWAP_[msg.sender] = _PENDING_BSWAP_[msg.sender].add(amount);
        _EXECUTE_TIME_[msg.sender] = block.timestamp.add(_COLD_DOWN_DURATION_);
    }

    function withdrawBSWAP() external {
        require(_EXECUTE_TIME_[msg.sender] <= block.timestamp, "WITHDRAW_COLD_DOWN");
        _transferBSWAPOut(msg.sender, _PENDING_BSWAP_[msg.sender]);
        _PENDING_BSWAP_[msg.sender] = 0;
    }

    // ============ Balance Function ============

    function _transferBSWAPIn(address from, uint256 amount) internal {
        IERC20(_BSWAP_TOKEN_).transferFrom(from, address(this), amount);
    }

    function _transferBSWAPOut(address to, uint256 amount) internal {
        IERC20(_BSWAP_TOKEN_).transfer(to, amount);
    }

    function _sync() internal {
        _BSWAP_RESERVE_ = IERC20(_BSWAP_TOKEN_).balanceOf(address(this));
    }

    // ============ View Function ============

    function getMemLevel(address user) external override returns (uint256) {
        return _STAKED_BSWAP_[user];
    }
}
