## Copyright (c) 2026 Bessonoff - MIT License
## See LICENSE.md for details.
@tool
extends EditorPlugin
const AUTOLOAD_NAME = "Terminal"
const AUTOLOAD_PATH = "res://addons/godot-game-terminal/core/terminal.gd"
func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
