## GGTConsole
## Based on code by Mansur Isaev and contributors (MIT)
## https://github.com/4d49/godot-console/
## Copyright (c) 2026 Bessonoff - MIT License
## See LICENSE.md for details.
class_name GGTConsole extends RefCounted


# tree scope /
# signals
signal on_output(message: String)


# private
var _flow: String = "" # buffer
var _cmd_dict: Dictionary[String, Dictionary] = {}
var _cmd_list: PackedStringArray = [""] # cache-list


# static
const C_TEMPLATE: PackedStringArray = [
		"%s", # NORMAL
		"[color=#70ffcc]%s[/color]", # ECHO
		"%s", # CMD
		"[color=#ff7070]%s[/color]", # SPEC
		"[color=#6c7a89]%s[/color]", # REM
		"[color=#ffcc70]%s[/color]" # HINT
	]
enum flow_type { NORMAL, ECHO, CMD, SPEC, REM, HINT }


# enviroment /
# constructor
func _init() -> void:
	create_command("help", _exec_help, "Show all commands.")


# string to type
static func str_to_type(string: String, type: int) -> Variant:
	if (type == TYPE_NIL || type == TYPE_STRING || type == TYPE_STRING_NAME):
		return string
	elif (type == TYPE_BOOL):
		var lower := string.to_lower()
		if (lower == "true"): return true
		elif (lower == "false"): return false
	elif (type == TYPE_INT && string.is_valid_int()):
		return string.to_int()
	elif (type == TYPE_FLOAT && string.is_valid_float()):
		return string.to_float()
	# >>
	return null


# Send message to the Universe.
func send_message(new_message: String, type: flow_type = flow_type.NORMAL) -> void:
	if (new_message.is_empty() || type < 0 || type >= C_TEMPLATE.size()): return
	on_output.emit(C_TEMPLATE[type] % new_message + "\n")


# 'true' if console has command
func has_command(cmd: String) -> bool:
	return _cmd_dict.has(cmd)


# add new command
func create_command(cmd: String, callable: Callable, \
		description: String = "", hints: String = "") -> void:
	cmd = cmd.strip_edges().to_lower()
	
	# validation...
	if (has_command(cmd)): return
	if (not cmd.is_valid_ascii_identifier() || cmd.length() > 255):
		return send_message("@constructor[c] >> '%s': invalid command name." % \
				cmd, flow_type.SPEC)
	if (not callable.is_valid()):
		return send_message("@constructor[c] >> '%s': invalid Callable." % \
				cmd, flow_type.SPEC)
	if (callable.is_custom()):
		return send_message("@constructor[c] >> '%s': custom Callable is not supported." % \
				cmd, flow_type.SPEC)
	
	# ...& registration
	var method_info: Dictionary = _find_method_info(callable.get_object(), callable.get_method())
	var arg_names: PackedStringArray = []
	var arg_types: PackedInt32Array = []
	_assign_names_and_types(method_info.get(&"args", []), arg_names, arg_types)
	var new_cmd: Dictionary[String, Variant] = {
			&"name": cmd,
			&"object_id": callable.get_object_id(),
			&"method": callable.get_method(),
			&"description": description,
			&"hints": hints,
			&"arg_names": arg_names,
			&"arg_types": arg_types,
			&"default_args": method_info.get(&"default_args", [])
		}
	new_cmd.make_read_only()
	_cmd_dict[cmd] = new_cmd
	_cmd_list.clear()


# remove command if it exists
func remove_command(cmd: String) -> void:
	if (_cmd_dict.erase(cmd)):
		_cmd_list.clear()
		send_message("@constructor[c] >> '" + cmd + "': removed from console.", flow_type.SPEC)


# get cache-list
func get_command_list() -> PackedStringArray:
	if (_cmd_list.is_empty()): # Lazy initialization.
		_cmd_list = _cmd_dict.keys()
		_cmd_list.sort()
	return _cmd_list


# execute command
func exec(cmd_line: String) -> void:
	cmd_line = cmd_line.strip_edges()
	var trimmed_line: PackedStringArray = cmd_line.split(" ", false)
	if trimmed_line.is_empty(): return
	
	# print command line at first
	trimmed_line[0] = trimmed_line[0].to_lower()
	send_message("] " + cmd_line, flow_type.CMD)
	if (not has_command(trimmed_line[0])):
		return send_message(cmd_line, flow_type.ECHO)
	
	# check...
	var cmd: Dictionary = _cmd_dict[trimmed_line[0]]
	if (not is_instance_id_valid(cmd[&"object_id"])):
		return send_message("Invalid object instance.", flow_type.SPEC)
	trimmed_line.remove_at(0)
	if (not _validate_arguments_count(trimmed_line, cmd)): return
	
	# ...& call
	var result: Variant = null
	var arg_types: Array = cmd[&"arg_types"]
	if (not arg_types.is_empty()):
		# handle
		var args: Array = []
		var args_size: int = trimmed_line.size()
		args.resize(args_size)
		for i: int in args_size:
			var value: Variant = str_to_type(trimmed_line[i], arg_types[i])
			if (value == null):
				_flow = "Invalid argument type: " + \
						"cannot convert argument %d from 'String' to '%s'." % \
						[i, type_string(arg_types[i])]
				return send_message(_flow, flow_type.SPEC)
			args[i] = value
		result = instance_from_id(cmd[&"object_id"]).callv(cmd[&"method"], args)
	else:
		# skip
		result = instance_from_id(cmd[&"object_id"]).call(cmd[&"method"])
	
	# >>
	if (result is String): send_message(result)


# deep /
# find method info
func _find_method_info(obj: Object, method_name: String) -> Dictionary:
	var script: Script = obj if (obj is Script) else obj.get_script()
	if (is_instance_valid(script)):
		for method: Dictionary in script.get_script_method_list():
			if (method_name == method.name): return method
	for method: Dictionary in obj.get_method_list():
		if (method_name == method.name): return method
	# >>
	return {}


# assign names & types
func _assign_names_and_types(args: Array[Dictionary], \
		names: PackedStringArray, types: PackedInt32Array) -> void:
	if (args.is_empty()): return
	var args_size: int = args.size()
	names.resize(args_size)
	types.resize(args_size)
	for i: int in args_size:
		var arg := args[i]
		names[i] = arg.get(&"name", "arg%d" % i)
		types[i] = arg.get(&"type", TYPE_NIL)


# validate arguments count
func _validate_arguments_count(args: PackedStringArray, cmd: Dictionary) -> bool:
	var expected_max: int = len(cmd[&"arg_types"])
	var expected_min: int = expected_max - len(cmd[&"default_args"])
	var args_size: int = args.size()
	if (args_size < expected_min || args_size > expected_max):
		if (cmd[&"default_args"]):
			_flow = "Invalid arguments count: expected between %d and %d, received %d." % \
					[expected_min, expected_max, args_size]
		else:
			_flow = "Invalid arguments count: expected %d, received %d." % \
					[expected_max, args_size]
		send_message(_flow, flow_type.SPEC)
		return false
	# >>
	return true


# default commands /
# 'help'
func _exec_help() -> void:
	send_message("--- Available commands ---")
	for cmd: String in get_command_list():
		_flow = "%s%s %s" % \
				[
					cmd,
					C_TEMPLATE[flow_type.HINT] % _cmd_dict[cmd][&"hints"],
					C_TEMPLATE[flow_type.REM] % ("// " + _cmd_dict[cmd][&"description"])
				]
		# >>
		send_message(_flow)
