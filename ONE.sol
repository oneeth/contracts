// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Include.sol";

contract VaultERC20 is ERC20UpgradeSafe, Configurable {
    address public vault;

	function __VaultERC20_init_unchained(address vault_) public governance {
		vault = vault_;
	}
	
	modifier onlyVault {
	    require(msg.sender == vault, 'called only by vault');
	    _;
	}

    function transferFrom_(address sender, address recipient, uint256 amount) external onlyVault returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }
    
	function mint_(address acct, uint amt) external onlyVault {
	    _mint(acct, amt);
	}
	
	function burn_(address acct, uint amt) external onlyVault {
	    _burn(acct, amt);
	}
}

contract ONE is VaultERC20 {
	function __ONE_init(address governor_, address vault_, address oneMine) external initializer {
        __Context_init_unchained();
		__ERC20_init_unchained("One Eth", "ONE");
		__Governable_init_unchained(governor_);
		__VaultERC20_init_unchained(vault_);
		__ONE_init_unchained(oneMine);
	}
	
	function __ONE_init_unchained(address oneMine) public governance {
		_mint(oneMine, 100 * 10 ** uint256(decimals()));
	}
	
}

contract ONS is VaultERC20 {
	function __ONS_init(address governor_, address vault_, address onsMine, address offering, address timelock) external initializer {
        __Context_init_unchained();
		__ERC20_init("One Share", "ONS");
		__Governable_init_unchained(governor_);
		__VaultERC20_init_unchained(vault_);
		__ONS_init_unchained(onsMine, offering, timelock);
	}
	
	function __ONS_init_unchained(address onsMine, address offering, address timelock) public governance {
		_mint(onsMine, 90000 * 10 ** uint256(decimals()));		// 90%
		_mint(offering, 5000 * 10 ** uint256(decimals()));		//  5%
		_mint(timelock, 5000 * 10 ** uint256(decimals()));		//  5%
	}

}

contract ONB is VaultERC20 {
	function __ONB_init(address governor_, address vault_) virtual external initializer {
        __Context_init_unchained();
		__ERC20_init("One Bond", "ONB");
		__Governable_init_unchained(governor_);
		__VaultERC20_init_unchained(vault_);
	}

    function _beforeTokenTransfer(address from, address to, uint256) internal virtual override {
        require(from == address(0) || to == address(0), 'ONB is untransferable');
    }
}

contract Offering is Configurable {
	using SafeMath for uint;
	using SafeERC20 for IERC20;
	
	IERC20 public token;
	IERC20 public currency;
	uint public price;
	address public vault;
	uint public begin;
	uint public span;
	
	function __Offering_init(address governor_, address _token, address _currency, uint _price, address _vault, uint _begin, uint _span) external initializer {
		__Governable_init_unchained(governor_);
		__Offering_init_unchained(_token, _currency, _price, _vault, _begin, _span);
	}
	
	function __Offering_init_unchained(address _token, address _currency, uint _price, address _vault, uint _begin, uint _span) public initializer {
		token = IERC20(_token);
		currency = IERC20(_currency);
		price = _price;
		vault = _vault;
		begin = _begin;
		span = _span;
	}
	
	function offer(uint vol) external {
		require(now >= begin, 'Not begin');
		if(now > begin.add(span))
			if(token.balanceOf(address(this)) > 0)
				token.safeTransfer(vault, token.balanceOf(address(this)));
			else
				revert('offer over');
		vol = Math.min(vol, token.balanceOf(address(this)));
		uint amt = vol.mul(price).div(1e18);
		currency.safeTransferFrom(msg.sender, vault, amt);
		token.safeTransfer(msg.sender, vol);
	}
}

contract Timelock is Configurable {
	using SafeMath for uint;
	using SafeERC20 for IERC20;
	
	IERC20 public token;
	address public recipient;
	uint public begin;
	uint public span;
	uint public times;
	uint public total;
	
	function start(address _token, address _recipient, uint _begin, uint _span, uint _times) external governance {
		require(address(token) == address(0), 'already start');
		token = IERC20(_token);
		recipient = _recipient;
		begin = _begin;
		span = _span;
		times = _times;
		total = token.balanceOf(address(this));
	}

    function unlockCapacity() public view returns (uint) {
       if(begin == 0 || now < begin)
            return 0;
            
        for(uint i=1; i<=times; i++)
            if(now < span.mul(i).div(times).add(begin))
                return token.balanceOf(address(this)).sub(total.mul(times.sub(i)).div(times));
                
        return token.balanceOf(address(this));
    }
    
    function unlock() public {
        token.safeTransfer(recipient, unlockCapacity());
    }
    
    fallback() external {
        unlock();
    }
}
