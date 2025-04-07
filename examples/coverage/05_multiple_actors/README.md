# Multiple actors example
This example shows how you can work with contracts where different actors play different roles. Also, some invariants can only be broken after transactions made by different actors.

Target contract:
```solidity
contract MultipleActorsTarget {
    bool public goal;
    bool private lock;
    address private unlocker;
    address private goaler;

    constructor(address _unlocker, address _goaler) {
        unlocker = _unlocker;
        goaler = _goaler;
        lock = true;
    }

    function unlock() external {
        if (msg.sender != unlocker) {
            revert();
        }
        lock = false;
    }

    function goal_function() external {
        if (msg.sender == goaler && lock == false) {
            goal = true;
        }
    }
}
```

This contract implements 2 roles: **goaler** and **unlocker**. To achieve the goal, the **unlocker** must first call the `unlock()` function and then the **goaler** must call the `goal_function()`.

In the test contract, we initialize 2 actors:
```solidity
actors = halmosHelpersGetSymbolicActorArray(2);
```
And deploy the target contract:
```solidity
target = new MultipleActorsTarget(address(actors[0]), address(actors[1]));
```
We check our abstract scenario: 2 symbolic transactions occur, which can be started by any of the actors:
```solidity
function check_MultipleActors() external {
    halmosHelpersSymbolicBatchStartPrank(actors);
    executeSymbolicallyAllTargets("check_MultipleActors_1");
    vm.stopPrank();

    halmosHelpersSymbolicBatchStartPrank(actors);
    executeSymbolicallyAllTargets("check_MultipleActors_2");
    vm.stopPrank();
    ...
```
## Run
```javascript
halmos --function check_MultipleActorsOneTarget -vv
```
and see counterexample scenario.