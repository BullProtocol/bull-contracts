/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {Ownable} from "./library/Ownable.sol";
import {IBSWAP} from "./interface/IBSWAP.sol";
import {ICloneFactory} from "./utils/CloneFactory.sol";


/**
 * @title BSWAPFactory
 * @author BSWAP Breeder
 *
 * @notice Register of All BSWAP
 */
contract BSWAPFactory is Ownable {
    address public _BSWAP_LOGIC_;
    address public _CLONE_FACTORY_;

    address public _DEFAULT_SUPERVISOR_;

    mapping(address => mapping(address => address)) internal _BSWAP_REGISTER_;
    address[] public _BSWAPs;

    // ============ Events ============

    event BSWAPBirth(address newBorn, address baseToken, address quoteToken);

    // ============ Constructor Function ============

    constructor(
        address _bswapLogic,
        address _cloneFactory,
        address _defaultSupervisor
    ) public {
        _BSWAP_LOGIC_ = _bswapLogic;
        _CLONE_FACTORY_ = _cloneFactory;
        _DEFAULT_SUPERVISOR_ = _defaultSupervisor;
    }

    // ============ Admin Function ============

    function setBSWAPLogic(address _bswapLogic) external onlyOwner {
        _BSWAP_LOGIC_ = _bswapLogic;
    }

    function setCloneFactory(address _cloneFactory) external onlyOwner {
        _CLONE_FACTORY_ = _cloneFactory;
    }

    function setDefaultSupervisor(address _defaultSupervisor) external onlyOwner {
        _DEFAULT_SUPERVISOR_ = _defaultSupervisor;
    }

    function removeBSWAP(address bswap) external onlyOwner {
        address baseToken = IBSWAP(bswap)._BASE_TOKEN_();
        address quoteToken = IBSWAP(bswap)._QUOTE_TOKEN_();
        require(isBSWAPRegistered(baseToken, quoteToken), "BSWAP_NOT_REGISTERED");
        _BSWAP_REGISTER_[baseToken][quoteToken] = address(0);
        for (uint256 i = 0; i <= _BSWAPs.length - 1; i++) {
            if (_BSWAPs[i] == bswap) {
                _BSWAPs[i] = _BSWAPs[_BSWAPs.length - 1];
                _BSWAPs.pop();
                break;
            }
        }
    }

    function addBSWAP(address bswap) public onlyOwner {
        address baseToken = IBSWAP(bswap)._BASE_TOKEN_();
        address quoteToken = IBSWAP(bswap)._QUOTE_TOKEN_();
        require(!isBSWAPRegistered(baseToken, quoteToken), "BSWAP_REGISTERED");
        _BSWAP_REGISTER_[baseToken][quoteToken] = bswap;
        _BSWAPs.push(bswap);
    }

    // ============ Breed BSWAP Function ============

    function breedBSWAP(
        address maintainer,
        address baseToken,
        address quoteToken,
        address oracle,
        uint256 lpFeeRate,
        uint256 mtFeeRate,
        uint256 k,
        uint256 gasPriceLimit
    ) external onlyOwner returns (address newBornBSWAP) {
        require(!isBSWAPRegistered(baseToken, quoteToken), "BSWAP_REGISTERED");
        newBornBSWAP = ICloneFactory(_CLONE_FACTORY_).clone(_BSWAP_LOGIC_);
        IBSWAP(newBornBSWAP).init(
            _OWNER_,
            _DEFAULT_SUPERVISOR_,
            maintainer,
            baseToken,
            quoteToken,
            oracle,
            lpFeeRate,
            mtFeeRate,
            k,
            gasPriceLimit
        );
        addBSWAP(newBornBSWAP);
        emit BSWAPBirth(newBornBSWAP, baseToken, quoteToken);
        return newBornBSWAP;
    }

    // ============ View Functions ============

    function isBSWAPRegistered(address baseToken, address quoteToken) public view returns (bool) {
        if (
            _BSWAP_REGISTER_[baseToken][quoteToken] == address(0) &&
            _BSWAP_REGISTER_[quoteToken][baseToken] == address(0)
        ) {
            return false;
        } else {
            return true;
        }
    }

    function getBSWAP(address baseToken, address quoteToken) external view returns (address) {
        return _BSWAP_REGISTER_[baseToken][quoteToken];
    }

    function getBSWAPs() external view returns (address[] memory) {
        return _BSWAPs;
    }
}
