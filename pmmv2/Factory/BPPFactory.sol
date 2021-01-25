/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {InitializableOwnable} from "../lib/InitializableOwnable.sol";
import {ICloneFactory} from "../lib/CloneFactory.sol";
import {IFeeRateModel} from "../lib/FeeRateModel.sol";
import {IBPP} from "../BSWAPPrivatePool/intf/IBPP.sol";
import {IBPPAdmin} from "../BSWAPPrivatePool/intf/IBPPAdmin.sol";

/**
 * @title BSWAP PrivatePool Factory
 * @author BSWAP Breeder
 *
 * @notice Create And Register BPP Pools 
 */
contract BPPFactory is InitializableOwnable {
    // ============ Templates ============

    address public immutable _CLONE_FACTORY_;
    address public immutable _DEFAULT_MAINTAINER_;
    address public immutable _DEFAULT_MT_FEE_RATE_MODEL_;
    address public immutable _BSWAP_APPROVE_;
    address public _BPP_TEMPLATE_;
    address public _BPP_ADMIN_TEMPLATE_;

    // ============ Registry ============

    // base -> quote -> BPP address list
    mapping(address => mapping(address => address[])) public _REGISTRY_;
    // creator -> BPP address list
    mapping(address => address[]) public _USER_REGISTRY_;

    // ============ Events ============

    event NewBPP(
        address baseToken,
        address quoteToken,
        address creator,
        address bpp
    );


    event RemoveBPP(address bpp);

    constructor(
        address cloneFactory,
        address bppTemplate,
        address bppAdminTemplate,
        address defaultMaintainer,
        address defaultMtFeeRateModel,
        address bswapApprove
    ) public {
        _CLONE_FACTORY_ = cloneFactory;
        _BPP_TEMPLATE_ = bppTemplate;
        _BPP_ADMIN_TEMPLATE_ = bppAdminTemplate;
        _DEFAULT_MAINTAINER_ = defaultMaintainer;
        _DEFAULT_MT_FEE_RATE_MODEL_ = defaultMtFeeRateModel;
        _BSWAP_APPROVE_ = bswapApprove;
    }

    // ============ Functions ============

    function createBSWAPPrivatePool() external returns (address newPrivatePool) {
        newPrivatePool = ICloneFactory(_CLONE_FACTORY_).clone(_BPP_TEMPLATE_);
    }

    function initBSWAPPrivatePool(
        address bppAddress,
        address creator,
        address baseToken,
        address quoteToken,
        uint256 lpFeeRate,
        uint256 k,
        uint256 i,
        bool isOpenTwap
    ) external {
        {
            address _bppAddress = bppAddress;
            address adminModel = _createBPPAdminModel(
                creator,
                _bppAddress,
                creator,
                _BSWAP_APPROVE_
            );
            IBPP(_bppAddress).init(
                adminModel,
                _DEFAULT_MAINTAINER_,
                baseToken,
                quoteToken,
                lpFeeRate,
                _DEFAULT_MT_FEE_RATE_MODEL_,
                k,
                i,
                isOpenTwap
            );
        }

        _REGISTRY_[baseToken][quoteToken].push(bppAddress);
        _USER_REGISTRY_[creator].push(bppAddress);
        emit NewBPP(baseToken, quoteToken, creator, bppAddress);
    }

    function _createBPPAdminModel(
        address owner,
        address bpp,
        address operator,
        address bswapApprove
    ) internal returns (address adminModel) {
        adminModel = ICloneFactory(_CLONE_FACTORY_).clone(_BPP_ADMIN_TEMPLATE_);
        IBPPAdmin(adminModel).init(owner, bpp, operator, bswapApprove);
    }

    // ============ Admin Operation Functions ============
    
    function updateAdminTemplate(address _newBPPAdminTemplate) external onlyOwner {
        _BPP_ADMIN_TEMPLATE_ = _newBPPAdminTemplate;
    }

    function updateBppTemplate(address _newBPPTemplate) external onlyOwner {
        _BPP_TEMPLATE_ = _newBPPTemplate;
    }

    function addPoolByAdmin(
        address creator,
        address baseToken, 
        address quoteToken,
        address pool
    ) external onlyOwner {
        _REGISTRY_[baseToken][quoteToken].push(pool);
        _USER_REGISTRY_[creator].push(pool);
        emit NewBPP(baseToken, quoteToken, creator, pool);
    }

    function removePoolByAdmin(
        address creator,
        address baseToken, 
        address quoteToken,
        address pool
    ) external onlyOwner {
        address[] memory registryList = _REGISTRY_[baseToken][quoteToken];
        for (uint256 i = 0; i < registryList.length; i++) {
            if (registryList[i] == pool) {
                registryList[i] = registryList[registryList.length - 1];
                break;
            }
        }
        _REGISTRY_[baseToken][quoteToken] = registryList;
        _REGISTRY_[baseToken][quoteToken].pop();
        address[] memory userRegistryList = _USER_REGISTRY_[creator];
        for (uint256 i = 0; i < userRegistryList.length; i++) {
            if (userRegistryList[i] == pool) {
                userRegistryList[i] = userRegistryList[userRegistryList.length - 1];
                break;
            }
        }
        _USER_REGISTRY_[creator] = userRegistryList;
        _USER_REGISTRY_[creator].pop();
        emit RemoveBPP(pool);
    }

    // ============ View Functions ============

    function getBSWAPPool(address baseToken, address quoteToken)
        external
        view
        returns (address[] memory pools)
    {
        return _REGISTRY_[baseToken][quoteToken];
    }

    function getBSWAPPoolBidirection(address token0, address token1)
        external
        view
        returns (address[] memory baseToken0Pool, address[] memory baseToken1Pool)
    {
        return (_REGISTRY_[token0][token1], _REGISTRY_[token1][token0]);
    }

    function getBSWAPPoolByUser(address user) 
        external
        view
        returns (address[] memory pools)
    {
        return _USER_REGISTRY_[user];
    }
}
