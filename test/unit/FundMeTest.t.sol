// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "lib/forge-std/src/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
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

    function testMinimumDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    // proveravamo da li je owner isto sto msg.sender
    function testOwnerIsMsgSender() public {
        // console.log(fundMe.i_owner());
        // console.log(msg.sender);
        // assertEq(fundMe.i_owner(), msg.sender);
        // // adrese su razlicite zato sto msg.sender je onaj koji poziva contract u ovom slucaju
        // // fundmetest i zato ovo ne pije vodu i stavljamo da uporedjuje ownera sa adresom ovog contracta
        // // umesto sendera u fundme
        // ovo iznad je bilo zbog ovo ispod s address this
        // // zato sto smo povezali s deployfundme a on koristi FundMe fundMe hardcode verziju ovo s this vise ne koristimo i vracamo
        // // msg sender
        // assertEq(fundMe.i_owner(), address(this));
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    // kreiramo test da proverimo fund funkciju ako ne fundiramo dovoljno da revertuje
    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); // ovim kazemo da ocekujemo da sledeca linija koga treba da revertuje
        fundMe.fund(); // ako ne stavimo nikakvu vrednost automatski je 0, sto bi znacilo da ce da revertuje jer smo namestili da min bude $5
    }

    // kreiramo test u slucaju da posaljemo dovoljno dal ce da prepozna
    function testFundUpdatesFundedDataStructure() public {
        // posto je zbunjujuce ko je pozvao funkciju dal msg.sender ili FundMeTest (address(this) ispod) foundry ima prank metodu
        // gde kreiramo laznu adresu uz pomoc makeAddr (imas iznad to)
        vm.prank(USER); // to znaci da sledecu transakciju (TX) ce biti poslata od strane USER sto smo napravili iznad
        fundMe.fund{value: SEND_VALUE}();
        // uint256 amountFunded = fundMe.getAddressToAmountFunded(address(this));
        // stavljamo uint256 jer kad pogledas funkcijutu u fundme.sol vraca adresu (returns(uint256))

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);

        assertEq(amountFunded, SEND_VALUE);
    }

    // test da proverimo dal dodaje fundere u array of funders i pozivamo getFunders funkciju
    function testAddsFundersToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        // stavljamo address jer kad pogledas funkcijutu u fundme.sol vraca adresu (returns(address))
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    modifier funded() {
        // s ove 2 linije koda fundiramo s novac
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    // testiramo da samo owner moze da withdraw
    function testOnlyOwnerCanWithdraw() public funded {
        // stavljamo zamisljenu situaciju gde nas fejk akaunt (USER) pokusava da podigne pare i on nije owner
        // stavljamo revert i on skipuje prank i kaze ocekujem ovu narednu liniju tj gde je withdraw zato je prvo revert
        // da smo stavili prank prvo on bi reko da ocekjem da sam ja taj user koji withdrawuje i preskocio bi revert
        vm.expectRevert();
        vm.prank(USER);
        fundMe.withdraw();
    }

    // testiramo withdraw sa samo jednog fundera
    function testWithdrawWithSingleFunder() public {
        // kod testiranja treba da razmisljamo o 3 stvari:

        // Arrange - setup the test , postavljamo testat (u ovom slucaju prvo proveravamo nas balans pre nego da pozovemo withdraw)
        // i da bi mogli da ga uporedimo s balans posle obavljanje withdraw

        // pocetni balans ownera
        uint256 startingOwnerBallance = fundMe.getOwner().balance;
        // pocetni balans funda, koristimo fundme adresu jer ce koristimo USER lazni akaunt sto smo napravili i fundirali
        uint256 startingFundMeBalance = address(fundMe).balance;

        // Act - akciju koju zelimo test da obavi
        vm.startPrank(fundMe.getOwner()); // stavljamo da samo owner moze da pozove tu funkciju
        fundMe.withdraw(); // ovo je ono sto testiramo withdraw zapravo
        vm.stopPrank();

        // Assert - tvrdnju koju zelimo da potvrdimo (u ovom slucaju da je ostatak u fundu 0 kad se withdrawuje)
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        // zbir pocetnok fund balansa i owner balansa  treba da bude jednak sa krajnjim owner balansom
        assertEq(
            startingFundMeBalance + startingOwnerBallance,
            endingOwnerBalance
        );
    }

    // sad testiramo withdraw sa vise fundera
    function testWithdrawWithMultipleFunders() public funded {
        // ce kreiramo for petlju koja ce dodaje fundere
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank - stvaramo novu adresu
            // vm.deal - fundiramo tu novu adresu
            // umesto ta dva ce koristimo hoax koji kombinuje ta dva
            // ako ocemo da koristimo brojeve za adrese onda mora da koristimo uint160 umesto uint256
            // pocinjemo od 1 ne od 0 zato sto oce ponekad da izbaci gresku zbog necega(nisam lepo razumeo sto)
            // pravimo novu adresu s i koja krece od 1 pa navise
            hoax(address(i), SEND_VALUE);
            // fundiramo fundMe tj teja adrese
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        // Act
        // umesto samo prank ce stavimo start i stop prank i ce se izvrsi samo ono sto je izmedju ta dva
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        // Assert
        // ovo je slican princip s assertEq iz proslu funkciju
        assert(address(fundMe).balance == 0);
        assert(
            startingOwnerBalance + startingFundMeBalance ==
                fundMe.getOwner().balance
        );
    }

    function testWithdrawWithMultipleFundersCheaper() public funded {
        // ce kreiramo for petlju koja ce dodaje fundere
        // Arrange
        uint160 numberOfFunders = 10;
        uint160 startingFunderIndex = 1;

        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            // vm.prank - stvaramo novu adresu
            // vm.deal - fundiramo tu novu adresu
            // umesto ta dva ce koristimo hoax koji kombinuje ta dva
            // ako ocemo da koristimo brojeve za adrese onda mora da koristimo uint160 umesto uint256
            // pocinjemo od 1 ne od 0 zato sto oce ponekad da izbaci gresku zbog necega(nisam lepo razumeo sto)
            // pravimo novu adresu s i koja krece od 1 pa navise
            hoax(address(i), SEND_VALUE);
            // fundiramo fundMe tj teja adrese
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;
        // Act
        // umesto samo prank ce stavimo start i stop prank i ce se izvrsi samo ono sto je izmedju ta dva
        vm.startPrank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        vm.stopPrank();

        // Assert
        // ovo je slican princip s assertEq iz proslu funkciju
        assert(address(fundMe).balance == 0);
        assert(
            startingOwnerBalance + startingFundMeBalance ==
                fundMe.getOwner().balance
        );
    }
}

/* Kako da radimo s adresama van naseg sistema 4 nacina:
1. Unit - testiramo odredjen deo naseg koda (kao npr ovde testiramo jednu funkciju npr dal je verzija tacna)
2. Integration - testiramo kako nas kod radi sa drugim delovima naseg koda (moze se reci takodje da je to i integration jer nasa funkcija
poziva drugi contract u ovom slucaju FundMe i proverava dal vise contracta rade zajedno)
3. Forked - testiramo nas kod u simuliranu sredinu
4. Staging - testiramo nas kod u stvarnu sredinu (deployujemo na testnet ili mainnet i proveravamo dal sve radi kako treba) */
