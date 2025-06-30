# Allowed functions example
This example shows how to allow only a limited set of functions for symbolic execution.

The essence of this example is the same as in `banned_function`, but this time we don't have a **blacklist** but a **whitelist**

## Run
```solidity
function check_AllowedFunction_disabled() external {
    vm.startPrank(address(actors[0]));
    executeSymbolicallyAllTargets("check_AllowedFunction_disabled_1");
    executeSymbolicallyAllTargets("check_AllowedFunction_disabled_2");
    executeSymbolicallyAllTargets("check_AllowedFunction_disabled_3");
    executeSymbolicallyAllTargets("check_AllowedFunction_disabled_4");
    executeSymbolicallyAllTargets("check_AllowedFunction_disabled_5");
    vm.stopPrank();
    assert(target.goal() != true);
}
```
```javascript
halmos --function check_AllowedFunction_disabled -vv
...
Symbolic test result: 0 passed; 1 failed; time: 9.25s
```
It took 9 seconds to execute test with this function.

Now let's allow only `goal_function()` function:
```solidity
function check_AllowedFunction_enabled() external {
    vm.startPrank(getConfigurer());
    halmosHelpersSetOnlyAllowedSelectors(true);
    halmosHelpersAllowFunctionSelector(target.goal_function.selector);
    vm.stopPrank();

    vm.startPrank(address(actors[0]));
    executeSymbolicallyAllTargets("check_AllowedFunction_enabled_1");
    executeSymbolicallyAllTargets("check_AllowedFunction_enabled_2");
    executeSymbolicallyAllTargets("check_AllowedFunction_enabled_3");
    executeSymbolicallyAllTargets("check_AllowedFunction_enabled_4");
    executeSymbolicallyAllTargets("check_AllowedFunction_enabled_5");
    vm.stopPrank();
    assert(target.goal() != true);
}
```
```javascript
halmos --function check_BannedFunction_enabled -vv
...
Symbolic test result: 0 passed; 1 failed; time: 0.66s
```
So much faster!