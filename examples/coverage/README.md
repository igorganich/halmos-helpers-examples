# Coverage examples
## Basic idea
**Coverage** examples are intended just to show typical situations that **halmos-helpers-lib** can cover. They are written as simply as possible so as not to overload the perception. It should be immediately obvious what exactly needs to be run to break the invariant.
## goal
In each of the examples there is a target contract with a public variable `goal`. Our task is to find a set of transactions that actors make to achieve `goal=true`. This will be our counterexample.