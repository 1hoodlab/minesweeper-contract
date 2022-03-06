// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;


interface IMinesweeper {
    
    event BuyTurn(address indexed buyer, uint8 numberOfTurns);

    event OpenCell(address indexed player, uint key, uint256 cell);


    function buyTurn(uint8 numberOfTurns) payable external;

    function start() external;

    function openCell(uint key) external;


}