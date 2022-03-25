pragma ton-solidity >= 0.58.1;
pragma AbiHeader pubkey;

import './MSDeployer.sol';
import "./Constants.sol";

library TrinityRootContractErrors {
  uint8 constant error_message_sender_is_not_my_owner = 100;
  uint8 constant error_insufficient_balance = 101;
  uint8 constant error_bad_tps_params = 102;
}

contract TrinityRoot {
  TvmCell static MSDeployerCode;
  TvmCell static MSCode;

  uint128 static salt;

  uint32 public deployer_counter;

  // How many requests in parallel must MS send to each other;
  // We used 3 to smooth delays in message delivery speed.
  // When you send message from A shard to B shard it can delay for 1-3 blocks of B shard. (up to 10 secs).

  uint32[] public tps_history;
  uint128[] public balance_history;
  uint128[] public require_history;

  uint128 value_for_deployer_gas = 0.15 ever;
  uint128 value_for_recursive_trinity_call_gas = 0.05 ever;

  modifier onlyOwnerOrSelf() {
    require(address(this) == msg.sender || tvm.pubkey() == msg.pubkey(), TrinityRootContractErrors.error_message_sender_is_not_my_owner);
    _;
  }

  function launchTps(uint128 timeSeconds, uint32 tps) public onlyOwnerOrSelf {
    tvm.accept();

    //Now we deploy One MSDeployer and if we need more - just call this contract again recursively.
    address _addr = new MSDeployer{
      value: getCostForTps(timeSeconds, 1)  - value_for_recursive_trinity_call_gas,
      flag: 1,
      code: MSDeployerCode,
      bounce: false,
      varInit: {
        MSCode: MSCode,
        root: address(this),
        salt: deployer_counter
      }
    }(Constants.parralel_request_per_ms_group);

    deployer_counter++;
    if (tps > 1) {
      TrinityRoot(address(this)).launchTps(timeSeconds, tps - 1);
    }
  }

  function getCostForTps(uint128 timeSeconds, uint32 tps) public view returns (uint128) {
    // 5_000_000 - cost for send one message from ms
    // 3 - ms's in one group
    // when we send a message from a shard to b shard it can be imported not in the next block
    uint128 cost_per_tps_per_second = 5_000_000 * Constants.ms_group_members_count;
    return cost_per_tps_per_second * tps * timeSeconds + uint128(howManyDeployersNeed(tps)) * (value_for_deployer_gas + value_for_recursive_trinity_call_gas);
  }

  function howManyDeployersNeed(uint32 tps) public view returns (uint32) {
      return tps;
  }

  function withdraw(address _to) public onlyOwnerOrSelf {
      tvm.accept();
      tvm.rawReserve(0.1 ever, 0);
      _to.transfer(0, false, 128);
  }
}
