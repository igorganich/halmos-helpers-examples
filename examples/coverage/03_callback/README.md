# Callback example
This example shows that the `SymbolicActor` from **halmos-helpers-lib** is able to automatically handle **callbacks** that were called from the target contract to it.

CallbackTarget contains the function `unlock_goal_function()`:
```solidity
function unlock_goal_function() external {
    lock = false;
    if (CallbackReceiver(msg.sender).callback() != 0x1337) {
        revert();
    }
    lock = true;
}
```
Meanwhile, `goal_function()`:
```solidity
function goal_function() external {
    if (lock == true) {
        revert();
    }
    goal = true;
}
```
The only way to achieve the goal is:
1. Call `unlock_goal_function()`
2. Handle `callback()` callback: inside it, call `goal_function()` and return `0x1337`.

## Run
```javascript
halmos --function check_Callback -vv 
```
and see counterexample scenario.