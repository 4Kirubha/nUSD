//SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.18;

import { ERC20Burnable, ERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
/**
*@title NUSD
*@author Kirubha Karan
*/
contract NUSD is ERC20Burnable,Ownable {
    error NUSD__MustBeGreaterThanZero();
    error NUSD__BurnAmountExceedsBalance();
    error NUSD__NotZeroAddress();

    constructor() ERC20("NUSD","nUSD") {}

    function burn(uint256 _amount) public override onlyOwner{
        uint256 balance = balanceOf(msg.sender);
        if(_amount <= 0){
            revert NUSD__MustBeGreaterThanZero();
        }
        if(balance < _amount){
            revert NUSD__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to,uint256 _amount) external onlyOwner returns (bool){
        if(_to == address(0)){
            revert NUSD__NotZeroAddress();
        }
        if(_amount <= 0){
            revert NUSD__MustBeGreaterThanZero();
        }
        _mint(_to,_amount);
        return true;
    } 
}