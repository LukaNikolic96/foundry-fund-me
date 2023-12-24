// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol";

contract FundMeTestInteractions is Test {
    //stavljamo je van da bi mogli da je koristimo u vise testova
    FundMe fundMe;
    address USER = makeAddr("user"); // prakn user
    uint256 constant SEND_VALUE = 0.1 ether;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 constant GAS_PRICE = 1;

    // prvi test je da testiramo deploy
    function setUp() external {
        // /* povezujemo ga s deployfundme da kad god napravimo tamo neku promenu se automatski updejtuje da nemoramo mi manualno
        // i zbog toga ovo hardcode resenje ne koristimo vise */
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); // dajemo nasem useru fejk balans uz pomoz deal metode
    }

    // proveravamo dal moze da se fundira s nasu interactions skriptu
    function testUserCanFundInteractions() public {
        FundFundMe fundFundMe = new FundFundMe();
        fundFundMe.fundFundMe(address(fundMe));

WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
withdrawFundMe.withdrawFundMe(address(fundMe));

assert(address(fundMe).balance == 0);
    }
}