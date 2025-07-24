# Vulnerabilities from Cantina's audit report of the Size Credit protocol v1.8-rc

This example is based on [Cantina's](https://github.com/SizeCredit/size-solidity/blob/main/audits/2025-06-14-Cantina.pdf) audit report of the [Size Credit](https://github.com/SizeCredit/size-solidity/) protocol version [v1.8-rc](https://github.com/SizeCredit/size-solidity/commits/daf1d1d8db21ae7c62df35fcef4f99ed0a914f69).

I suggest you familiarize yourself with the code of this protocol and this audit report, but in this **README** I will still provide a superficial description of the vulnerabilities. After that, an approach will be given on how such vulnerabilities can be conveniently detected using **halmos-helpers-lib**.

## Vulnerabilities overview

We are interested in 3 vulnerabilities found and fixed after the audit, which are based on the assumption that some external contract may have a malicious implementation, which will cause the entire protocol to break.

To put it very simply: the part of functionality of this protocol allows **users** to work with multiple whitelisted **ERC4626** **vaults** in a unified way, making deposits, withdrawing funds, moving assets from one **vault** to another, etc. For each **user**, one specific **vault** is registered with which he works (`vaultOf[user]`). The protocol itself also stores the number of assets belonging to a particular **user** (`sharesOf[user]`).

There are 3 key smart contracts that govern this functionality:
1. **Size**: This is essentially an entry point for **users**. **Users** call functions from this smart contract to make deposits, withdraws, etc.
2. **NonTransferrableRebasingTokenVault**: This is the "heart" of this functionality - it describes the logic of working with the `underlyingToken` (e.g. **USDC**): deposits, withdraws, vault changes, how assets are sent to user's **vaults**. This is where the `vaultOf[user]` and `sharesOf[user]` information is stored.
3. **ERC4626Adapter**: Since the protocol can work with different types of **vaults**, specific logic has been developed for **ERC4626**. Functions from **NonTransferrableRebasingTokenVault** use **ERC4626Adapter** as a specific implementation for working with **assets** and **vaults**.

I think this brief description is enough to understand the whole essence of the vulnerabilities below even for a person who is not familiar with the entire protocol. This audit found scenarios where having a compromised whitelisted **ERC4626** could cause damage to the entire system. By "compromised" we mean "could contain any implementation".

### 3.1.1 Vault drain via no-op _transferFrom()
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function setVault(address user, address vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (vaultToIdMap.contains(vault) && vaultOf[user] != vault) {
            // slither-disable-next-line reentrancy-no-eth
            _transferFrom(vaultOf[user], vault, user, user, balanceOf(user));

            emit VaultSet(user, vaultOf[user], vault);
            vaultOf[user] = vault;
        }
    }
...
}
```
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function balanceOf(address account) public view returns (uint256) {
        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[account]);
        return adapter.balanceOf(vaultOf[account], account);
    }
...
}
```
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function _transferFrom(address vaultFrom, address vaultTo, address from, address to, uint256 value) private {
        if (value > 0) {
            ...
        }
    }
...
}
```
```solidity
contract ERC4626Adapter {
...
    function balanceOf(address vault, address account) public view returns (uint256) {
        return IERC4626(vault).convertToAssets(tokenVault.sharesOf(account));
    }
...
}
```
The essence of this bug is that when changing the vault, a `user` using a compromised `vault` (`vaultOf[user] == compromised_vault`) can take possession of funds that he never deposited.

Let `vaultOf[user] == compromised_vault` and `user` have some **non-zero** number of `shares` (`sharesOf[user] == some_value`). When changing the `vault` to another, the `NonTransferrableRebasingTokenVault::setVault()` function is called. It removes all funds from the previous `vault`, transfers them to the new `vault`, and recalculates the value of `sharesOf[user]` according to the new `vault`. However, a compromised protocol can return `compromised_vault.balanceOf(user) = 0`, even if the `user's` `shares` is not `0`. Then the `_transferFrom()` function will do **NOTHING**, and the `vault` will change. At the same time, `sharesOf[user]` will remain not recalculated, which means that funds that the `user` never deposited can be withdrawn from the new `vault`.
### 3.3.2 Vault drain via reentrancy
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function deposit(address to, uint256 amount) external onlyMarket returns (uint256 assets) {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[to]);
        underlyingToken.safeTransferFrom(msg.sender, address(adapter), amount);
        assets = adapter.deposit(vaultOf[to], to, amount);

        emit Transfer(address(0), to, assets);
    }
...
}
```
```solidity
contract ERC4626Adapter {
...
    function deposit(address vault, address to, uint256 amount) external onlyOwner returns (uint256 assets) {
        // slither-disable-next-line uninitialized-local
        Vars memory vars;
        vars.sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
        vars.userSharesBefore = tokenVault.sharesOf(to);

        underlyingToken.forceApprove(vault, amount);
        // slither-disable-next-line unused-return
        IERC4626(vault).deposit(amount, address(tokenVault));

        uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - vars.sharesBefore;
        assets = IERC4626(vault).convertToAssets(shares);

        tokenVault.setSharesOf(to, vars.userSharesBefore + shares);
    }
...
}
```
The essence of this bug is that `compromised_vault` inside the `NonTransferrableRebasingTokenVault::deposit()` can use **reentrancy** to set any `sharesOf[user]` value for the user, while setting any `vaultOf[user]`. This means that any whitelisted `vault` can be drained.

So, the conditions are:
1. `vaultOf[to] == compromised_vault`
2. `compromised_vault` has permission from `to` to set his **vault** on its behalf (controlled by **SizeFactory**):
    ```solidity
    vm.startPrank(alice);
    ...
    sizeFactory.setAuthorization(symbolic_vault, Authorization.getActionsBitmap(Action.SET_USER_CONFIGURATION));
    ...
    ```
3. `compromised_vault` inside its `deposit()` function sets **vault** for `to` using `Size::setUserConfigurationOnBehalfOf()`.
4. `compromised_vault` implements the `convertToAssets()` function, returning any sufficiently large value.
    Thus, user `to` will be able to empty any vault, since
    ```solidity
    assets = IERC4626(vault).convertToAssets(shares);
    
    tokenVault.setSharesOf(to, vars.userSharesBefore + shares);
    ```
    will give him a huge amount of assets for the `vault`, that he never deposited.
### 3.3.3 setVault() DoS
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function setVault(address user, address vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (vaultToIdMap.contains(vault) && vaultOf[user] != vault) {
            // slither-disable-next-line reentrancy-no-eth
            _transferFrom(vaultOf[user], vault, user, user, balanceOf(user));

            emit VaultSet(user, vaultOf[user], vault);
            vaultOf[user] = vault;
        }
    }
...
}
```
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function balanceOf(address account) public view returns (uint256) {
        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[account]);
        return adapter.balanceOf(vaultOf[account], account);
    }
...
}
```
```solidity
contract ERC4626Adapter {
...
    function balanceOf(address vault, address account) public view returns (uint256) {
        return IERC4626(vault).convertToAssets(tokenVault.sharesOf(account));
    }
...
}
```
The essence of this bug is that `compromised_vault` inside `setVault()` can prevent `users` from changing the `vault`. To do this, it only needs to `revert()` at the reading stage of `compromised_vault.balanceOf()`. Thus, `users` will be "blocked" from using the protocol. This is the whole vulnerability.

## Implementing a symbolic test with halmos-helpers-lib
In general, the preparation of a halmos symbolic test that could catch such a vulnerabilities was divided into several stages:
1. General setup preparation
2. Preparation of halmos-helpers
3. Emulation of a compromised vault using a Symbolic Actor
4. Invariants
5. Description of scenarios

### General setup preparation
To start, we need the **Size** protocol to work at all in our test environment. There is no need to do much research here: just take the setup from the [Unit tests](https://github.com/SizeCredit/size-solidity/blob/d03a69b0bdd66c7a3581444dc4ff45f005451284/script/Deploy.sol), highlight the main things and deploy:
```solidity
import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import "@test/mocks/PoolMock.sol";
import {SizeFactory} from "@src/factory/SizeFactory.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import "@test/mocks/USDC.sol";
import "@test/mocks/NonTransferrableRebasingTokenVaultMock.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    Initialize,
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";
import {ERC4626Adapter} from "@src/market/token/adapters/ERC4626Adapter.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MockERC4626 as ERC4626Solady} from "@solady/test/utils/mocks/MockERC4626.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {DataView} from "@src/market/SizeViewData.sol";
import {WETH} from "@test/mocks/WETH.sol";
import {DepositParams} from "@src/market/libraries/actions/Deposit.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {PriceFeedMock} from "@test/mocks/PriceFeedMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AaveAdapter} from "@src/market/token/adapters/AaveAdapter.sol";
import "@src/market/token/NonTransferrableRebasingTokenVault.sol";

contract HalmosSizeTest is Test {
    ...
    address deployer = address(0xcafe0000);
    address feeRecipient = address(0xcafe0001);

    SizeFactory internal sizeFactory;
    address internal implementation;
    IERC20Metadata internal collateral;
    PriceFeedMock internal priceFeed;
    InitializeFeeConfigParams internal f;
    InitializeRiskConfigParams internal r;
    InitializeOracleParams internal o;
    InitializeDataParams internal d;
    USDC private usdc;
    WETH internal weth;
    ERC4626Adapter erc4626Adapter;
    IERC4626 internal vaultSolady;
    ERC1967Proxy internal proxy;
    AaveAdapter private aaveAdapter;

    Size internal size;
    NonTransferrableRebasingTokenVaultMock private token;
    IPool private variablePool;
    ...
       constructor() {}

    function setUp() external {
        settingUp();
    }

    function settingUp() internal {
        ...
        vm.startPrank(deployer);

        collateral = IERC20Metadata(address(new ERC20Mock()));
        priceFeed = new PriceFeedMock(deployer);
        priceFeed.setPrice(1e18);
        weth = new WETH();
        usdc = new USDC(deployer);
        usdc.mint(address(alice), USDC_INITIAL_BALANCE);
        usdc.mint(address(bob), USDC_INITIAL_BALANCE);
        variablePool = IPool(address(new PoolMock()));

        token = new NonTransferrableRebasingTokenVaultMock();
        sizeFactory = SizeFactory(address(new ERC1967Proxy(address(new SizeFactory()), abi.encodeCall(SizeFactory.initialize, (deployer)))));
        token.initialize(
            ISizeFactory(address(sizeFactory)),
            variablePool,
            usdc,
            address(deployer),
            string.concat("Size ", usdc.name(), " Vault"),
            string.concat("sv", usdc.symbol()),
            usdc.decimals()
        );

        f = InitializeFeeConfigParams({
            swapFeeAPR: 0.005e18,
            fragmentationFee: 5e6,
            liquidationRewardPercent: 0.05e18,
            overdueCollateralProtocolPercent: 0.01e18,
            collateralProtocolPercent: 0.1e18,
            feeRecipient: feeRecipient
        });
        r = InitializeRiskConfigParams({
            crOpening: 1.5e18,
            crLiquidation: 1.3e18,
            minimumCreditBorrowToken: 5e6,
            minTenor: 1 hours,
            maxTenor: 5 * 365 days
        });
        o = InitializeOracleParams({priceFeed: address(priceFeed), variablePoolBorrowRateStaleRateInterval: 0});
        d = InitializeDataParams({
            weth: address(weth),
            underlyingCollateralToken: address(weth),
            underlyingBorrowToken: address(usdc),
            variablePool: address(variablePool), // Aave v3
            borrowTokenVault: address(token),
            sizeFactory: address(sizeFactory)
        });

        implementation = address(new Size());
        sizeFactory.setSizeImplementation(implementation);
        proxy = ERC1967Proxy(payable(address(sizeFactory.createMarket(f, r, o, d))));
        size = Size(payable(proxy));
        PriceFeedMock(address(priceFeed)).setPrice(1337e18);

        erc4626Adapter = new ERC4626Adapter(token, usdc);
        token.setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);
        aaveAdapter = new AaveAdapter(token, variablePool, usdc);
        token.setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        ...
        vm.stopPrank();
    }
}
```
### Preparation of halmos-helpers
Since we are looking at scenarios that each involve `setVault()`, it makes sense that we need at least 2 `vaults`. And since each **user** can only have 1 **vault**, we need at least 2 **users**. These will be our `actors`:
```solidity
function settingUp() internal {
    vm.startPrank(getConfigurer());
    ...
    /*
    * Initialize 2 Actors
    * actors[0] is a regular user
    * actors[1] is a regular user
    */
    actors = halmosHelpersGetSymbolicActorArray(2);

    alice = address(actors[0]);
    bob = address(actors[1]);
    ...

    vm.stopPrank();
    ...
```
In this test, the only target for the symbolic execution contract will be `size`, but of course, if you want to expand this test, you can add other targets:
```solidity
...
vm.startPrank(getConfigurer());
halmosHelpersRegisterTargetAddress(address(size), "Size");
...
vm.stopPrank();
```
### Emulating a compromised vault using a Symbolic Actor
In this test, we are trying to answer the question: "is there an implementation of external `vault` that could, in some scenario, break the logic of the entire protocol?". And to answer this question, we need a mechanism to emulate any `vault` implementation. That is, `vault` can return any value from the `view` functions and execute any `call` inside callbacks, such as `deposit()`. And **halmos-helpers** has a ready-made solution for this need! Just use the **SymbolicActor** contract as `symbolic_vault` and it will emulate any `vault` behavior:
```solidity
function settingUp() internal {
    vm.startPrank(getConfigurer());
    ...
    vaults = halmosHelpersGetSymbolicActorArray(1);
    ...
    symbolic_vault = address(vaults[0]);
    vm.stopPrank();
    ...
    token.setVaultAdapter(symbolic_vault, bytes32("ERC4626Adapter"));
    vaultSolady = IERC4626(address(new ERC4626Solady(address(usdc), "VaultSolady", "VAULTSOLADY", true, 0)));
    token.setVaultAdapter(address(vaultSolady), bytes32("ERC4626Adapter"));
    ...
    /* 
     * Deposit something and leave something on actors' balances, while everything is approved
     * to cover more scenarios 
    */
    vm.startPrank(alice);
    usdc.approve(address(size), USDC_INITIAL_BALANCE);
    size.deposit(DepositParams({token: address(usdc), amount: USDC_INITIAL_BALANCE / 2, to: alice}));
    sizeFactory.setAuthorization(address(size), Authorization.getActionsBitmap(Action.SET_USER_CONFIGURATION));
    sizeFactory.setAuthorization(symbolic_vault, Authorization.getActionsBitmap(Action.SET_USER_CONFIGURATION));
    vm.stopPrank();
    // Symbolic implementation of vault can "forget" to take approved assets
    vm.prank(address(vaults[0]));
    usdc.transferFrom(address(erc4626Adapter), address(symbolic_vault), USDC_INITIAL_BALANCE / 2);

    vm.startPrank(bob);
    usdc.approve(address(size), USDC_INITIAL_BALANCE);
    size.deposit(DepositParams({token: address(usdc), amount: USDC_INITIAL_BALANCE / 2, to: bob}));
    sizeFactory.setAuthorization(address(size), Authorization.getActionsBitmap(Action.SET_USER_CONFIGURATION));
    vm.stopPrank();
```

One of the **vaults** will be the "victim": a regular **ERC4626Solady**, and the other (`symbolic_vault`) will be the "compromised".

`alice's` vault is `symbolic_vault`, `bob's` vault is `vaultSolady`.
### Invariants
For vulnerabilities `3.1.1` and `3.3.2` (both are assets drain), the following invariant was used: we sum all shares of `vaultSolady` contract's **users** and check if this contract has enough **USDC** balance to repay them. If not - the balance is corrupted and somebody probably can drain the **vault**. It is worth noting that we do not consider gaining through **yields** in these scenarios. To do this, I had to add shadow tracking of all assets for a specific vault:
```solidity
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

contract NonTransferrableRebasingTokenVaultMock is NonTransferrableRebasingTokenVault {
    constructor() {
        bytes32 slot = _initializableStorageSlot();
        // re-enables initialize()
        assembly {
            sstore(slot, 0)
        }
    }

    mapping(address => bool) present_in_shares;
    mapping(uint256 => address) addresses_with_shares;
    uint256 number_addresses_with_shares = 0;

    function setSharesOf(address user, uint256 shares) override public onlyAdapter {
        if (present_in_shares[user] == false)
        {
            present_in_shares[user] = true;
            addresses_with_shares[number_addresses_with_shares] = user;
            number_addresses_with_shares++;
        }
        super.setSharesOf(user, shares);
    }

    /// @custom:halmos --loop 256
    function getAllShares(address _vault) external view returns(uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < number_addresses_with_shares; i++) {
            address user = addresses_with_shares[i];
            if (vaultOf[user] == _vault) {
                sum += sharesOf[user];               
            }
        }
        return sum;
    }
}
```
And **invariant**:
```solidity
function vaultSoladyBalanceNotBrokenInvarint() internal view {
    /* A regular vault should be able to return all assets */
    assert(token.getAllShares(address(vaultSolady)) <= usdc.balanceOf(address(vaultSolady)));
}
```

For vulnerability `3.3.3`, the **invariant** "can `market` aka `size` set a valid **vault** to any valid **user**" was chosen:
```solidity
/* market should be able to change vault for any valid user */
address user = _svm.createAddress("user");
vm.assume(user != address(0x0));
vm.assume(token.vaultOf(user) != address(vaultSolady));
bytes memory setVault_calldata = abi.encodeWithSelector(token.setVault.selector, user, address(vaultSolady));

vm.prank(address(size));
(res, retdata ) = address(token).call(setVault_calldata);

assert(res == true);
```
### Scenarios
In this section, I will describe the scenarios and vulnerabilities they can detect. The analysis of counterexamples will be in a separate section below.

1. Depth of 1, no reentrancy

    The simplest scenario: let's see what we can get if some **user** simply calls some function from **Size**. In this case, **symbolic vault** "does not know how" to handle non-view functions, which means reentrancy will not occur. At the same time, in this scenario, it can handle `view` functions symbolically:
    ```solidity
    function settingUp() internal {
        // Don't process callbacks symbolically during setup
        halmosHelpersSetSymbolicCallbacksDepth(0, 0);
        ...
    }
    ...
    /* Should find 3.1.1 (No reentrancy required) */
    function check_BalanceIntegrityNoReentrancy() external {
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegritySize");
        vm.stopPrank();

        vaultSoladyBalanceNotBrokenInvarint();
    }
    ```

    And this is enough to reproduce vulnerability `3.1.1`: **alice** calls `setUserConfigurationOnBehalfOf()` or `setUserConfiguration()` function with appropriate parameters (while `symbolic_vault` returns malicious bytes on view function) and breaks invariant.
2. Depth of 1, reentrancy with depth of 1, **NoDuplicateCalls** enabled

    In this scenario, we add the ability to handle `external/public` callbacks for the `symbolic_vault`: it starts executing one function from ``size`` inside of `fallback()`. At the same time, we add the following heuristic: if some function from `size` has already been called in the current path, we do not call it again:
    ```solidity
    /* Should find 3.1.1 and 3.3.2. Test is still pretty long but shorter than check_BalanceIntegrityWithReentrancyNoDuplicateCallsDisabled */
    function check_BalanceIntegrityWithReentrancyNoDuplicateCallsEnabled() external {
        vm.startPrank(getConfigurer());
        halmosHelpersSetSymbolicCallbacksDepth(1, 1);
        halmosHelpersSetNoDuplicateCalls(true);
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegritySize");
        vm.stopPrank();

        vaultSoladyBalanceNotBrokenInvarint();
    }
    ```
    This scenario is much more "heavy" to execute symbolically, but you can expect it to complete in half a day on a powerful machine. In addition to the above `3.1.1`, this scenario can detect vulnerability `3.3.2`: after `deposit()`, some symbolic function is called from the `symbolic_vault`, which in turn changes the current `vault` of `alice` via `setUserConfigurationOnBehalfOf ` and breaks `shares` of `alice`.
3. Depth of 1, reentrancy with depth of 1, **NoDuplicateCalls** disabled

    Essentially the same test as above, but this time we turned off the duplicate function heuristic. It can find the same vulnerabilities, but in different scenarios and takes much longer. I couldn't wait for it to finish on my machine:
    ```solidity
    /* Should find 3.1.1 and 3.3.2. Long test */
    function check_BalanceIntegrityWithReentrancyNoDuplicateCallsDisabled() external {
        vm.startPrank(getConfigurer());
        halmosHelpersSetSymbolicCallbacksDepth(1, 1);
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegritySize");
        vm.stopPrank();

        vaultSoladyBalanceNotBrokenInvarint();
    }
    ```
4. Full test

    Added all known contract addresses in the `setUp()` as targets, increased the test depth to 2, the recursion depth of fallbacks to 2. Also, callbacks will execute 2 functions inside. I don't think such a test can be done in a reasonable amount of time, but it just shows a possible way to extend the test. Any of the previous tests can be extended further     incrementally by adding options from the **Full** test:
    ```solidity
    /* 
    * Theoretically, this test should find 3.1.1 and 3.3.2 in all forms (via reentrancy and trivially) in some time. 
    * However, given that we have a lot of targets, there is no certainty that this test will be completed even in six months.
    * It is also necessary to investigate all symbolic execution bottlenecks in these contracts and handle them.
    * It should be perceived as just a way to expand the scenarios for testing, not an actual test to run.
    */
    function check_BalanceIntegrityFull() external {
        vm.startPrank(getConfigurer());
        halmosHelpersSetSymbolicCallbacksDepth(2, 2);
        for (uint i = 0; i < actors.length; i++) {
            actors[i].setSymbolicFallbackTxsNumber(2);
            actors[i].setSymbolicReceiveTxsNumber(2);
        }
        for (uint i = 0; i < vaults.length; i++) {
            actors[i].setSymbolicFallbackTxsNumber(2);
            actors[i].setSymbolicReceiveTxsNumber(2);
        }
        halmosHelpersRegisterTargetAddress(address(collateral), "ERC20Mock");
        halmosHelpersRegisterTargetAddress(address(priceFeed), "PriceFeedMock");
        halmosHelpersRegisterTargetAddress(address(weth), "ERC20Mock");
        halmosHelpersRegisterTargetAddress(address(usdc), "WETH");
        halmosHelpersRegisterTargetAddress(address(variablePool), "IPool");
        halmosHelpersRegisterTargetAddress(address(token), "NonTransferrableRebasingTokenVault");
        halmosHelpersRegisterTargetAddress(address(sizeFactory), "SizeFactory");
        halmosHelpersRegisterTargetAddress(address(implementation), "Size");
        halmosHelpersRegisterTargetAddress(address(erc4626Adapter), "ERC4626Adapter");
        halmosHelpersRegisterTargetAddress(address(aaveAdapter), "AaveAdapter");
        halmosHelpersRegisterTargetAddress(address(vaultSolady), "IERC4626");
        halmosHelpersRegisterTargetAddress(symbolic_vault, "SymbolicActor");
        halmosHelpersRegisterTargetAddress(address(proxy), "ERC1967Proxy");
        halmosHelpersRegisterTargetAddress(address(collateral), "ERC20Mock");

        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegrityFull_1");
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegrityFull_2");
        vm.stopPrank();

        vaultSoladyBalanceNotBrokenInvarint();
    }
    ```
5. DoS test

    Separately, I will say that any of the scenarios above easily finds the `3.3.3` vulnerability, since it does not require any transaction before the **invariant** (halmos finds the **DoS** scenario just inside the **invariant** itself).

    This scenario stands out a bit from the others:
    ```solidity
    function check_marketCanSetValidVault() external {
        bool res;
        bytes memory retdata;

        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_marketCanSetValidVault");
        vm.stopPrank();

        /* market should be able to change vault for any valid user */
        address user = _svm.createAddress("user");
        vm.assume(user != address(0x0));
        vm.assume(token.vaultOf(user) != address(vaultSolady));
        bytes memory setVault_calldata = abi.encodeWithSelector(token.setVault.selector, user, address(vaultSolady));

        vm.prank(address(size));
        (res, retdata ) = address(token).call(setVault_calldata);

        assert(res == true);
    }
    ```
## Halmos run
We run halmos with the following parameters:
```javascript
halmos --solver-timeout-assertion 2000 --solver-timeout-branching 2000 --function check_<function_name> --default-bytes-lengths 1024 -vv
```
It has been experimentally shown that giving the solver 2 seconds for **branching** and **assertion** should be enough to find counterexamples and not "hang" when SMT is too complex. Standard values ​​are not suitable for this test.

`--default-bytes-lengths 1024`. This parameter helps to save on the number of paths. The logic of this protocol does not depend on the size of the transmitted byte arrays, so we simply make the assumption that an array bytes of size `1024` should be enough for everything.

`-vv` is used to print full trace of execution path that broke the invariant.
## Key addresses
Before moving on to counterexamples and their analysis, it is worth specifying the addresses and their corresponding contracts from the test:
```javascript
0xaaaa001c - alice
0xaaaa001d - bob
0xaaaa001e - symbolic vault
0xaaaa0029 - size
0xaaaa002c - adapter
0xaaaa0025 - Underlying token (USDC)
```
## 3.1.1 counterexample analysis
The full halmos log can be found [here](https://gist.github.com/igorganich/22c2f2e24caf10a18db2abf60a4b6c11)

There are 2 similar counterexamples here, we will only analyze the counterexample with `setUserConfigurationOnBehalfOf()`.
```javascript
Counterexample: 
    halmos_ETH_val_uint256_a531e05_18 = 0x00
    halmos_GlobalStorage_selector_bytes4_17d1c25_19 = 0xc7cd4d87
    halmos_batch_prank_addr_address_ac8301a_16 = 0xaaaa001c
    halmos_check_balanceIntegritySize_address_f29c46d_17 = 0xaaaa0029
    halmos_fallback_is_empty_bool_0b4e934_05 = 0x01
    halmos_fallback_is_empty_bool_494af02_11 = 0x01
    halmos_fallback_is_empty_bool_60d74d5_02 = 0x01
    halmos_fallback_is_empty_bool_ac7c59f_08 = 0x01
    halmos_fallback_is_empty_bool_b6f2233_212 = 0x01
    halmos_fallback_is_empty_bool_d51a2a9_14 = 0x01
    halmos_fallback_retdata_bytes_03ec0f5_12 = 0x80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    halmos_fallback_retdata_bytes_4d5326b_06 = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffff8000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    halmos_fallback_retdata_bytes_5c55208_213 = 0x00
    halmos_fallback_retdata_bytes_f359e46_03 = 0xaaaa00220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    halmos_fallback_selector_bytes4_18f3654_13 = 0x7a2d13a
    halmos_fallback_selector_bytes4_24e5f0e_10 = 0x70a08231
    halmos_fallback_selector_bytes4_c4fc4f6_04 = 0x70a08231
    halmos_fallback_selector_bytes4_cc57fe9_01 = 0x38d52e0f
    halmos_fallback_selector_bytes4_efaa880_211 = 0x7a2d13a
    halmos_fallback_selector_bytes4_f27dc8f_07 = 0x6e553f65
    p_externalParams.onBehalfOf_address_423501a_196 = 0xaaaa001c
    p_externalParams.params.allCreditPositionsForSaleDisabled_bool_1c01e5f_191 = 0x01
    p_externalParams.params.creditPositionIdsForSale_bool_a65f308_192 = 0x01
    p_externalParams.params.creditPositionIds_length_a988697_193 = 0x00
    p_externalParams.params.openingLimitBorrowCR_uint256_36f3b10_190 = 0x00
    p_externalParams.params.vault_address_a57bb47_189 = 0xaaaa002e
```
Let's look at the key points of symbolic execution that allowed halmos to find a counterexample.
### SetUp() symbolic shares
Take a look to this `deposit()` process of `alice`:
```solidity
vm.startPrank(alice);
usdc.approve(address(size), USDC_INITIAL_BALANCE);
size.deposit(DepositParams({token: address(usdc), amount: USDC_INITIAL_BALANCE / 2, to: alice}));
...
```
```solidity
function depositOnBehalfOf(DepositOnBehalfOfParams memory params) {
        ...
        state.executeDeposit(params);
    }
```
```solidity
function deposit(address vault, address to, uint256 amount) external onlyOwner returns (uint256 assets) {
        ...
        IERC4626(vault).deposit(amount, address(tokenVault));

        uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - vars.sharesBefore;
        tokenVault.setSharesOf(to, vars.userSharesBefore + shares);
    }
```
Let's see how the `symbolic_vault` processed the deposit:
```javascript
CALL ERC1967Proxy::deposit(...) (caller: 0xaaaa001c)
  ...
  DELEGATECALL ERC1967Proxy::executeDeposit(...) (caller: 0xaaaa001c)
  ...
     CALL 0xaaaa0025::deposit(...) (caller: ERC1967Proxy)
  ...
        STATICCALL 0xaaaa001e::balanceOf(...) (caller: 0xaaaa002c)
        ...
        ↩ RETURN halmos_fallback_retdata_bytes_4d5326b_06
```
As we can see from the logs, **symbolic vault** returned some symbolic value `halmos_fallback_retdata_bytes_4d5326b_06` of **alice's** balance (`balanceOf()` function). **ERC4626Adapter** stored this value as **alice's** current number of `shares`. Let's remember this value.
### Processing setUserConfigurationOnBehalfOf()
During symbolic execution halmos processes all entry points of the target. We will only consider `setUserConfigurationOnBehalfOf()`:
```solidity
function check_BalanceIntegrityNoReentrancy() external {
...
        halmosHelpersSymbolicBatchStartPrank(actors);
        executeSymbolicallyAllTargets("check_balanceIntegritySize");
        vm.stopPrank();
...
```
```javascript
 CALL HalmosSizeTest::check_BalanceIntegrityNoReentrancy() (caller: 0x1804c8ab1f12e6bbf3894d4083f33e07309d1f38)
 ...
    DELEGATECALL ERC1967Proxy::setUserConfigurationOnBehalfOf(Concat(0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000040, p_externalParams.onBehalfOf_address_423501a_196, p_externalParams.params.vault_address_a57bb47_189, p_externalParams.params.openingLimitBorrowCR_uint256_36f3b10_190, p_externalParams.params.allCreditPositionsForSaleDisabled_bool_1c01e5f_191, p_externalParams.params.creditPositionIdsForSale_bool_a65f308_192, 0x00000000000000000000000000000000000000000000000000000000000000a0, p_externalParams.params.creditPositionIds_length_a988697_193, p_externalParams.params.creditPositionIds[0]_uint256_0bb68e8_194, p_externalParams.params.creditPositionIds[1]_uint256_30eb88d_195)) (value: halmos_ETH_val_uint256_a531e05_18) (caller: halmos_batch_prank_addr_address_ac8301a_16)
```   
Before execution, all parameters are symbolic. As validations, constraints, etc. are processed, these symbolic parameters (including the `prank()` address) become more specific. In the counterexample itself, they are all concrete.
### setVault() processing
In one of the paths halmos found the opportunity to do `setVault()`:
```solidity
function setVault(address user, address vault) external onlyMarket {
        ...
            _transferFrom(vaultOf[user], vault, user, user, balanceOf(user));
        ...
            vaultOf[user] = vault;
        }
```
```solidity
function _transferFrom(address vaultFrom, address vaultTo, address from, address to, uint256 value) private {
    if (value > 0) {
        if (vaultFrom == vaultTo) {
            IAdapter adapter = getWhitelistedVaultAdapter(vaultFrom);
            adapter.transferFrom(vaultFrom, from, to, value);
        } else {
            IAdapter adapterFrom = getWhitelistedVaultAdapter(vaultFrom);
            IAdapter adapterTo = getWhitelistedVaultAdapter(vaultTo);
            // slither-disable-next-line unused-return
            adapterFrom.withdraw(vaultFrom, from, address(adapterTo), value);
            // slither-disable-next-line unused-return
            adapterTo.deposit(vaultTo, to, value);
        }
    }
}
```
In this path halmos considered the option that `user` is `alice`. So `vaultOf[user]` is `symbolic_vault`. Therefore, the `value` parameter in `_transferFrom()` is the result of the `symbolic_vault::balanceOf()` function. We have seen this pattern before. 

Let's see how halmos handled `setVault()`:
```javascript
CALL 0xaaaa0025::setVault(...) (caller: ERC1967Proxy)
...
    STATICCALL 0xaaaa002c::balanceOf(...) [static][0m (caller: 0xaaaa0025)
    ...
    RETURN Extract(0x1f3f, 0x1e40, halmos_fallback_retdata_bytes_5c55208_213)
    ...
```
Again `symbolic_vault::balanceOf()` returned the symbolic value `halmos_fallback_retdata_bytes_5c55208_213`. In this particular path halmos considered the possibility that `halmos_fallback_retdata_bytes_5c55208_213 == 0`. And this literally is the condition of the attack `3.1.1`. 

As a result:
1. `alice's` vault has been changed.
2. `sharesOf[alice]` has not changed anywhere, it is still `halmos_fallback_retdata_bytes_4d5326b_06`. 

### Invariant breaking
At this point, the invariant is easy to break. We know the exact **USDC** balance of `vaultSolady` and we know that `sharesOf[alice]` is a symbolic value that is not constrained by anything. We just need to pick a large enough value and the invariant will be broken. Halmos picked ` halmos_fallback_retdata_bytes_4d5326b_06 = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffff80000......000`. 

Vulnerability reproduced!
## 3.3.2 counterexample analysis
The essence of the `3.2.2` vulnerability reproduction is very similar to `3.1.1`, but there is a key difference: You need to use a test with support for callbacks by **symbolic vault**. 

We will consider [part of the log](https://gist.github.com/igorganich/069fda8de9a5e2b76134f40b6f3ab68c) that is generated by running the test function `check_BalanceIntegrityWithReentrancyNoDuplicateCallsEnabled()`. The full log is too large, overloaded, and there is no point in looking at all the duplicate counterexamples.

```javascript
halmos_ETH_val_uint256_4a429ed_18 = 0x00
    halmos_ETH_val_uint256_ecad954_218 = 0x00
    halmos_GlobalStorage_selector_bytes4_461be31_219 = 0xc7cd4d87
    halmos_GlobalStorage_selector_bytes4_6b4cf9d_19 = 0xcf8542f
    halmos_batch_prank_addr_address_afc9ae3_16 = 0xaaaa001d
    halmos_check_balanceIntegritySize_address_7f97a89_17 = 0xaaaa0029
    halmos_fallback_is_empty_bool_0075bcd_14 = 0x01
    halmos_fallback_is_empty_bool_528c080_419 = 0x01
    halmos_fallback_is_empty_bool_67e14d2_212 = 0x01
    halmos_fallback_is_empty_bool_6e19cf6_11 = 0x01
    halmos_fallback_is_empty_bool_6e5ce5f_412 = 0x01
    halmos_fallback_is_empty_bool_7235517_08 = 0x01
    halmos_fallback_is_empty_bool_9993aba_416 = 0x01
    halmos_fallback_is_empty_bool_a9b682a_215 = 0x00
    halmos_fallback_is_empty_bool_ba35b42_05 = 0x01
    halmos_fallback_is_empty_bool_c4b65bc_02 = 0x01
    halmos_fallback_is_revert_bool_18b5a3d_216 = 0x00
    halmos_fallback_retdata_bytes_471ae07_06 = 0x00
    halmos_fallback_retdata_bytes_6887436_417 = 0x80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    halmos_fallback_retdata_bytes_95474c5_413 = 0x00
    halmos_fallback_retdata_bytes_bca175b_213 = 0x00
    halmos_fallback_retdata_bytes_d499086_03 = 0xaaaa00220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    halmos_fallback_retdata_bytes_db6c3da_12 = 0x00
    halmos_fallback_selector_bytes4_136534d_415 = 0x70a08231
    halmos_fallback_selector_bytes4_13679f1_411 = 0x7a2d13a
    halmos_fallback_selector_bytes4_52d88c6_418 = 0x7a2d13a
    halmos_fallback_selector_bytes4_5753c58_211 = 0x70a08231
    halmos_fallback_selector_bytes4_9786b66_214 = 0x6e553f65
    halmos_fallback_selector_bytes4_986e829_10 = 0x70a08231
    halmos_fallback_selector_bytes4_a34164a_07 = 0x6e553f65
    halmos_fallback_selector_bytes4_b04bf0b_13 = 0x7a2d13a
    halmos_fallback_selector_bytes4_b5a0882_04 = 0x70a08231
    halmos_fallback_selector_bytes4_fd18221_01 = 0x38d52e0f
    halmos_fallback_target_address_dd71d4b_217 = 0xaaaa0029
    p_externalParams.onBehalfOf_address_d4dce10_396 = 0xaaaa001c
    p_externalParams.params.allCreditPositionsForSaleDisabled_bool_e868154_391 = 0x01
    p_externalParams.params.creditPositionIdsForSale_bool_72f6795_392 = 0x01
    p_externalParams.params.creditPositionIds_length_8bf027a_393 = 0x00
    p_externalParams.params.openingLimitBorrowCR_uint256_8c33c38_390 = 0x00
    p_externalParams.params.vault_address_8ab8556_389 = 0xaaaa002e
    p_params.amount_uint256_ccf4925_91 = 0x4000000000
    p_params.to_address_fedf92e_92 = 0xaaaa001c
    p_params.token_address_0249170_90 = 0xaaaa0022
```
Let's look at the key points of symbolic execution that allowed halmos to find a counterexample.
### deposit symbolic processing
In this case, halmos began his journey to a counterexample with `Size::deposit()`:
```solidity
function check_BalanceIntegrityWithReentrancyNoDuplicateCallsEnabled() external {
    ...
    halmosHelpersSymbolicBatchStartPrank(actors);
    executeSymbolicallyAllTargets("check_balanceIntegritySize");
    vm.stopPrank();
```
```javascript
...
CALL ERC1967Proxy::deposit(Concat(p_params.token_address_0249170_90, p_params.amount_uint256_ccf4925_91, p_params.to_address_fedf92e_92)) (caller: halmos_batch_prank_addr_address_afc9ae3_16)
...
```
So far, all parameters and even `caller` are symbolic values.
```solidity
function depositOnBehalfOf(DepositOnBehalfOfParams memory params) {
    ...
    state.executeDeposit(params);
}
```
```solidity
function executeDeposit(State storage state, DepositOnBehalfOfParams memory externalParams) public {
    ...
    amount = state.data.borrowTokenVault.deposit(params.to, amount);
}
```
```solidity
function deposit(address to, uint256 amount) external onlyMarket returns (uint256 assets) {
    ...
    assets = adapter.deposit(vaultOf[to], to, amount);
    ...
}
```
```javascript
DELEGATECALL ERC1967Proxy::executeDeposit(..., halmos_batch_prank_addr_address_afc9ae3_16)(caller: halmos_batch_prank_addr_address_afc9ae3_16)
...
    CALL 0xaaaa0025::deposit(...) (caller: ERC1967Proxy)
    ...
        CALL 0xaaaa002c::deposit(...) (caller: 0xaaaa0025)
```
### external calls to symbolic vault in deposit()
```solidity
function deposit(address vault, address to, uint256 amount) external onlyOwner returns (uint256 assets) {
    // slither-disable-next-line uninitialized-local
    Vars memory vars;
    vars.sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
    vars.userSharesBefore = tokenVault.sharesOf(to);

    underlyingToken.forceApprove(vault, amount);
    // slither-disable-next-line unused-return
    IERC4626(vault).deposit(amount, address(tokenVault));

    uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - vars.sharesBefore;
    assets = IERC4626(vault).convertToAssets(shares);

    tokenVault.setSharesOf(to, vars.userSharesBefore + shares);
}
```
Similar to the previous scenario, in this path halmos considered the option that `to` is `alice`. So `vault` is `symbolic_vault`.

This place is the critical point of the entire attack. Here we have 4 external calls to the `symbolic_vault`:
1. view functions (`balanceOf()`, `convertToAssets()`). We already know that they return a symbolic unbounded value. We are only interested in:
    ```solidity
    vars.sharesBefore = IERC4626(vault).balanceOf(address(tokenVault));
    vars.userSharesBefore = tokenVault.sharesOf(to);
    ...
    uint256 shares = IERC4626(vault).balanceOf(address(tokenVault)) - vars.sharesBefore;
    ...
    tokenVault.setSharesOf(to, vars.userSharesBefore + shares);
    ```
    It's not hard to guess that `tokenVault.setSharesOf()` will take a symbolic value, completely controlled by what the **symbolic vault** returned.

2. non-view `deposit()` function. Inside it does reentrancy and sets up another `vault` for **alice**. We will discuss this in more detail in the next section.
### symbolic vault reentrancy processing
If the `fallback()` processing depth is enabled at least `1`, the **symbolic vault** will start making external calls to all targets (in this case, only **Size**).
```solidity
contract SymbolicActor is HalmosHelpersTargetsExecutor {
    ...
    fallback() external payable {
        ...
        for (uint8 i = 0; i < symbolic_fallback_txs_number; i++) {
            ...
            executeSymbolicallyAllTargets("fallback_target");
            ...
        }
        ...
    }
}
```
And in this path, it executed a symbolic call to the `setUserConfigurationOnBehalfOf()` function, changing **alice's** `vault` to `vaultSolady`. We have already discussed the mechanics of processing such a symbolic call above, so I will not dwell on it.
```javascript
CALL 0xaaaa001e::deposit(...) (caller: 0xaaaa002c)
...
    CALL ERC1967Proxy::setUserConfigurationOnBehalfOf(...) (caller: 0xaaaa001e)
    ...
```

At this stage, we have met all the conditions for a broken invariant: the sum of all shares in `vaultSolady` far exceeds its `balance`.

This vulnerability is reproduced as well.

## 3.3.3 counterexample analysis
Part of the log from `check_marketCanSetValidVault` test is [here](https://gist.github.com/igorganich/42f5d224dd059b13f2e738a303f1cb3c).

```javascript
Counterexample: 
    halmos_ETH_val_uint256_0de56e1_18 = 0x00
    halmos_GlobalStorage_selector_bytes4_25b6a1e_19 = 0xf54ae18b
    halmos_batch_prank_addr_address_d778c5f_16 = 0xaaaa001d
    halmos_check_balanceIntegrity_address_90c0a95_17 = 0xaaaa0029
    halmos_fallback_is_empty_bool_0aebb84_05 = 0x01
    halmos_fallback_is_empty_bool_1351415_08 = 0x01
    halmos_fallback_is_empty_bool_73e2d03_14 = 0x01
    halmos_fallback_is_empty_bool_e914145_213 = 0x00
    halmos_fallback_is_empty_bool_e992075_11 = 0x01
    halmos_fallback_is_empty_bool_fc561eb_02 = 0x01
    halmos_fallback_is_revert_bool_93d68a2_214 = 0x01
    halmos_fallback_retdata_bytes_1fa8c99_12 = 0x00
    halmos_fallback_retdata_bytes_3bafb63_06 = 0x00
    halmos_fallback_retdata_bytes_5889562_03 = 0xaaaa00220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
    halmos_fallback_selector_bytes4_0cb1eac_04 = 0x70a08231
    halmos_fallback_selector_bytes4_37b0a56_07 = 0x6e553f65
    halmos_fallback_selector_bytes4_3ae211c_13 = 0x7a2d13a
    halmos_fallback_selector_bytes4_819d424_212 = 0x7a2d13a
    halmos_fallback_selector_bytes4_81fcee9_10 = 0x70a08231
    halmos_fallback_selector_bytes4_93dfcd2_01 = 0x38d52e0f
    halmos_user_address_e855eb4_211 = 0xaaaa001c
    p_externalParams.onBehalfOf_address_90dc7d3_210 = 0xaaaa001d
    p_externalParams.params.amount_uint256_f7db607_208 = 0x8000000000000000000000000000000000000000000000000000000000000000
    p_externalParams.params.to_address_e7f674e_209 = 0x8000000000000000000000000000000000000000
    p_externalParams.params.token_address_f2ba346_207 = 0xaaaa0022
```

As already written above, halmos finds a counterexample regardless of what was done before the invariant check. Therefore, we will consider only the part of the invariant check:
```solidity
address user = _svm.createAddress("user");
vm.assume(user != address(0x0));
vm.assume(token.vaultOf(user) != address(vaultSolady));
bytes memory setVault_calldata = abi.encodeWithSelector(token.setVault.selector, user, address(vaultSolady));

vm.prank(address(size));
(res, retdata ) = address(token).call(setVault_calldata);

assert(res == true);
```
### setVault symbolic processing
```solidity
(res, retdata ) = address(token).call(setVault_calldata);
```
```javascript
CALL 0xaaaa0025::setVault(Concat(0x000000000000000000000000, halmos_user_address_e855eb4_211, 0x00000000000000000000000000000000000000000000000000000000aaaa002e)) (caller: ERC1967Proxy)
```
This time we have a specific `caller` and a specific `vault`. Only `user` is symbolic, but restricted to not being `0x0` and its current `vault` is not `soladyVault`.
### call to symbolic_vault::convertToAssets()
In one of the paths halmos considered the possibility that `user` is `alice`, which means you need to call `convertToAssets()` from `alice's` vault, i.e. `symbolic_vault`:
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function setVault(address user, address vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (vaultToIdMap.contains(vault) && vaultOf[user] != vault) {
            // slither-disable-next-line reentrancy-no-eth
            _transferFrom(vaultOf[user], vault, user, user, balanceOf(user));

            emit VaultSet(user, vaultOf[user], vault);
            vaultOf[user] = vault;
        }
    }
...
}
```
```solidity
contract NonTransferrableRebasingTokenVault {
...
    function balanceOf(address account) public view returns (uint256) {
        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[account]);
        return adapter.balanceOf(vaultOf[account], account);
    }
...
}
```
```solidity
contract ERC4626Adapter {
...
    function balanceOf(address vault, address account) public view returns (uint256) {
        return IERC4626(vault).convertToAssets(tokenVault.sharesOf(account));
    }
...
}
```
```javascript
CALL 0xaaaa0025::setVault(...) (caller: ERC1967Proxy)
...
    STATICCALL 0xaaaa002c::balanceOf(...) (caller: 0xaaaa0025)
    ...
        STATICCALL 0xaaaa001e::convertToAssets(...) (caller: 0xaaaa002c)
        ...
```
### revert in symbolic_vault::convertToAssets
**SymbolicActor** considers different scenarios of what might happen during the execution of a symbolic function. One option is to simply `revert()`:
```solidity
fallback() external payable {
    ...
    bool is_revert = _svm.createBool("fallback_is_revert");
    if (false == is_revert) {
        ...
    } else {
        revert();
    }
    ...
}
```
This is exactly what happened in the counterexample:
```javascript
...
        STATICCALL 0xaaaa001e::convertToAssets
            ...
            Concat(0x0000000000000000000000000000000000000000000000000000000000000000, halmos_fallback_is_revert_bool_93d68a2_214)
        REVERT (error: Revert())
    REVERT (error: Revert())
REVERT (error: Revert())
```
Thus, the call transaction returned `false` and the invariant was broken:
```solidity
(res, retdata ) = address(token).call(setVault_calldata);

assert(res == true);
```
## Full code
The entire test can be found in [this PR](https://github.com/SizeCredit/size-solidity/pull/188/files)
