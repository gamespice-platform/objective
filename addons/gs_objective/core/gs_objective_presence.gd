class_name GSObjectivePresence
extends RefCounted

## How an objective finds out who is standing on it.
##
## [b]The whole coupling of this addon to a game is here, and it is six callables.[/b]
## GameSpice Objective never imports GameSpice Match, GameSpice Combat, GameSpice Player Controller or GameSpice Net,
## and it must not: a control point is the same rule in a 3D shooter, a 2D arena and a
## headless test with a dictionary of positions in it. The alternative — asking a
## [GSMatch] for its roster — would make every one of those a project that needs
## GameSpice Match installed to compile.
##
## The failure this shape has is the family's most repeated one, so it is checked
## rather than trusted: an unset [Callable] is not an error in GDScript, it is a
## [code]false[/code]/[code]0[/code]/[code]Vector3.ZERO[/code] answer that looks
## exactly like a real one. Every player at the origin, on no team and dead is a
## perfectly legitimate state, so [method validate] refuses a presence with holes in
## it rather than letting a suite pass against nothing.

## Every player who might be standing somewhere. [code]() -> PackedStringArray[/code]
##
## Keys, not peer ids: GameSpice Match scores by key and a peer id dies with its connection,
## which is the bug GameSpice Moderation exists because of.
var participants_fn: Callable = Callable()

## Where one is. [code](key: String) -> Vector3[/code]. A 2D game returns XZ.
var position_fn: Callable = Callable()

## Which team one is on. [code](key: String) -> int[/code]. Zero is no team.
var team_fn: Callable = Callable()

## Whether one is alive. [code](key: String) -> bool[/code]
##
## A dead player standing on a point captures nothing, and a body that keeps capturing
## is the oldest bug in this genre.
var alive_fn: Callable = Callable()

## What one player is worth to a capture. [code](key: String) -> int[/code]
##
## The long-standing per-player capture value. Defaults to 1. It is here because
## every game that ships a class system eventually wants one class to count double,
## and because a game with a "capture value" powerup has nowhere else to put it.
var capture_value_fn: Callable = Callable()

## Whether one may capture at all. [code](key: String) -> bool[/code]
##
## Defaults to true. The class-based objective shooters use it for a player who is
## invulnerable: they may not capture, and they may still block, which is the
## distinction below.
var may_capture_fn: Callable = Callable()

## Whether one may block a capture they cannot contribute to.
## [code](key: String) -> bool[/code]
##
## [b]Defaults to true, and deliberately NOT to [member may_capture_fn].[/b] Chaining
## it to that is the obvious thing and it is wrong in exactly the case the pair exists
## for: the invulnerable player may not capture and must still stop one, so a fallback
## of "may_capture" makes the one player this distinction was invented for the one
## player it does not apply to. Anybody alive and standing there blocks
## unless the game says otherwise.
var may_block_fn: Callable = Callable()

## Optional, API 2: everybody alive, with where they are, in one call.
## [code]() -> Array[/code] of two: a [PackedStringArray] of keys and a [PackedVector3Array] of their positions.
##
## The same people in the same order as [member participants_fn] filtered by [member alive_fn], each at
## [member position_fn]'s answer; [method living] builds exactly that from the three when this is unset. A game sets
## it when it can answer from its own roster in one pass: a flag poll then makes no callable call per player per
## flag. A participant whose position is meaningless (no body) may be left out, since nothing reaches it.
var living_fn: Callable = Callable()
## The pair [method living] builds, reused (its two slots are replaced each call, the pair itself is not reallocated).
var _living: Array[Variant] = [PackedStringArray(), PackedVector3Array()]


## One team's presence inside an area.
class Count extends RefCounted:
	var team: int = 0
	var cappers: int = 0     ## Value, not headcount: see capture_value_fn.
	var blockers: int = 0    ## Present, cannot capture, can stop one.
	var first: String = ""   ## The first one found — who gets block credit.


static func of(
	p_participants: Callable,
	p_position: Callable,
	p_team: Callable,
	p_alive: Callable
) -> GSObjectivePresence:
	var p := GSObjectivePresence.new()
	p.participants_fn = p_participants
	p.position_fn = p_position
	p.team_fn = p_team
	p.alive_fn = p_alive
	return p


func validate() -> GSResult:
	var missing := PackedStringArray()
	if not participants_fn.is_valid():
		missing.append("participants_fn")
	if not position_fn.is_valid():
		missing.append("position_fn")
	if not team_fn.is_valid():
		missing.append("team_fn")
	if not alive_fn.is_valid():
		missing.append("alive_fn")

	if missing.is_empty():
		return GSResult.success(null)

	return GSResult.fail(
		GSError.CODE_STATE,
		(
			"The presence is missing %s. An unset Callable answers with a zero rather "
			+ "than failing, and 'everybody is dead, at the origin, on no team' is a "
			+ "state a real game has — so nothing would ever look wrong."
		) % ", ".join(missing)
	)


func participants() -> PackedStringArray:
	if not participants_fn.is_valid():
		return PackedStringArray()
	return participants_fn.call() as PackedStringArray


func position_of(key: String) -> Vector3:
	if not position_fn.is_valid():
		return Vector3.ZERO
	return position_fn.call(key) as Vector3


func team_of(key: String) -> int:
	if not team_fn.is_valid():
		return 0
	return int(team_fn.call(key))


func is_alive(key: String) -> bool:
	if not alive_fn.is_valid():
		return false
	return bool(alive_fn.call(key))


## The living participants and their positions, [code][keys, positions][/code] ([member living_fn]). Without it:
## [method participants] in order, kept where [method is_alive], each at [method position_of].
func living() -> Array:
	if living_fn.is_valid():
		var got: Variant = living_fn.call()
		if got is Array and (got as Array).size() == 2:
			var keys: Variant = got[0]
			var at: Variant = got[1]
			if keys is PackedStringArray and at is PackedVector3Array and (keys as PackedStringArray).size() == (at as PackedVector3Array).size():
				return got
		GSLog.warn("objective", "living_fn returned something other than [keys, positions]; asking each participant instead", {})
	var keys := PackedStringArray()
	var at := PackedVector3Array()
	for key in participants():
		if not is_alive(key):
			continue
		keys.append(key)
		at.append(position_of(key))
	_living[0] = keys
	_living[1] = at
	return _living


func value_of(key: String) -> int:
	if not capture_value_fn.is_valid():
		return 1
	return maxi(int(capture_value_fn.call(key)), 0)


func may_capture(key: String) -> bool:
	if not may_capture_fn.is_valid():
		return true
	return bool(may_capture_fn.call(key))


func may_block(key: String) -> bool:
	if may_block_fn.is_valid():
		return bool(may_block_fn.call(key))
	return true


func is_inside(key: String, area: GSObjectiveArea) -> bool:
	if area == null:
		return false
	return area.contains(position_of(key))


## Everybody alive inside an area, grouped by team.
##
## Returns [code]{team_id: Count}[/code], and only for teams with somebody in it — an
## empty dictionary means an empty zone, which is the answer a caller wants to branch
## on without iterating every team that exists.
func counts_in(area: GSObjectiveArea, allowed: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var out: Dictionary = {}
	if area == null:
		return out

	var alive := living()
	var keys: PackedStringArray = alive[0]
	var at: PackedVector3Array = alive[1]
	for i in keys.size():
		if not area.contains(at[i]):
			continue
		var key := keys[i]

		var team := team_of(key)
		if team <= 0:
			continue
		if not allowed.is_empty() and not allowed.has(team):
			continue

		var count: Count = out.get(team, null)
		if count == null:
			count = Count.new()
			count.team = team
			out[team] = count

		if may_capture(key):
			if count.first == "":
				count.first = key
			count.cappers += value_of(key)
		elif may_block(key):
			if count.first == "":
				count.first = key
			count.blockers += value_of(key)

	return out


## The nearest alive participant to a point, optionally on one team. "" when nobody.
func nearest(
	point: Vector3, within: float = 0.0, team: int = 0
) -> String:
	var best := ""
	var best_d := INF
	for key in participants():
		if not is_alive(key):
			continue
		if team > 0 and team_of(key) != team:
			continue
		var d := position_of(key).distance_to(point)
		if within > 0.0 and d > within:
			continue
		if d < best_d:
			best_d = d
			best = key
	return best


func describe() -> Dictionary:
	return {
		"participants": participants().size(),
		"wired": validate().ok,
	}
