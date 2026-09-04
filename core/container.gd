## GGTContainer
## Copyright (c) 2026 Bessonoff - MIT License
## See LICENSE.md for details.
class_name GGTContainer extends Control


# tree scope /
# nodes
@onready var _RichTextLabel: RichTextLabel = $VBoxContainer/RichTextLabel
@onready var _LineEdit: LineEdit = $VBoxContainer/HBoxContainer/LineEdit


# public
var blocked: bool = true # input block from outside
var Console: GGTConsole = null
var flow: PackedStringArray = [] # msg history


# private
var _nav_index: int = -1
var _tab_index: int = -1
var _tab_list: PackedStringArray = []


# static
const C_OUTPUT_LIMIT: int = 1000
const C_OUTPUT_MAX_LINES: int = 200


# The King is in the house.
func _ready() -> void:
	set_process(false)
	init()
	_exec_clear()


# enviroment /
# bbcode cleaner
func bbcode_cleaner(text: String) -> String:
	if (text.is_empty()): return ""
	var result: PackedStringArray = []
	var txt_len: int = text.length()
	var i: int = 0
	var end: int
	while (i < txt_len):
		if (text[i] == "["):
			end = text.find("]", i)
			if (end != -1):
				i = end + 1
				continue
		result.append(text[i])
		i += 1
	# >>
	return "".join(result)


# constructor
func _init() -> void:
	Console = GGTConsole.new()
	assert(Console, "@constructor[GGTContainer] >> GGTConsole.new()")


# sub-constructor
func init() -> void:
	# Console.
	Console.create_command("clear", _exec_clear, "Clear console history.")
	Console.create_command("open_logs", _exec_open_logs, "Open logs directory.")
	Console.create_command("save_log", _exec_save_log, \
			"Save log to file ('-v' visible only).", " -v")
	Console.on_output.connect(update_me)
	
	# UX.
	_LineEdit.text_changed.connect(_on_LineEdit_text_changed)
	_LineEdit.gui_input.connect(_on_LineEdit_gui_input)


# designer
func make_me() -> void:
	flow.clear()
	_RichTextLabel.clear()
	var echo: String = GGTConsole.C_TEMPLATE[GGTConsole.flow_type.ECHO]
	flow.append(echo % "$ godot-game-terminal\n")
	flow.append(echo % "$ started at " + \
			Time.get_datetime_string_from_system().replace("T", " "))


# dancer
func update_me(message: String = "") -> void:
	if (message.is_empty()): return
	flow.append(message)
	
	# check limits
	var flow_size: int = flow.size()
	var start_index: int = 0
	if (flow_size >= C_OUTPUT_LIMIT): flow = flow.slice(flow_size - C_OUTPUT_LIMIT, flow_size)
	flow_size = flow.size()
	if (flow_size > C_OUTPUT_MAX_LINES): start_index = flow_size - C_OUTPUT_MAX_LINES
	
	# >>
	_RichTextLabel.text = "".join(flow.slice(start_index, flow_size))
	push_focus()


# visioneer
func push_focus(new_text: String = "") -> void:
	_LineEdit.text = new_text
	_LineEdit.grab_focus.call_deferred()
	_LineEdit.caret_column = _LineEdit.text.length()


# 'clear'
func _exec_clear() -> void:
	make_me()
	update_me("\n\n")


# 'open_logs'
func _exec_open_logs() -> void:
	var logs_dir: String = OS.get_user_data_dir() + "/logs"
	if (DirAccess.dir_exists_absolute(logs_dir)): OS.shell_open(logs_dir)
	else: Console.send_message("Logs directory does not exist yet.", GGTConsole.flow_type.SPEC)


# 'save_log'
func _exec_save_log(mode: String = "") -> void:
	var msg_to_flow: String = ""
	var timestamp: String = Time.get_datetime_string_from_system() \
			.replace("-", "").replace(":", "").replace("T", "_")
	var f_path: String = OS.get_user_data_dir() + "/logs/tmlog" + timestamp + ".txt"
	if (not DirAccess.dir_exists_absolute(f_path.get_base_dir())):
		if (not DirAccess.make_dir_recursive_absolute(f_path.get_base_dir())):
			return Console.send_message("Cannot create directory: " + f_path.get_base_dir(), \
					GGTConsole.flow_type.SPEC)
	var f_tout := FileAccess.open(f_path, FileAccess.WRITE)
	if (not f_tout):
		return Console.send_message("Cannot write to file: " + f_path, \
				GGTConsole.flow_type.SPEC)
	else:
		# check mode
		var result_string: String = ""
		if (mode == "-v"): # visible only
			result_string = bbcode_cleaner(_RichTextLabel.text)
		else: # all stack
			result_string = bbcode_cleaner("".join(flow))
		f_tout.store_string(result_string)
		f_tout.close()
		msg_to_flow = "Saved to: " + f_path
	
	# >>
	update_me(msg_to_flow + "\n")


# UX /
# Autocomplete by [Tab].
func _tab(prompt: String) -> void:
	prompt = prompt.strip_edges().to_lower()
	if (prompt.is_empty()): return
	var cmd_list: PackedStringArray = Console.get_command_list()
	if (cmd_list.is_empty()): return
	
	# re-tab
	if (_tab_index == -1):
		for cmd: String in cmd_list:
			if (cmd.begins_with(prompt)): _tab_list.append(cmd)
	if (_tab_list.is_empty()): return
	_tab_index = wrapi(_tab_index + 1, 0, _tab_list.size())
	_nav_index = cmd_list.find(_tab_list[_tab_index])
	
	# >>
	push_focus(_tab_list[_tab_index] + " ")


# Navigation through the command list by [Up]/[Down].
func _nav(prompt: String, direction: int) -> void:
	var cmd_list: PackedStringArray = Console.get_command_list()
	if (cmd_list.is_empty()): return
	
	# re-start
	_tab_list.clear()
	var cmd_size: int = cmd_list.size()
	prompt = prompt.strip_edges().to_lower()
	if (prompt.is_empty()): _nav_index = -2 if (direction == 1) else cmd_size
	if (_nav_index == -1):
		for i: int in cmd_size:
			if (cmd_list[i].begins_with(prompt)):
				_nav_index = i
				break
		_nav_index = clampi(_nav_index, 0, cmd_size - 1)
	else:
		_nav_index = clampi(_nav_index + direction, 0, cmd_size - 1)
	
	# >>
	push_focus(cmd_list[_nav_index] + " ")


# from signals /
# '_LineEdit': gui_input
func _on_LineEdit_text_changed(new_text: String) -> void:
	_nav_index = -1
	_tab_index = -1
	_tab_list.clear()


# '_LineEdit': gui_input
func _on_LineEdit_gui_input(event: InputEvent) -> void:
	# hotkeys
	if (not (event is InputEventKey && event.pressed) || blocked): return
	match (event.keycode):
		KEY_TAB: _tab(_LineEdit.text)
		KEY_UP: _nav(_LineEdit.text, -1)
		KEY_DOWN: _nav(_LineEdit.text, 1)
		KEY_ENTER: Console.exec(_LineEdit.text)
		_: return
	_LineEdit.accept_event()
