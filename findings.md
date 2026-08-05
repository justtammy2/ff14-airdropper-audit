# FF#14 AirDropper - Audit Findings

Personal audit exercise on CodeHawks First Flight #14 (AirDropper).
Part of my 100-day security research sprint.

Target: src/MerkleAirdrop.sol
Contest link: https://codehawks.cyfrin.io/c/2024-04-airdropper

## [H-1] Missing state tracking in claim() allows repeated claims and full drain of the airdrop

**Severity**: High

**Impact**: Any caller can repeatedly re-claim the same allocation and drain the contract's entire USDC balance. The other three eligible users receive nothing.

**Vulnerability Details**:
claim() performs the fee check, Merkle proof verification, event emission, and token transfer, but never records that a claim occurred. There is no mapping, bitmap, or counter that tracks which addresses have already claimed. The Claimed event is emitted, but events are off-chain logs and cannot be read by the contract on subsequent calls.
Because the Merkle proof and inputs remain valid across calls, any caller can invoke claim(account, amount, proof) any number of times using an eligible address's public data. Each call transfers another 25e18 USDC to account until the contract's balance is exhausted.

**Proof of Concept**:
A passing Foundry test at pocs/test/MerkleAirdropTest.t.sol demonstrates the exploit. The test calls claim() twice from the same eligible user with the same proof; both calls succeed and the user's balance ends at 50e18 instead of 25e18.

```solidity
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

    // Second claim - should also succeed to prove the vulnerability (lack of state tracking)
    vm.prank(USER);
    airdrop.claim{value: 1e9}(USER, AMOUNT, proof);
    assertEq(
        token.balanceOf(USER),
        balanceBefore + 2 * AMOUNT,
        "second claim failed"
    );
}
```

Result:

```
[PASS] test_H1_UserCanClaimTwice() (gas: 86755)
```

**Recommended Mitigation**:
Track claim status with a mapping keyed by claimant address. Check it before any expensive work and set it before the token transfer, following the checks-effects-interactions pattern:

```diff
+    error MerkleAirdrop__AlreadyClaimed();
+
+    mapping(address => bool) private s_hasClaimed;

     function claim(
         address account,
         uint256 amount,
         bytes32[] calldata merkleProof
     ) external payable {
         if (msg.value != FEE) {
             revert MerkleAirdrop__InvalidFeeAmount();
         }
+        if (s_hasClaimed[account]) {
+            revert MerkleAirdrop__AlreadyClaimed();
+        }
         bytes32 leaf = keccak256(
             bytes.concat(keccak256(abi.encode(account, amount)))
         );
         if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
             revert MerkleAirdrop__InvalidProof();
         }
+        s_hasClaimed[account] = true;
         emit Claimed(account, amount);
         i_airdropToken.safeTransfer(account, amount);
     }
```

## [H-2] Hardcoded Incorrect USDC address makes the airdrop unclaimable

**Severity**: High

**Impact**: The airdrop is undeliverable. Every claim() call reverts because the token address holds no code

**Vulnerability Details**:
Deploy.s.sol hardcodes the airdrop token address as 0x1D17CbCf0D6d143135be902365d2e5E2a16538d4. This is meant to be native USDC on zkSync Era, but the real native USDC address (per Circle's docs) is 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4. The two differ by a single character at position 18 — b vs a. The deploy-script address holds no code, no balance, and no transactions on zkSync Era. When claim() reaches i_airdropToken.safeTransfer(...), OpenZeppelin's SafeERC20 reverts because it requires the target to have code. Every claim fails.

**Proof of Concept**:
The bug is in Deploy.s.sol and can be verified without executing the contract.

1. Deploy script — hardcoded address:
   address public s_zkSyncUSDC = 0x1D17CbCf0D6d143135be902365d2e5E2a16538d4;
2. Real USDC address on zkSync (Circle): 0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4
   Source: https://developers.circle.com/stablecoins/usdc-contract-addresses
3. Deploy-script address on zkSync Era block explorer: 0x1D17CbCf0D6d143135be902365d2e5E2a16538d4
   Zero balance. Zero transactions. No code deployed.

**Recommended Mitigation**:
Correct the token address in Deploy.s.sol to the real native USDC address on zkSync Era:

```diff
-    IERC20 zkSyncUSDC = IERC20(0x1D17CbCf0D6d143135be902365d2e5E2a16538d4);
+    IERC20 zkSyncUSDC = IERC20(0x1d17CBcF0D6D143135aE902365D2E5e2A16538D4);
```

As additional hardening, add a check in the `MerkleAirdrop` constructor that reverts if the token address has no code deployed. This catches typos or misconfigurations at deployment rather than at first claim:

```diff
+    error MerkleAirdrop__TokenHasNoCode();

     constructor(bytes32 merkleRoot, IERC20 airdropToken) Ownable(msg.sender) {
+        if (address(airdropToken).code.length == 0) {
+            revert MerkleAirdrop__TokenHasNoCode();
+        }
         i_merkleRoot = merkleRoot;
         i_airdropToken = airdropToken;
     }
```

## [L-1] Missing input validation in constructor allows deployment with zero values

**Severity**: Low

**Impact**: If deployed with a zero address for airdropToken or a zero value for merkleRoot, the contract is permanently non-functional and must be redeployed.

**Vulnerability Details**:
The constructor accepts airdropToken and merkleRoot and stores them in immutable state without checking for zero values. If airdropToken is address(0), every claim() call reverts on the token transfer. If merkleRoot is bytes32(0), no valid proof can verify against it. In either case, the contract is permanently non-functional and must be redeployed.

**Proof of Concept**:
The vulnerability is in the MerkleAirdrop constructor. It accepts merkleRoot and airdropToken as inputs and assigns them to state without any validation

```solidity
constructor(bytes32 merkleRoot, IERC20 airdropToken) Ownable(msg.sender) {
    i_merkleRoot = merkleRoot;
    i_airdropToken = airdropToken;
}
```

There is no check that airdropToken != address(0) or that merkleRoot != bytes32(0).

**Recommended Mitigation**:
Add two if checks at the top of the constructor to reject zero addresses and zero roots, each reverting with a custom error:

```diff
+    error MerkleAirdrop__InvalidMerkleRoot();
+    error MerkleAirdrop__InvalidTokenAddress();

     constructor(bytes32 merkleRoot, IERC20 airdropToken) Ownable(msg.sender) {
+        if (merkleRoot == bytes32(0)) {
+            revert MerkleAirdrop__InvalidMerkleRoot();
+        }
+        if (address(airdropToken) == address(0)) {
+            revert MerkleAirdrop__InvalidTokenAddress();
+        }
         i_merkleRoot = merkleRoot;
         i_airdropToken = airdropToken;
     }
```
