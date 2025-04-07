# No duplicate calls mode example
This example shows how enabling **noDuplicateCalls** mode can be useful. We have a target contract that needs to call 5 functions in the correct order for the goal:
```solidity
contract NoDuplicateCallsTarget {
    bool public goal;
    uint8 private counter;

    constructor() {
        counter = 0;
        goal = false;
    }

    function inc_counter1() external {
        if (counter == 0) {
            counter++;
        }
    }

    function inc_counter2() external {
        if (counter == 1) {
            counter++;
        }
    }

    function inc_counter3() external {
        if (counter == 2) {
            counter++;
        }
    }

    function inc_counter4() external {
        if (counter == 3) {
            counter++;
        }
    }

    function goal_function() external {
        if (counter == 4) {
            goal = true;
        }
    }
}
```
By default, halmos will try to call the target function even if it has already called it in the current path:
```solidity
function check_NoDuplicateCalls_disabled() external {
    vm.startPrank(address(actors[0]));
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_1");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_2");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_3");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_4");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_5");
    vm.stopPrank();
    assert(target.goal() != true);
}
```
Run:
```javascript
halmos --function check_NoDuplicateCalls_disabled -vv
...
[FAIL] check_NoDuplicateCalls_disabled() (paths: 3127, time: 269.35s, bounds: [])
```
It found a counterexample, but only after ~5 minutes (on my machine).

And now the same scenario, but with the **NoDuplicateCalls** mode enabled:
```solidity
function check_NoDuplicateCalls_enabled() external {
    vm.startPrank(getConfigurer());
    halmosHelpersSetNoDuplicateCalls(true);
    vm.stopPrank();

    vm.startPrank(address(actors[0]));
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_1");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_2");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_3");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_4");
    executeSymbolicallyAllTargets("check_NoDuplicateCalls_disabled_5");
    vm.stopPrank();
    assert(target.goal() != true);
}
```
Run:
```solidity
halmos --function check_NoDuplicateCalls_enabled -vv
...
[FAIL] check_NoDuplicateCalls_enabled() (paths: 122, time: 54.81s, bounds: [])
```
So much faster!