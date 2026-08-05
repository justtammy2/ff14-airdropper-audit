# Post-Mortem — FF#14 AirDropper

## 0. Predictions (before opening results)

**Which of my findings will match published findings?**

- H-1 (double-claim): Yes
- H-2 (wrong USDC address): Yes
- L-1 (missing input validation): Not sure

**Total findings I expect in the results:** 5

**What I think I missed:** a funds-related bug in claimFees()

## 1. What I submitted vs what happened

**My H-1 (Missing state tracking in claim())** → matches contest **H-02** (Eligible users can claim over and over, draining the contract).

- Severity: I said High. Contest confirmed High.
- Nuance: none. same bug, same severity, same root cause

**My H-2 (Hardcoded incorrect USDC address)** → matches contest **H-01** (Address of USDC token in Deploy.s.sol is wrong).

- Severity: I said High. Contest confirmed High.
- Nuance: Contest used a Foundry fork test against real zkSync mainnet as their PoC (forge test --zksync --rpc-url). Mine used external evidence (Circle docs, block explorer). Both prove the bug, but fork tests are more reproducible for reviewers — worth adding to my toolkit for chain-specific findings.

**My L-1 (Missing input validation in constructor)** → no match.

- The contest did not accept this as a finding. Not listed as High, Medium, Low, or Informational.
- Takeaway: input-validation Lows only land when they enable a real exploit path. Deployer-hygiene ones get dropped. Log as Informational or skip next time.

## 2. Findings I missed — why?

### Missed: H-03 — Wrong amounts in Merkle tree due to decimal mismatch

**What it was:** makeMerkle.js hardcodes claim amounts as 25e18 (18 decimals). USDC is 6 decimals. So the tree actually encodes 25 trillion USDC per claim, not 25 USDC. Contract doesn't hold that, transfer reverts, no one claims.

**Why I missed it:** I saw makeMerkle.js in the file list but never opened it. Only looked at tree.json, which is the output. If I'd read the script that builds the tree, 25e18 would've been obvious.

**Pattern to remember:** When I catch one misconfig in off-chain tooling (like H-2, the wrong USDC address), don't stop there. Check every hardcoded value in every other off-chain file. One misconfig usually means the whole deploy setup was rushed — check the whole surface.

### Missed: H-04 — Account abstraction on zkSync breaks the airdrop

**What it was:** Merkle tree was built with mainnet-style addresses. zkSync uses account abstraction so the same user has a different address on zkSync. Users show up, their address doesn't match the tree, their proof fails, they can't claim.

**Why I missed it:** I actually had the instinct. I raised account abstraction as a concern early on but dropped it after concluding the specific angle I named (private keys) wasn't the issue. Should have pushed further and asked "even if this angle is wrong, is there a related one?" The class of concern was right; I just followed it to the wrong endpoint.

**Pattern to remember:**

- When auditing a contract for a specific chain, always ask what that chain does differently. zkSync uses account abstraction, so addresses aren't the same as on mainnet. Other chains have their own quirks — check them.
- When my gut flags a chain-specific concern, don't drop it just because the first angle I thought of turns out to be wrong. Ask "is there a related angle here I'm missing?" before moving on.

### Missed: L-01 — Fee is too low to be economically worth claiming

**What it was:** The 1e9 wei claim fee is way too small. Gas cost to call claimFees ends up more than the total fees collected. Owner has no rational reason to claim. On L2 gas is cheaper but still not free.

**Why I missed it:** I saw the fee was tiny during recon and called it trivial. I did the math but stopped at "the number is small." Didn't ask "trivial for who" or think about the owner having to spend gas to withdraw.

**Pattern to remember:** When a value looks too small or too large, don't stop at noticing it. Go further — ask who has to interact with that value and whether it makes sense for them.

## 3. Patterns to remember

- When I catch one misconfig in off-chain tooling, don't stop there. Check every hardcoded value in every other off-chain file. One misconfig usually means the whole deploy setup was rushed.
- When auditing a contract for a specific chain, always ask what that chain does differently. zkSync uses account abstraction, so addresses aren't the same as on mainnet. Other chains have their own quirks — check them.
- When my gut flags a chain-specific concern, don't drop it just because the first angle I thought of turns out to be wrong. Ask "is there a related angle here I'm missing?" before moving on.
- When a value looks too small or too large, don't stop at noticing it. Ask who has to interact with that value and whether it makes sense for them.
- For chain-specific bugs, prefer Foundry fork tests over external evidence links. Contest used a fork test for H-01 (the wrong USDC address) — mine used links to Circle docs and the block explorer. Both proved the bug, but fork tests are more reproducible for reviewers.
- Input-validation Lows without a real exploit path usually get dropped by judges. Either downgrade to Informational or skip logging entirely.

## 4. Process fixes for next audit

- Prediction discipline. In recon, write my prediction of what the protocol does before opening the README. First line of recon.md. No looking, no shortcuts.
- Follow my instinct. When something in my gut says "check this," check it. If I dismiss a concern, log it as "dismissed — is there a related angle?" and come back to it before verification.
- Chain-specific research pass. Before opening the code, spend 10 minutes learning what's different about the target chain. Note the quirks in recon.md as things to check during hypothesis phase.
- Follow every off-chain lead. When I catch a misconfig in one script, block off 15 minutes to check every hardcoded value in every other off-chain file. One misconfig usually means more.
- Cross-verify AI dismissals. When any tool I'm using (AI or otherwise) tells me a concern "isn't a bug here," push back and ask the follow-up. My reading of the code is the ground truth — the tool's analysis is just another opinion.
