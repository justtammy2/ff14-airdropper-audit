# Recon — FF#14 AirDropper

## 0. Prediction (before reading anything)

What do I think this protocol does, based on folder/filename only?

## 1. What does the protocol do?

AirDropper distributes a fixed amount of USDC (25 USDC each) to a preset list of 4 eligible users. Eligibility is verified via a Merkle proof submitted to the claim function. Claiming requires paying a 1e9 wei fee. The contract owner is the only address permitted to withdraw the accumulated fees.

## 2. Who are the actors?

- Claimers: 4 addresses on the Merkle tree. Call claim() to receive 25 USDC each.
- Owner: whoever deploys the contract. Can withdraw the ETH fees users pay when claiming.
- Merkle tree builder: whoever runs makeMerkle.js off-chain and sets the root at deployment. Not on-chain, but the whole system trusts they built the tree correctly.
- Anyone else: can call claim() with any inputs. The Merkle proof check is the only thing stopping them.

## 3. Contracts and their purpose

- MerkleAirdrop.sol — the whole protocol. Handles claim verification, USDC transfer, fee collection, and owner withdrawal.

## 4. Functions and their purpose

- constructor — sets the Merkle root, USDC token address, and owner. Called once at deployment.
- claim(account, amount, proof) — anyone can call. Verifies the proof against the stored root, then transfers USDC from the contract to the claimer. Requires a fee to be sent along.
- claimFees() — only owner. Sends the contract's entire ETH balance to the owner. Reverts if the transfer fails.
- getMerkleRoot() — view. Returns the stored Merkle root.
- getAirdropToken() — view. Returns the USDC token address.
- getFee() — pure. Returns the fee amount.

## 5. Trust assumptions

- The Merkle root is generated from the real recipient list — correct addresses, correct amounts, no extras or missing entries.
- The off-chain Merkle tree generator (makeMerkle.js) uses the exact same hashing rules as the on-chain verification. If the leaf format differs, valid users can't claim.
- We trust the owner to keep their private key secure. If it's compromised, an attacker drains all collected ETH fees. Impact is small because the fee is only 1e9 wei per claim, but it's a trust point worth naming.
- We trust USDC to behave like a standard ERC20 — no unexpected pauses, fees on transfer, or reverts that would break claims.

## 6. Invariants

- No address on the Merkle tree can claim more than once.
- Only addresses on the Merkle tree can successfully claim.
- Every successful claim transfers exactly 25 USDC to the claimer — not more, not less.
- The Merkle root set at deployment can never be changed.
- Every successful claim must pay the exact fee (1e9 wei). No claim goes through with less.

## Smells (raw notes for hypotheses phase — do not investigate yet)

- claimFees withdraws entire ETH balance. Where does ETH come from? Only claim fees? Or could something else land ETH in the contract? If yes, owner takes it.
