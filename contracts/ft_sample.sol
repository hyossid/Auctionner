pragma solidity ^0.8.0;
import "hardhat/console.sol";

contract Token {
  string public name = "Sidney_Token";
  string public symbol = "STK";
  uint public totalSupply = 100000;
  address public owner;
  mapping(address => uint) balances;

  constructor() {
    balances[msg.sender] = totalSupply;
    owner = msg.sender;
  }

  function transfer(address to, uint amount) external {
    console.log("Sender balance is %s tokens", balances[msg.sender]);
    require(balances[msg.sender] >= amount, "Not enough tokens");

    balances[msg.sender] -= amount;
    balances[to] += amount;
  }

  function balanceOf(address account) external view returns (uint) {
    return balances[account];
  }
}
