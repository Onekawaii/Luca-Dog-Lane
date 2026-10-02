class_name LucaCompanionBrain
extends RefCounted

enum State {
	IDLE,
	FOLLOW,
	INVESTIGATE,
	WAIT,
	RECOVER,
	REST,
}

var state: State = State.IDLE
var last_reason := "boot"

func choose_state(distance_to_player: float, has_target: bool, interest_nearby: bool, tired: bool) -> State:
	var next := State.IDLE
	var reason := "near player"
	if not has_target:
		next = State.WAIT
		reason = "no player target"
	elif distance_to_player > 24.0:
		next = State.RECOVER
		reason = "too far from player"
	elif tired:
		next = State.REST
		reason = "rest budget"
	elif interest_nearby:
		next = State.INVESTIGATE
		reason = "nearby point of interest"
	elif distance_to_player > 5.0:
		next = State.FOLLOW
		reason = "follow distance exceeded"
	else:
		next = State.IDLE
		reason = "within companion radius"
	state = next
	last_reason = reason
	return state

func state_name() -> String:
	return State.keys()[state]
