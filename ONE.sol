// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./Include.sol";

contract ONE is ERC20UpgradeSafe, Configurable {
    address vault;

	function initialize(address governor_, address oneFarm, address vault_) public initializer {
		Governable.initialize(governor_);
		ERC20UpgradeSafe.__ERC20_init("One Eth", "ONE");
		
		uint8 decimals = 18;
		_setupDecimals(decimals);
		
		_mint(oneFarm, 4200 * 10 ** uint256(decimals));
		
		vault = vault_;
	}
	
	function setVault(address vault_) external governance {
	    vault = vault_;
	}
	
	function mint_(address acct, uint amt) external onlyVault {
	    _mint(acct, amt);
	}
	
	function burn_(address acct, uint amt) external onlyVault {
	    _burn(acct, amt);
	}
	
	modifier onlyVault {
	    require(msg.sender == vault, 'called only by vault');
	    _;
	}
}

contract ONS is ERC20UpgradeSafe, Configurable {

	function initialize(address governor_, address onsFarm, address offering, address timelock) public initializer {
		Governable.initialize(governor_);
		ERC20UpgradeSafe.__ERC20_init("One Share", "ONS");
		
		uint8 decimals = 18;
		_setupDecimals(decimals);
		
		_mint(onsFarm, 90000 * 10 ** uint256(decimals));		// 90%
		_mint(offering, 5000 * 10 ** uint256(decimals));		//  5%
		_mint(timelock, 5000 * 10 ** uint256(decimals));		//  5%
	}

}

contract ONB is ERC20UpgradeSafe, Configurable {
    address vault;

	function initialize(address governor_, address vault_) virtual public initializer {
		Governable.initialize(governor_);
		ERC20UpgradeSafe.__ERC20_init("One Bond", "ONB");
		
		uint8 decimals = 18;
		_setupDecimals(decimals);
		
		vault = vault_;
	}

    function _beforeTokenTransfer(address from, address to, uint256) internal virtual override {
        require(from == address(0) || to == address(0), 'ONB is untransferable');
    }
    
	function mint_(address acct, uint vol) external onlyVault {
	    _mint(acct, vol);
	}
	
	function burn_(address acct, uint vol) external onlyVault {
	    _burn(acct, vol);
	}
	
	modifier onlyVault {
	    require(msg.sender == vault, 'called only by vault');
	    _;
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
	
	function initialize(address governor_, address _token, address _currency, uint _price, address _vault, uint _begin, uint _span) public initializer {
		Governable.initialize(governor_);
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
