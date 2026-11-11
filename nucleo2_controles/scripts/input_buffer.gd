class_name N2InputBuffer
extends RefCounted

var _frames: Array = []
var _head: int = 0
var _count: int = 0

func _init(capacity: int = 30) -> void:
	resize(capacity)

func resize(capacity: int) -> void:
	_frames.clear()
	_frames.resize(maxi(capacity, 1))
	_frames.fill(null)
	_head = 0
	_count = 0

func push(snapshot: Dictionary) -> void:
	if _frames.is_empty():
		resize(30)
	_frames[_head] = snapshot.duplicate(true)
	_head = (_head + 1) % _frames.size()
	_count = mini(_count + 1, _frames.size())

func get_last(n: int) -> Array:
	var out: Array = []
	var total := mini(n, _count)
	var cap := _frames.size()
	for i in range(total):
		var idx := (_head - 1 - i + cap * 2) % cap
		out.push_front(_frames[idx])
	return out

func clear() -> void:
	_frames.fill(null)
	_head = 0
	_count = 0

func size() -> int:
	return _count

func capacity() -> int:
	return _frames.size()
