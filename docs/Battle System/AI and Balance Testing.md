---
tags: [battle-system, plan]
created: 2026-11-14
---
# AI and Balance Testing

Back to [[Battle System Overview]]

## Enemy AI (first version)
Greedy search with the same functions the player uses:
1. For each combination of up to 2 legal cards (any order, at most 1 attack), `apply` them to a **copy** of the state.
2. Score the result: damage dealt, kills, damage the enemy can deal back next turn, own position (cornered = bad).
3. Play the best one.

On a 5×5 grid with a handful of cards this is cheap. Difficulty can come from randomness in the choice, or from looking further ahead.

Reactions make the AI's predictions imperfect (it might not know which reactions the player armed), which is fine and even good.

## Headless balance testing
Because the rules are pure and seeded, a script can run thousands of battles without graphics:
- random genomes (or fixed test creatures), AI vs AI, many seeds;
- report win rate against **number of parts**, **build**, specific **cards**, specific **parts**, creature size.

The key check: **does more parts mean more wins?** If yes, build (or the stat formulas) needs tuning. This is the fastest way to tune numbers. Do it before polishing the battle scene.

Also useful in the creature lab: a key that auto-battles the two selected creatures and prints the result.
