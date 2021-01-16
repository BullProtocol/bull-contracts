// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BSwapToken.sol";

interface IMigrator {
    // Perform POOL token migration from legacy UniswapV2 to ERC20Swap.
    // Take the current POOL token address and return the new POOL token address.
    // Migrator should have full access to the caller's POOL token.
    // Return the new POOL token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 POOL tokens.
    // ERC20Swap must mint EXACTLY the same amount of ERC20Swap POOL tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// BSwapPool is the master of ERC20. He can make ERC20 and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once ERC20 is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract BSwapPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many POOL tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of ERC20s
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accERC20PerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws POOL tokens to a pool. Here's what happens:
        //   1. The pool's `accERC20PerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 poolToken;           // Address of POOL token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. ERC20s to distribute per block.
        uint256 lastRewardBlock;  // Last block number that ERC20s distribution occurs.
        uint256 accERC20PerShare; // Accumulated ERC20s per share, times 1e12. See below.
    }

    // The ERC20 TOKEN!
    ERC20Token public erc20;
    // Dev address.
    address public devaddr;
    // Block number when bonus ERC20 period ends.
    uint256 public bonusEndBlock;
    // ERC20 tokens created per block.
    uint256 public erc20PerBlock = 833333333333333;
    // Bonus muliplier for early erc20 makers.
    uint256 public constant BONUS_MULTIPLIER = 5;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigrator public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes POOL tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when ERC20 mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        ERC20Token _erc20,
        address _devaddr,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        address[] memory _poolTokens
    ) public {
        erc20 = _erc20;
        devaddr = _devaddr;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        uint256 i;
        for (i = 0; i < _poolTokens.length; ++i) {
			add(IERC20(_poolTokens[i]), false, 100);
		}
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new token to the pool. Can only be called by the owner.
    function add(IERC20 _poolToken, bool _withUpdate, uint256 _allocPoint) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            poolToken: _poolToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accERC20PerShare: 0
        }));
    }

    // Add new tokens to the pool. Can only be called by the owner.
    function addTokenList(address[] memory _poolTokens, uint256 _allocPoint) public onlyOwner {
        uint256 i;
        for (i = 0; i < _poolTokens.length; ++i) {
			add(IERC20(_poolTokens[i]), false, _allocPoint);
		}
    }

    // setNewToken, can only be called by the owner.
    function setNewToken(uint _pid, IERC20 _newToken) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.poolToken = _newToken;
    }

    // Update the given pool's ERC20 allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigrator _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate pool token to another pool contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 poolToken = pool.poolToken;
        uint256 bal = poolToken.balanceOf(address(this));
        poolToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(poolToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.poolToken = newLpToken;
    }
    
    // Upgrade Mining Pool. Can only be called by the owner
    function upgrade(address _address) public onlyOwner {
        erc20.transferOwnership(_address);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    // View function to see pending ERC20s on frontend.
    function pendingERC20(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accERC20PerShare = pool.accERC20PerShare;
        uint256 tokenSupply = pool.poolToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && tokenSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 erc20Reward = multiplier.mul(erc20PerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accERC20PerShare = accERC20PerShare.add(erc20Reward.mul(1e12).div(tokenSupply));
        }
        return user.amount.mul(accERC20PerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 tokenSupply = pool.poolToken.balanceOf(address(this));
        if (tokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 erc20Reward = multiplier.mul(erc20PerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        erc20.mint(devaddr, erc20Reward.div(10));
        erc20.mint(address(this), erc20Reward);
        pool.accERC20PerShare = pool.accERC20PerShare.add(erc20Reward.mul(1e12).div(tokenSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit POOL tokens to BSwapPool for ERC20 allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accERC20PerShare).div(1e12).sub(user.rewardDebt);
            safeERC20Transfer(msg.sender, pending);
        }
        pool.poolToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accERC20PerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw POOL tokens from BSwapPool.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accERC20PerShare).div(1e12).sub(user.rewardDebt);
        safeERC20Transfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accERC20PerShare).div(1e12);
        pool.poolToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.poolToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe erc20 transfer function, just in case if rounding error causes pool to not have enough ERC20s.
    function safeERC20Transfer(address _to, uint256 _amount) internal {
        uint256 erc20Bal = erc20.balanceOf(address(this));
        if (_amount > erc20Bal) {
            erc20.transfer(_to, erc20Bal);
        } else {
            erc20.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
