# Hypotheses — FF#14 AirDropper

- H1 — claim() has no state tracking of who claimed. No mapping, no bitmap. Any eligible user can call claim() with the same proof repeatedly and drain USDC.
  Location: claim(), MerkleAirdrop.sol
  Severity guess: High
  Raw list. Wide net. Not verified. Verification phase kills the weak ones.

## Format

- **H#** — [one-line hypothesis]
  - **Location:** MerkleAirdrop.sol:LINE
  - **Reasoning:** why this feels off, one or two sentences
  - **Attack sketch (optional):** if you have a rough attack in mind

---
