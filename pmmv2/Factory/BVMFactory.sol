/*

    Copyright 2020 BSWAP FACTORY.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {InitializableOwnable} from "../lib/InitializableOwnable.sol";
import {ICloneFactory} from "../lib/CloneFactory.sol";
import {IBVM} from "../BSWAPVendingMachine/intf/IBVM.sol";

interface IBVMFactory {
    function createBSWAPVendingMachine(
        address baseToken,
        address quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        bool isOpenTWAP
    ) external returns (address newVendingMachine);
}


/**
 * @title BSWAP VendingMachine Factory
 * @author BSWAP Breeder
 *
 * @notice Create And Register BVM Pools 
 */
contract BVMFactory is InitializableOwnable {
    // ============ Templates ============

    address public immutable _CLONE_FACTORY_;
    address public immutable _DEFAULT_MAINTAINER_;
    address public immutable _DEFAULT_MT_FEE_RATE_MODEL_;
    address public _BVM_TEMPLATE_;

    // ============ Registry ============

    // base -> quote -> BVM address list
    mapping(address => mapping(address => address[])) public _REGISTRY_;
    // creator -> BVM address list
    mapping(address => address[]) public _USER_REGISTRY_;

    // ============ Events ============

    event NewBVM(
        address baseToken,
        address quoteToken,
        address creator,
        address bvm
    );

    event RemoveBVM(address bvm);

    // ============ Functions ============

    constructor(
        address cloneFactory,
        address bvmTemplate,
        address defaultMaintainer,
        address defaultMtFeeRateModel
    ) public {
        _CLONE_FACTORY_ = cloneFactory;
        _BVM_TEMPLATE_ = bvmTemplate;
        _DEFAULT_MAINTAINER_ = defaultMaintainer;
        _DEFAULT_MT_FEE_RATE_MODEL_ = defaultMtFeeRateModel;
    }

    function createBSWAPVendingMachine(
        address baseToken,
        address quoteToken,
        uint256 lpFeeRate,
        uint256 i,
        uint256 k,
        bool isOpenTWAP
    ) external returns (address newVendingMachine) {
        newVendingMachine = ICloneFactory(_CLONE_FACTORY_).clone(_BVM_TEMPLATE_);
        {
            IBVM(newVendingMachine).init(
                _DEFAULT_MAINTAINER_,
                baseToken,
                quoteToken,
                lpFeeRate,
                _DEFAULT_MT_FEE_RATE_MODEL_,
                i,
                k,
                isOpenTWAP
            );
        }
        _REGISTRY_[baseToken][quoteToken].push(newVendingMachine);
        _USER_REGISTRY_[tx.origin].push(newVendingMachine);
        emit NewBVM(baseToken, quoteToken, tx.origin, newVendingMachine);
    }

    // ============ Admin Operation Functions ============

    function updateBvmTemplate(address _newBVMTemplate) external onlyOwner {
        _BVM_TEMPLATE_ = _newBVMTemplate;
    }

    function addPoolByAdmin(
        address creator,
        address baseToken, 
        address quoteToken,
        address pool
    ) external onlyOwner {
        _REGISTRY_[baseToken][quoteToken].push(pool);
        _USER_REGISTRY_[creator].push(pool);
        emit NewBVM(baseToken, quoteToken, creator, pool);
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
        emit RemoveBVM(pool);
    }

    // ============ View Functions ============

    function getBSWAPPool(address baseToken, address quoteToken)
        external
        view
        returns (address[] memory machines)
    {
        return _REGISTRY_[baseToken][quoteToken];
    }

    function getBSWAPPoolBidirection(address token0, address token1)
        external
        view
        returns (address[] memory baseToken0Machines, address[] memory baseToken1Machines)
    {
        return (_REGISTRY_[token0][token1], _REGISTRY_[token1][token0]);
    }

    function getBSWAPPoolByUser(address user)
        external
        view
        returns (address[] memory machines)
    {
        return _USER_REGISTRY_[user];
    }
}
