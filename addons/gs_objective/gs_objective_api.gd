extends RefCounted

## GameSpice Objective's API level. The rule for bumping it is on [GSAddonApi].
##
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning,
## because every pack built before that no longer compiles against this addon.

# 1: everything before this file existed (an absent file reads as 1).
# 2: GSObjectivePresence.living_fn (optional, `() -> [PackedStringArray keys, PackedVector3Array positions]` of the
#    living) and living(); the CTF flag poll and counts_in ask it once a tick instead of per player per flag.
const LEVEL := 2
const OLDEST := 1
