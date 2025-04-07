# Banned functions example
This example shows how to exclude a function from the target list.

Our target contract has the following function:
```solidity
/* 
** This function is guaranteed to have no effect on any target
** It is taken from https://docs.safe.global/reference-smart-account/transactions/simulateAndRevert
*/
function simulateAndRevert(address targetContract, bytes memory calldataPayload) external {
    assembly {
        let success := delegatecall(gas(), targetContract, add(calldataPayload, 0x20), mload(calldataPayload), 0, 0)

        mstore(0x00, success)
        mstore(0x20, returndatasize())
        returndatacopy(0x40, 0, returndatasize())
        revert(0, add(returndatasize(), 0x40))
    }
}
```
By default, halmos will symbolically execute some calls inside `simulateAndRevert()`, despite the fact that this function is guaranteed to have no effect on anything. We can help halmos not to consider it in the symbolic test, thereby saving a lot of resources. The larger the setup, the greater the savings.

## Run
```solidity
function check_BannedFunction_disabled() external {
    vm.startPrank(address(actors[0]));
    executeSymbolicallyAllTargets("check_BannedFunction_disabled_1");
    executeSymbolicallyAllTargets("check_BannedFunction_disabled_2");
    executeSymbolicallyAllTargets("check_BannedFunction_disabled_3");
    executeSymbolicallyAllTargets("check_BannedFunction_disabled_4");
    executeSymbolicallyAllTargets("check_BannedFunction_disabled_5");
    vm.stopPrank();
    assert(target.goal() != true);
}
```
```javascript
halmos --function check_BannedFunction_disabled -vv
...
Symbolic test result: 0 passed; 1 failed; time: 7.97s
```
It took 8 seconds to execute test with this function.

Now let's ban this function:
```solidity
function check_BannedFunction_enabled() external {
    vm.startPrank(getConfigurer());
    halmosHelpersBanFunctionSelector(bytes4(keccak256("simulateAndRevert(address,bytes)")));
    vm.stopPrank();

    vm.startPrank(address(actors[0]));
    executeSymbolicallyAllTargets("check_BannedFunction_enabled_1");
    executeSymbolicallyAllTargets("check_BannedFunction_enabled_2");
    executeSymbolicallyAllTargets("check_BannedFunction_enabled_3");
    executeSymbolicallyAllTargets("check_BannedFunction_enabled_4");
    executeSymbolicallyAllTargets("check_BannedFunction_enabled_5");
    vm.stopPrank();
    assert(target.goal() != true);
}
```
```javascript
halmos --function check_BannedFunction_enabled -vv
...
[FAIL] check_BannedFunction_enabled() (paths: 1, time: 0.75s, bounds: [])
```
So much faster!