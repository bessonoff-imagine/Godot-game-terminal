## godot-game-terminal
## Copyright (c) 2026 Bessonoff - MIT License
## See LICENSE.md for details.
extends Node


# tree scope /
# public
var is_active: bool = false
var anchors := Vector4(0.0, 0.0, 1.0, 1.0) # left, top, right, bottom
var offsets := Vector4(0.0, 0.0, 0.0, 0.0) # -/-/-/-


# private
var _tm_container: GGTContainer = null
var _tm_console: GGTConsole = null
var _tm_canvas: CanvasLayer = null


# The King is in the house.
func _ready() -> void:
	set_process(false)
	init()


# user inputs /
func _input(event: InputEvent) -> void:
	if (event is InputEventKey && event.pressed):
		if (event.keycode == KEY_QUOTELEFT):
			if (event.is_echo()): toggle(true)
			else: toggle()
			get_viewport().set_input_as_handled()


# enviroment /
# constructor
func init() -> void:
	if (is_instance_valid(_tm_canvas)): _tm_canvas.queue_free()
	_tm_container = null
	_tm_console = null
	
	# Core connection.
	var c_scene: PackedScene = load("res://addons/godot-game-terminal/core/container.tscn")
	if (not c_scene): return
	_tm_container = c_scene.instantiate()
	_tm_container.resized.connect(_tm_on_resized)
	_tm_canvas = CanvasLayer.new()
	_tm_canvas.visible = false
	_tm_canvas.add_child(_tm_container)
	get_tree().root.add_child.call_deferred(_tm_canvas)
	_tm_console = _tm_container.Console
	
	# Register basic commands.
	create_command("tm_layout", _exec_tm_layout, \
			"Terminal layout: set up anchors and offsets.", " l t r b ol ot or ob")


# legacy /
func create_command(cmd: String, callable: Callable, \
		description: String = "", hints: String = "") -> void:
	if (is_instance_valid(_tm_console)): _tm_console.create_command(cmd, callable, description, hints)
func remove_command(cmd: String) -> void:
	if (is_instance_valid(_tm_console)): _tm_console.remove_command(cmd)
func exec(cmd_line: String) -> void:
	if (is_instance_valid(_tm_console)): _tm_console.exec(cmd_line)
func send_message(new_message: String, type: GGTConsole.flow_type = 0) -> void:
	if (is_instance_valid(_tm_console)): _tm_console.send_message(new_message, type)


# style variators
func echo(text: String) -> String:
	return GGTConsole.C_TEMPLATE[GGTConsole.flow_type.ECHO] % text
func spec(text: String) -> String:
	return GGTConsole.C_TEMPLATE[GGTConsole.flow_type.SPEC] % text
func rem(text: String) -> String:
	return GGTConsole.C_TEMPLATE[GGTConsole.flow_type.REM] % text
func hint(text: String) -> String:
	return GGTConsole.C_TEMPLATE[GGTConsole.flow_type.HINT] % text


# UX /
# show/hide
func toggle(canceled: bool = false) -> void:
	if (not is_instance_valid(_tm_container)): return
	if (is_active || canceled): _tm_vfx(false)
	else: _tm_vfx(true)


# appearance vfx
func _tm_vfx(mode: bool) -> void:
	if (not is_instance_valid(_tm_canvas)): return
	is_active = mode
	_tm_container.blocked = not mode
	_tm_container.push_focus.call_deferred()
	
	# Here you can set your own effects
	# for the appearance/disappearance of the Terminal:
	_tm_canvas.visible = mode


# on viewport resized
func _tm_on_resized() -> void:
	_tm_container.anchor_left = anchors.x
	_tm_container.anchor_top = anchors.y
	_tm_container.anchor_right = anchors.z
	_tm_container.anchor_bottom = anchors.w
	_tm_container.offset_left = offsets.x
	_tm_container.offset_top = offsets.y
	_tm_container.offset_right = offsets.z
	_tm_container.offset_bottom = offsets.w


# Basic commands /
# 'tm_set_anchors'
func _exec_tm_layout(_l: float = 0.0, _t: float = 0.0, _r: float = 1.0, _b: float = 1.0, \
		_ol: float = 0.0, _ot: float = 0.0, _or: float = 0.0, _ob: float = 0.0) -> String:
	anchors = Vector4(_l, _t, _r, _b)
	offsets = Vector4(_ol, _ot, _or, _ob)
	_tm_on_resized()
	
	# here your code to save config maybe?
	# ...
	
	# >>
	var msg: String = "The terminal size is set to:\n" + \
			"  anchors = " + str(anchors) + "\n  offsets = " + str(offsets)
	return msg
