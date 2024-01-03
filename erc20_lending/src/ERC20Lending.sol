// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract ERC20Lending {
    error ERC20Lending__ApprovalFailed();
    error ERC20Lending__DepositFailed();
    error ERC20Lending__WithdrawFailed();
    error ERC20Lending__BorrowFailed();
    error ERC20Lending__ReturnFailed();
    error ERC20Lending__InsufficientBalance();
    error ERC20Lending__WrongAmount();

    event ERC20Lending__TokenDeposited(address indexed _from, uint256 _amount);
    event ERC20Lending__TokenWithdrawn(address indexed _to, uint256 _amount);
    event ERC20Lending__TokenBorrowed(address indexed _to, uint256 _amount);
    event ERC20Lending__TokenReturned(address indexed _from, uint256 _amount);
    event ERC20Lending__TokenSet(address indexed _token);

    address public token;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public borrowings;

    function setToken(address _token) public {
        token = (_token);
        emit ERC20Lending__TokenSet(_token);
    }

    function depositToken(uint256 _amount) public payable {
        (bool approvalSuccess,) =
            address(token).call(abi.encodeWithSignature("approve(address,uint256)", address(this), _amount));
        if (!approvalSuccess) {
            revert ERC20Lending__ApprovalFailed();
        }

        balances[msg.sender] += _amount;

        (bool success,) = address(token).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount)
        );

        if (!success) {
            revert ERC20Lending__DepositFailed();
        } else {
            emit ERC20Lending__TokenDeposited(msg.sender, _amount);
        }
    }

    function withdrawToken(uint256 _amount) public {
        if (balances[msg.sender] < _amount) {
            revert ERC20Lending__InsufficientBalance();
        }

        balances[msg.sender] -= _amount;

        (bool success,) = address(token).call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _amount));

        if (!success) {
            revert ERC20Lending__WithdrawFailed();
        } else {
            emit ERC20Lending__TokenWithdrawn(msg.sender, _amount);
        }
    }

    function borrowToken(uint256 _amount) public {
        if (_amount > IERC20(token).balanceOf(address(this))) {
            revert ERC20Lending__InsufficientBalance();
        }

        borrowings[msg.sender] += _amount;

        (bool success,) = address(token).call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _amount));

        if (!success) {
            revert ERC20Lending__BorrowFailed();
        } else {
            emit ERC20Lending__TokenBorrowed(msg.sender, _amount);
        }
    }

    function repayToken(uint256 _amount) public {
        if (_amount != borrowings[msg.sender]) revert ERC20Lending__WrongAmount();

        borrowings[msg.sender] -= _amount;

        (bool success,) = address(token).call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), _amount)
        );

        if (!success) {
            revert ERC20Lending__ReturnFailed();
        } else {
            emit ERC20Lending__TokenReturned(msg.sender, _amount);
        }
    }
}
