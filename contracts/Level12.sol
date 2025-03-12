// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract EntrantOne {
    function enter(address gatekeeperAddress, uint256 gasToUse, bytes8 gateKey) external {
        GatekeeperOne(gatekeeperAddress).enter{gas:gasToUse}(gateKey);
    }
}

interface GatekeeperOne {
  function enter ( bytes8 _gateKey ) external returns ( bool );
  function entrant (  ) external view returns ( address );
}
