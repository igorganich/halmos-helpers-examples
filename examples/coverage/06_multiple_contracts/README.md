# Multiple contracts example
In the real-world protocols, we almost always have multiple contracts and they depend on each other. This example shows how halmos-helpers-lib handles such cases.

To achieve the goal, we need to register both (MultipleContractsTarget1 and MultipleContractsTarget2) targets:
```solidity
halmosHelpersRegisterTargetAddress(address(target1), "MultipleContractsTarget1");
halmosHelpersRegisterTargetAddress(address(target2), "MultipleContractsTarget2");
```
The test scenario runs 2 transactions that can be called by the actor any of the two targets:
```solidity
function check_MultipleContracts() external {
    halmosHelpersSymbolicBatchStartPrank(actors);
    executeSymbolicallyAllTargets("check_MultipleContracts_1");
    vm.stopPrank();

    halmosHelpersSymbolicBatchStartPrank(actors);
    executeSymbolicallyAllTargets("check_MultipleContracts_2");
    vm.stopPrank();
    ...
```
## Run
```javascript
halmos --function check_MultipleContracts -vv
```
And see counterexample scenario