# FF#14 AirDropper — What I Learned

two highs found, two highs missed, one low that didn't land in my first audit ever.

merkle-based airdrop contract meant to be deployed on zksync era. four users, 25 usdc each, 100 usdc total. it's a practice audit — the contest closed years ago, so i audited it as-if-live, wrote findings before checking results, then compared. day 5 of a 100-day sprint to land my first paid finding, and the first protocol i've ever audited.

## what i found

- claim() didn't track who had claimed. any caller could loop the same proof and drain the contract, leaving no usdc for the other eligible users.
- the deploy script hardcoded the wrong usdc address on zksync — one character off from the real one. every claim reverts on transfer.

## what i missed

### missed: wrong merkle root due to decimal mismatch

what happened: makemerkle.js hardcoded amounts as 25e18. usdc has 6 decimals, so the tree encoded 25 trillion usdc per claim instead of 25.

what i did wrong: saw makemerkle.js in the file list. never opened it. only read tree.json (the output).

**if you see off-chain tooling that produces on-chain values, audit the tooling.** wrong values in a script become wrong values in the tree, wrong values in the contract.

### missed: account abstraction on zksync breaks the airdrop

what happened: merkle tree was built with mainnet-style addresses. zksync uses account abstraction, so the same user has a different address on zksync than mainnet. proofs don't verify. users can't claim.

what i did wrong: i knew there was something off with account abstraction. tried one angle (private keys), it wasn't the bug, so i dropped it and moved on. the class of concern was right — i just followed it to the wrong endpoint.

**if you're auditing for a specific chain, ask what that chain does differently.** and if you dismiss a chain-specific concern, ask "is there a related angle?" before you drop it. your gut was probably onto something.

### missed: fee too small to be economically claimable

what happened: the 1e9 wei claim fee is trivially small. gas cost to call claimFees() ends up more than the total fees collected across all 4 claims. the owner has no rational reason to ever claim — the mechanism is economically broken.

what i did wrong: i saw the fee was tiny in recon and called it trivial. did the math. stopped there. never asked "trivial for whom" — the owner is the one who has to pay gas to withdraw it, not the user.

**if a value in the contract looks trivially small or trivially large, ask who has to interact with it.** cheap for a user can still be economically broken for the owner. numbers that feel "off" usually are.

## what i'll do differently

- write my prediction of what the protocol does before opening the readme. first line of recon.md. no shortcuts.
- when i dismiss a concern, log it as "dismissed — is there a related angle?" and come back to it before verification. gut usually has more to say.
- before opening the code, spend 10 minutes learning what's different about the target chain. every chain has quirks. write them in recon.md as things to check.
- when i catch a misconfig in one script, block off 15 minutes to check every hardcoded value in every other off-chain file. one misconfig usually means more.
- when a tool tells me a concern isn't a bug, push back and ask the follow-up. my reading of the code is ground truth. the tool is another opinion.

## what's next

repo: github.com/justtammy2/ff14-airdropper-audit

next up: my first competitive audit. same workflow, real stakes.
