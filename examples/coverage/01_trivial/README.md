# trivial example
This example shows the process of preparing for a symbolic test, as well as different ways to launch a transaction on the target contract on behalf of an actor. Target contract the most simple as possible. 
It is enough to call one function `trivial_function()` to break the invariant.
## Run
```javascript
$ halmos --function check_Trivial -vv
```
and see 3 counterxamples for each of 3 checks.