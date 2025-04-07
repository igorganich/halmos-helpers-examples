# Sequence of 2 in receive example
This example shows that `SymbolicActor` can automatically handle `receive()` callback. In addition, we show the possibilities of configuring the number of symbolic transactions inside `receive()`.

Target contract:
```solidity
contract SequenceOf2ReceiveTarget {
    bool public goal;
    bool private lock1;
    bool private lock2;

    constructor() {
        lock1 = true;
        lock2 = true;
        goal = false;
    }

    receive() external payable {
        if (lock1 == false && address(this).balance == 15e18) {
            lock2 = false;
        }
    }

    function unlock1() external payable {
        lock1 = false;
        payable(msg.sender).transfer(msg.value);
        lock1 = true;
    }

    function goal_function() external {
        if (lock1 == false && lock2 == false) {
            goal = true;
        }
    }
}
```
The only way to achieve the goal is:
1. Call `unlock1()`
2. Handle `receive()` callback: inside it, send some exact amount of ETH to target and call `goal_function()`
To do this, we need to use the next configuration:
```solidity
vm.startPrank(getConfigurer());
...
actors[0].setSymbolicReceiveTxsNumber(2);
vm.stopPrank();
```
This will allow two symbolic transactions to be called inside `receive()`
## Run
```javascript
$ halmos --function check_SequenceOf2Receive -vv
```
and see counterexample scenario.