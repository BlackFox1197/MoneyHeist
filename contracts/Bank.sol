//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";

// struct Account {
//     uint256 balance;
//     uint lastInterestUpdate;
// }

contract Bank is IBank {
    mapping(address => Account) accountBalancesEth;
    mapping(address => Account) accountBalancesHak;

    mapping(address => uint256) accountBorrowedEth;
    mapping(address => uint256) accountBorrowesHak;

    // modifier updatesInterest {
    //     if (token == hakToken) {
    //     let blocksPassed = msg.block - 
    //     _;
    // }

    function getAccount(address token) private view returns (Account storage) {
        if (token == hakToken) {
            return accountBalancesHak[msg.sender];
        // TODO: is this compare secure?
        } else if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            return accountBalancesEth[msg.sender];
        } else {
            revert("token not supported");
        }
    }

    address payable hakToken;
    // TODO: Move eth address to a constant

    constructor(address _priceOracle, address payable _hakToken) {
        hakToken = _hakToken;
    }

    // TODO: Where does msg come from??
    // TODO: What is amount???
    // TODO: Comparison `==` secure??
    function deposit(address token, uint256 amount)
        payable
        external
        override
        returns (bool) {
            // TODO: is memory correct here?
            Account storage account = getAccount(token);
            if (token == hakToken) {
                account.deposit += amount;
                // TODO: Check that the sender has the amount?
                hakToken.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount));
            } else  {
                // TODO: is this secure??? no transfer?
                account.deposit += msg.value;
            }
            return true;
        }

    function withdraw(address token, uint256 amount)
        external
        override
        returns (uint256) {
            // TODO: Update to also consider account.interest; need to move from interest => deposit?
            Account storage account = getAccount(token);
            if (account.deposit == 0) {
                revert("no balance");
            }
            if (amount > account.deposit) {
                revert("amount exceeds balance");
            }
            account.deposit -= amount;
            if (token == hakToken) {
                // TODO: Check that the sender has the amount?
                hakToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
            } else  {
                // TODO: Payout ETH
            }
        }

    function borrow(address token, uint256 amount)
        external
        override
        returns (uint256) {
            // if (token == hakToken) {
            //     if (accountBalancesHak[msg.sender] * 100/amount > 150) {
            //         revert("no colletaral");
            //     }
            //     else {
            //         accountBorrowesHak[msg.sender] + amount;
            //         payable(token).transfer(amount);
            //     }
            // }
            // else {
            //     if (accountBalancesEth[msg.sender] * 100/amount > 150) {
            //         revert("no colletaral");
            //     }
            //     else {
            //         accountBorrowedEth[msg.sender] + amount;
            //         payable(token).transfer(amount);
            //     }
            // }
        }

    function repay(address token, uint256 amount)
        payable
        external
        override
        returns (uint256) {}

    function liquidate(address token, address account)
        payable
        external
        override
        returns (bool) {}

    function getCollateralRatio(address token, address account)
        view
        public
        override
        returns (uint256) {}

    function getBalance(address token)
        view
        public
        override
        returns (uint256) {
            Account storage account = getAccount(token);
            return account.deposit;
        }
}
