// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
//pragma experimental ABIEncoderV2;

import "./ONE.sol";
import "./SwapLib.sol";

contract Vault is Configurable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    using EmaOracle for EmaOracle.Observations;
    
    bytes32 internal constant _thresholdReserve_        = 'thresholdReserve';
    bytes32 internal constant _ratioAEthWhenMint_       = 'ratioAEthWhenMint';
    bytes32 internal constant _periodTwapOne_           = 'periodTwapOne';
    bytes32 internal constant _periodTwapOns_           = 'periodTwapOns';
    
    address public one;
    address public ons;
    address public onb;
    address public aEth;
    uint public begin;
    uint public span;
    EmaOracle.Observations public twapOne;
    EmaOracle.Observations public twapOns;
    
	function initialize(address governor_, address _one, address _ons, address _onb, address _aEth, uint _begin, uint _span) external initializer {
		Governable.initialize(governor_);
		one = _one;
		ons = _ons;
		onb = _onb;
		aEth = _aEth;
		begin = _begin;
		span = _span;
		config[_thresholdReserve_]  = 0.8 ether;
		config[_ratioAEthWhenMint_] = 0.9 ether;
		config[_periodTwapOne_]     = 1 days;
		config[_periodTwapOns_]     = 15 minutes;
	}
	
	function twapInit(address swapFactory) external governance {
		twapOne.initialize(swapFactory, config[_periodTwapOne_], one, aEth);
		twapOns.initialize(swapFactory, config[_periodTwapOns_], ons, aEth);
	}
		
    modifier updateTwap {
        twapOne.update(config[_periodTwapOne_], one, aEth);
        twapOns.update(config[_periodTwapOns_], ons, aEth);
        _;
    }
    
    function calcEmaPrice(uint period, uint timestampStart, uint priceCumulativeStart, uint emaPriceStart, uint timestampEnd, uint priceCumulativeEnd) internal pure returns (uint) {
        uint timeElapsed = timestampEnd.sub(timestampStart);
        if(timeElapsed == 0)
            return emaPriceStart;
        uint priceAverage = priceCumulativeEnd.sub(priceCumulativeStart).div(timeElapsed);
        if(timeElapsed >= period) {
            return priceAverage;
        } else {
            return period.sub(timeElapsed).mul(emaPriceStart).add(timeElapsed.mul(priceAverage)).div(period);
        }
    }
    
    function mintONE(uint amt) external updateTwap {
        uint quota = IERC20(one).totalSupply().mul(config[_thresholdReserve_]).div(1e18).sub0(IERC20(aEth).balanceOf(address(this)));
        require(now >= begin && now <= begin.add(span) ||  quota > 0 , 'mintONE only when aEth.balanceOf(this)/one.totalSupply() < 80%');
        
        amt = Math.min(amt, quota);
        IERC20(aEth).safeTransferFrom(msg.sender, address(this), amt.mul(config[_ratioAEthWhenMint_]).div(1e18));
        
        uint vol = amt.mul(uint(1e18).sub(config[_ratioAEthWhenMint_])).div(1e18);
        vol = twapOns.consultHi(config[_periodTwapOns_], address(aEth), vol, address(ons));
        IERC20(ons).safeTransferFrom(msg.sender, address(this), vol);
        
        ONE(one).mint_(msg.sender, amt);
    }
    
    function mintONB(uint vol) external {
        
    }
    
    function B2E(uint vol) external {
        
    }
    
    function burnONE(uint amt) external {
        
    }
    
    function burnONB(uint vol) external {
        
    }
}