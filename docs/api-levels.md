# API levels

What each `GSObjectiveApi.LEVEL` added; the rule for bumping is on `GSAddonApi`.

1: everything before `gs_objective_api.gd` existed (an absent file reads as 1).

2: `GSObjectivePresence.living_fn` (optional, `() -> [PackedStringArray keys, PackedVector3Array positions]` of the living) and `living()`; the CTF flag poll and `counts_in` ask it once a tick instead of per player per flag, and fall back to the per-player callables when it is unset or returns a bad shape. `GSObjectiveSet.flags()` returns one shared, read-only array per rebuild (duplicate it before changing it).
