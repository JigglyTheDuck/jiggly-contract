// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Clock.sol";
import "./IUniswapRouter.sol";

contract TokenComposerV2 is Clock, UniswapConnect {
    struct Contribution {
        uint64 volume;
        uint64 segmentIndex;
    }

    struct UniswapTX {
      uint64 blockNumber;
      uint64 value;
    }

    UniswapTX latestUniswapTx;
    uint rewardPoolFreeFraction;
    uint segmentIndex = 0;
    uint public segmentPoolSize;
    uint public segmentVolume;
    uint public targetPrice = 0;
    uint public previousTarget = 0;
    uint previousSegmentVolume;

    mapping(address => Contribution) public contributions;
    event Segment(uint targetPrice, uint actualPrice);

    // TBD..
    address lpToken = 0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6;
    
    constructor()
        Clock(1 hour) 
        UniswapConnect(
            msg.sender,
            0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6, // factory
            0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24, // router 1
            0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD, // router 2
            0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f // initial hash
        )
    {
        rewardPoolFreeFraction = 200;
        // actually rubbish, we'll only a single pool.
        // still we can keep it..
        // we can even use DAO just for this here.
        addLP(lpToken);
    }


    function decimals() external view returns(uint8) {return 9;};

    function compose(
        address from,
        address to,
        uint256 value
    ) external returns (uint256) {
        require(msg.sender == mainTokenAddress);

        if (isUniswapLP(from) && isUniswapRouter(to)) {
            // keep track of latest Uniswap TX for BUY trades
            latestUniswapTX = UniswapTX(blockNumber, uint64(value));

            return 0;
        }

        if (isUniswapRouter(from) && latestUniswapTX.value / value == 1) {
             // this is the output of buy tx to the user
             processTrade(to, latestUniswapTX.value, false);
             latestUniswapTX = 0;
        }

        if (isUniswapLP(to)) {
            if (!isUniswap(from)) return 0;
             else {
                 // this is a sell.
                 processTrade(from, value, true);
            }
        }

        if (progressTime()) {
            newSegment();
        }

        return value / rewardPoolFreeFraction;
    }

    function addContribution(address account, uint value) internal {
        segmentVolume += value;
        contributions[account] = Contribution(
            uint64(value),
            uint64(segmentIndex)
        );
    }

    function processTrade(address account, uint value, bool isSell) internal  {
       claimRewards(account);
       segmentVolume += value;
       uint price = getPrice();

       if ((price > targetPrice && isSell) || (price < targetPrice && !isSell)) {
         addContribution(account, value);
       }
    }

    function getPrice() internal view returns (uint) {
      address[] memory path = new address[](2);
      path[0] = mainTokenAddress;
      path[1] = lpToken;

      uint[] memory amountsOut = IUniswapRouter(usRouter1).getAmountsOut(
        1 gwei,
        path
      );

      returns amountsOut[1];
    }

    function setRewardPool() internal {
      uint price = getPrice();
      uint maxPoolSize = IERC20(mainTokenAddress).balanceOf(address(this));
      uint distance = targetPrice > price ? targetPrice - price : price - targetPrice;
      distance = distance == 0 ? 1 : 0;

      segmentPoolSize = 
        (segmentVolume * maxPoolSize) / (IERC20(mainTokenAddress).totalSupply() * rewardPoolFreeFraction * distance);
    }

    function newSegment() internal {
      // time is already progressed at this point.
      uint8 r = uint8(blockhash(block.number - 1)[0]);
      uint price = getPrice();

      segmentIndex += 1;

      updateRewardPool();

      emit Segment(targetPrice, price);

      previousTarget = targetPrice;
      previousSegmentVolume = segmentVolume;

      // we can make it a little bit more sophisticated
      // add brackets and so on...

      // the rule can be as simple as
      // < 50 = 1%
      // < 90 = 2%
      // < 115 = 3%
      // > 115 = 5%

      if (r < 128) {
        targetPrice = price - price / 100;
      } else {
        targetPrice = price + price / 100;
      }
    }

    function passProposal(uint8 proposal, address target) external {
        require(msg.sender == mainTokenAddress);
      
        removeLP(lpToken);
        addLp(target);
        lpToken = target;
    }

    function claimRewards(address account) internal {
        if (segmentVolume == 0) return 0;
        Contribution storage contribution = contributions[account];

        if (contribution.segmentIndex != segmentIndex - 1) return 0;

        uint256 rewards = (segmentPoolSize * contribution.value) /
            previousSegmentVolume;

        // reset to avoid reentry
        contribution.value = 0;

        if (rewards > 0) IERC20(mainTokenAddress).transfer(account, rewards);
    }
}
