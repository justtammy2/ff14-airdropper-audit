# Hypotheses — FF#14 AirDropper

- H1 — claim() has no state tracking of who claimed. No mapping, no bitmap. Any caller (not just eligible users) can call claim() repeatedly with any eligible address and proof, draining USDC to that address. Other eligible users can't claim because contract is empty.
  Location: claim(), MerkleAirdrop.sol
  Severity guess: High

- H2 — Deploy script hardcodes wrong USDC address on zkSync (typo)
  Location: script/DeployMerkleAirdrop.s.sol (or wherever the address lives)
  Reasoning: Deploy script uses 0x1D17...be...38d4. Real native USDC on zkSync is 0x1d17...ae...38d4 per Circle's official docs. One character off. The address in the script has no code deployed at it — verified on zkSync explorer, zero balance and zero transactions. When deployed, safeTransfer reverts on every claim because SafeERC20 rejects targets with no code. Protocol is fully bricked.
  Severity guess: High (arguably Critical — 100% of intended functionality broken).

- claimFees() sends the whole contract balance, not a tracked fee total. Checked whether force-feeding ETH via selfdestruct could break anything — it can't. Owner just gets a bit extra. No invariant depends on the balance being exact. Dismissed.

- Leaf uses abi.encode(account, amount). Wondered about hash collisions. Not possible here — abi.encode pads everything to 32 bytes, and both inputs are static types anyway. Dismissed.

## Format

- **H#** — [one-line hypothesis]
  - **Location:** MerkleAirdrop.sol:LINE
  - **Reasoning:** why this feels off, one or two sentences
  - **Attack sketch (optional):** if you have a rough attack in mind

---
