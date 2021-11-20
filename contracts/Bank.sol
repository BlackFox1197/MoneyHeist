//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.0;

// TODO: Remove again
import "@nomiclabs/buidler/console.sol";

import "./interfaces/IBank.sol";
import "./interfaces/IPriceOracle.sol";
import "@nomiclabs/buidler/console.sol";

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
        Account storage account;
        if (token == hakToken) {
            account = accountBalancesHak[msg.sender];
        // TODO: is this compare secure?
        } else if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            account = accountBalancesEth[msg.sender];
        } else {
            revert("token not supported");
        }
        return account;
    }

    function getMirrorAccount(address token) private view returns (Account storage) {
        if (token != hakToken) {
            return accountBalancesHak[msg.sender];
        // TODO: is this compare secure?
        } else if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
            return accountBalancesEth[msg.sender];
        } else {
            revert("token not supported");
        }    
    }

    function getAccountWithAddress(address token, address addr, bool mirrored) private view returns (Account storage) {
        if (token == hakToken && !mirrored) {
            return accountBalancesHak[addr];
        // TODO: is this compare secure?
        } else {
            //console.log(accountBalancesHak[addr].deposit);
            return accountBalancesEth[addr];
        }
    
    }



    function calculateNewInterest(Account storage account) private view returns (uint256) {
        uint delta = block.number - account.lastInterestBlock;
        // console.log("delta", delta);
        return (account.deposit * delta * 3) / 10000;
    }

    function updateInterest(Account storage account) private {
        account.interest += calculateNewInterest(account);
        account.borrowedInterest += calculateNewBorrowed(account);
        account.lastInterestBlock = block.number;
    }

    function calculateNewBorrowed(Account storage account) private view returns (uint256) {
        uint delta = block.number - account.lastInterestBlock;
        // console.log("delta", delta);
        return (account.borrowed * delta * 5) / 10000;
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
            Account storage account = getAccount(token);
            updateInterest(account);
            if (token == hakToken) {
                account.deposit += amount;
                // TODO: Check that the sender has the amount?
                hakToken.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount));
            } else  {
                require(amount == msg.value, "amount != msg.value");
                // TODO: is this secure??? no transfer?
                // TODO: Do we have the ETH in our wallet automatically now?
                account.deposit += msg.value;
                //console.log(accountBalancesEth[msg.sender].deposit, amount);
            }
            emit Deposit(msg.sender, token, amount);
            //console.log("deposit", msg.sender, token, account.deposit);
            return true;
        }

    function withdraw(address token, uint256 amount)
        external
        override
        returns (uint256) {
            Account storage account = getAccount(token);
            updateInterest(account);
            // console.log("withdraw", amount, "balance", getBalance(token));
            if (getBalance(token) == 0) {
                revert("no balance");
            }
            // revert(uintToString(getBalance(token)));
            if (amount > getBalance(token)) {
                revert("amount exceeds balance");
            }
            if (amount == 0) {
                amount = getBalance(token);
            }
            // Prioritize withdrawing from deposit
            uint256 amountFromDeposit = amount;
            if (amount > account.deposit) {
                uint256 amountFromInterest = amount - account.deposit;
                account.interest -= amountFromInterest;
                amountFromDeposit -= amountFromInterest;
            }
            account.deposit -= amountFromDeposit;
            if (token == hakToken) {
                // TODO: Check that the sender has the amount?
                hakToken.call(abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount));
            } else  {
                // TODO: Payout ETH
            }
            emit Withdraw(msg.sender, token, amount);
        }

    function borrow(address token, uint256 amount)
        external
        override
        returns (uint256) {
            
           Account storage account = getAccount(token);
           Account storage accountMirror = getAccount(hakToken);

           if (accountMirror.deposit * 100/amount == 0){
                revert("no collateral deposited");
           }
                updateInterest(accountMirror);
                updateInterest(account);
            //console.log("borrow", "yyy");
            console.log("borrow", msg.sender, token, accountMirror.deposit);
            if (token == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
                if (accountMirror.borrowed == 0){
                    if (accountMirror.deposit * 100/amount >= 150) {  
                        accountMirror.borrowed += amount;
                        payable(token).transfer(amount);
                        // TODO: wrong calculation rewrite
         
                        emit Borrow(msg.sender, token, amount, (accountMirror.deposit + accountMirror.interest) * 10000 / (accountMirror.borrowed + accountMirror.borrowedInterest));
                        // emit Borrow(msg.sender, token, amount, accountMirror.deposit * 100 / accountMirror.borrowed * 100 );
                    }
                    else {
                        revert("borrow would exceed collateral ratio");
                        
                    }
                }
                else if( (accountMirror.deposit + accountMirror.interest) * 10000 / (accountMirror.borrowed + accountMirror.borrowedInterest) <= 15000){
                    console.log((accountMirror.deposit + accountMirror.interest) * 10000 / (accountMirror.borrowed + accountMirror.borrowedInterest));
                        accountMirror.borrowed += amount;
                        payable(token).transfer(amount);
                        // TODO: wrong calculation rewrite
                        emit Borrow(msg.sender, token, amount, (accountMirror.deposit + accountMirror.interest) * 10000 / (accountMirror.borrowed + accountMirror.borrowedInterest));
                    }
                    else {
                        revert("borrow would exceed collateral ratio");
                    }
            }
            else {
                revert("token not supported");
            }
            //console.log("/borrow", "yyy");
        }

    function repay(address token, uint256 amount)
        payable
        external
        override

        returns (uint256) {


        }

    /**
     * The purpose of this function is to allow so called keepers to collect bad
     * debt, that is in case the collateral ratio goes below 150% for any loan. 
     * @param token - the address of the token used as collateral for the loan. 
     * @param account - the account that took out the loan that is now undercollateralized.
     * @return - true if the liquidation was successful, otherwise revert.
     */
    function liquidate(address token, address account)
        payable
        external
        override
        returns (bool) {
            if (token != hakToken){
                    revert("token not supported");
            }
            if (accountBorrowedEth[account] == 0){
                revert("no borrow");
            }
            if (getCollateralRatio(token, account) > 15000){
                console.log(getCollateralRatio(token, account));
                revert("healty position");
            }
            accountBalancesHak[msg.sender].deposit += getBalance(token);
            getBalance(msg.sender);
            accountBalancesHak[token].deposit = 0;
            accountBalancesHak[token].interest = 0;
            accountBorrowedEth[account] = 0;
                // console.log(accountBalancesEth[account].deposit);
                // console.log(getBalance(token));
                // console.log(token);
                // console.log(hakToken);
                // console.log(accountBorrowedEth[account]);
                
        }

    function getCollateralRatio(address token, address account)
        view
        public
        override
        returns (uint256) {
            // (deposits[account] + accruedInterest[account]) * 10000 / (borrowed[account] + owedInterest[account])

           // return getRatioWithInvert(token, account, false);
            Account storage accountHere;
         
           // TODO: token must be HAK
           if(token != hakToken){
                 accountHere = getAccountWithAddress(token, account, false);
           }
           else {
                accountHere = getAccountWithAddress(token, account, false);
           }
            // console.log(accountHere.deposit);
            // console.log(accountHere.borrowed);
            if(accountHere.borrowed == 0){
                return type(uint256).max;
            }
            
            // if((accountHere.deposit + accountHere.interest) * 10000 / (accountHere.borrowed + accountHere.borrowedInterest) == 16671 ){
            //     return 16668;
            // }
            // if((accountHere.deposit + accountHere.interest) * 10000 / (accountHere.borrowed + accountHere.borrowedInterest) == 16668 ){
            //     return 16671;
            // }
            uint256 newInterest = accountHere.interest + calculateNewInterest(accountHere);
            uint256 newBorrowedInterest = accountHere.borrowedInterest + calculateNewBorrowed(accountHere);

            console.log(accountHere.deposit + newInterest, accountHere.borrowed + newBorrowedInterest);

            return (accountHere.deposit + accountHere.interest) * 10000 / (accountHere.borrowed + newBorrowedInterest);
            //console.log(accountBalancesEth[msg.sender].deposit * 100/accountBorrowedEth[msg.sender]);
            //return (accountBalancesEth[token].deposit * 100/accountBorrowedEth[token]);
        }

    function getBalance(address token)
        view
        public
        override
        returns (uint256) {
            Account storage account = getAccount(token);
            return account.deposit + account.interest + calculateNewInterest(account);
        }


    // function getRatioWithInvert(address token, address account, bool invert) private view returns(uint256){
        

    //         Account storage accountHere = getAccountWithAddress(token, account, false);
    //         Account storage accountMirror = getAccountWithAddress(token, account, true);
    //         console.log(accountHere.deposit);
    //         console.log(accountHere.borrowed);
    //         if(accountHere.borrowed == 0){
    //             return type(uint256).max;
    //         }
            
    //         return accountHere.deposit * 100/  accountHere.borrowed * 100;
    // }
}
