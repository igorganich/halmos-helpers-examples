# Side-entrance CTF example
[side-entrance](https://www.damnvulnerabledefi.xyz/challenges/side-entrance/) is one of the [Damn Vulnerable Defi](damnvulnerabledefi.xyz) challenges.

To successfully solve this challenge, you need to 
1. Run at least 2 symbolic transactions (`flashloan() -> deposit()` and `withdraw()`)
2. Process 2 callbacks: `execute()` and `receive()`

Since **halmos-helpers-lib** allows you to do all this with minimal configuration, I decided to take this challenge as an example. It is enough to make one short test contract and the challenge will be solved.
## Run
```javascript
halmos --function check_sideEntrance -vv
```
See counterexample scenario