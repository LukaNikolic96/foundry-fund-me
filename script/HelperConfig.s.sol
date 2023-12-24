// Pravimo mocks da nebi hardkodovali adresu u deploy i da bi mogli da radimo s lokalnu anvil adresu
/* 1. Deploy mocks when we are on local anvil chain
2. Keep tracn of contract address across different chains like Sepolion ETH/USD or Mainnet ETH/USD */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    /* If we are on a local anvil, we deploy mocks, otherwise grab existing address from live network */
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2200e8;

    struct NetworkConfig {
        address priceFeed; // ETH/USD price feed address
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        // price feed address
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
        });
        return sepoliaConfig;
    }

    function getMainnetEthConfig() public pure returns (NetworkConfig memory) {
        // price feed address
        NetworkConfig memory mainnetConfig = NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        });
        return mainnetConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        /* ovo if stavljamo da ako pozovemo getanvilethconfig da proveri ako smo vec prethodno kreirali tu adresu da korisiti nju ako ne 
        da napravi novu */
        if(activeNetworkConfig.priceFeed != address(0)){
            return activeNetworkConfig;
        }
        // price feed address
        /* posto localna adresa nema contracte prvo moramo da deploy mocks (sto je fejk contract ili dummy contract) i 
        return mock adrese*/

        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed)
        });
        return anvilConfig;
    }
}
