// SPDX-License-Identifier: MIT
// Solidity Version Pragma
// Contract Declaration
// State Variables
// Mapping
// Functions
// Payable Keyword
// Global Objects
// Require Statements
// Transferring Ether
// Address Type
// Error Handling
// Comments

pragma solidity 0.8.20;

contract DeFiLending {
    error DeFiLending__ZeroAmount();
    error DeFiLending__ZeroAddress();
    error DeFiLending__InsufficientBalance();
    error DeFiLending__WithdrawalFailed();
    error DeFiLending__BorrowFailed();
    error DeFiLending__WrongAmount();

    event DeFiLending__Deposit(address indexed _user, uint256 _amount);
    event DeFiLending__WithdrawalSuccess(address indexed _user, uint256 _amount);
    event DeFiLending__BorrowlSuccess(address indexed _user, uint256 _amount);
    event DeFiLending__RepaylSuccess(address indexed _user, uint256 _amount);

    address public owner;

    mapping(address _user => uint256 _amount) public balances;
    mapping(address _user => uint256 _amount) public borrows;

    modifier isZeroAmount(uint256 _amount) {
        if (_amount == 0) {
            revert DeFiLending__ZeroAmount();
        }
        _;
    }

    function deposit() public payable isZeroAmount(msg.value) {
        uint256 _amount = msg.value;

        balances[msg.sender] += _amount;

        emit DeFiLending__Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) public isZeroAmount(_amount) {
        if (_amount < balances[msg.sender]) {
            revert DeFiLending__InsufficientBalance();
        }

        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert DeFiLending__WithdrawalFailed();
        } else {
            balances[msg.sender] -= _amount;
            emit DeFiLending__WithdrawalSuccess(msg.sender, _amount);
        }
    }

    function borrow(uint256 _amount) public isZeroAmount(_amount) {
        if (_amount < address(this).balance) {
            revert DeFiLending__InsufficientBalance();
        }
        borrows[msg.sender] += _amount;

        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert DeFiLending__BorrowFailed();
        } else {
            balances[msg.sender] -= _amount;
            emit DeFiLending__BorrowlSuccess(msg.sender, _amount);
        }
    }

    function repay(uint256 _amount) public isZeroAmount(_amount) {
        if (_amount < borrows[msg.sender]) {
            revert DeFiLending__WrongAmount();
        }

        borrows[msg.sender] -= _amount;

        emit DeFiLending__RepaylSuccess(msg.sender, _amount);
    }
}
