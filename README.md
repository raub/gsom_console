# gsom_console

A Half-Life 1 inspired console for Godot projects.
There is a singleton and optional UI (that doesn't autoload).
It's also possible to craft your own UI instead.
Future versions may provide additional UI implementations as well.

The core idea: you have CVARs (console variables) and CMDs (commands).
You can use CVARs as global variables and settings. CMDs are like global events/signals.

Supported variable types: `bool, int, float, String` - the variable type
is determined when it is registered with an initial value.
After that, new values are interpreted as being of that type.

`GsomConsole.register_cvar("test", 5, "Description.")` - will register an `int` CVAR.

* `test` -> output 5
* `test 6` -> now `test` is `6`
* `test 7.1` -> now test is `7` because it is `int`

Registering commands simply declares them for future calls. The console
doesn't do anything specific per CMD call - only emits the `called_cmd` signal.

`GsomConsole.register_cmd("do_something", "Description.")` - will register the `do_something` CMD.

* `do_something` -> will emit `called_cmd.emit("do_something", [])`.
* `do_something abc -1 20 true 3.3` -> will
    emit `called_cmd.emit("do_something", ["abc", "-1", "20", "true", "3.3"])`.

See [example](preview.gd) script.


## GsomConsole

This is **an autoload singleton**, that becomes globally available when you enable the plugin.
It holds all the common console logic and is not tied to any specific UI.

**Signals**

* `signal changed_cvar(cvar_name: String)` - a CVAR has been changed.
    You may fetch its updated value with `get_cvar(cvar_name)` and react to the change.
* `signal called_cmd(cmd_name: String, args: PackedStringArray)` - a CMD was called.
    All listeners will receive the command name and list of args.
* `signal toggled(is_visible: bool)` - console visibility toggled.
    This is optional - if you use the default visibility logic that comes with this singleton.
* `signal logged(rich_text: String)` - a log string was added. Only the latest addition
    is passed to the signal. The whole log text is available as `log_text` prop.

**Properties**

* `log_text: String` - the whole log text content. This may be also used to reset the log.
* `is_visible: bool` - current visibility status. As the UI is not directly linked to
    the singleton, this visibility flag is just for convenience. You can implement any
    other visibility logic separately and disregard this flag.
* `history: PackedStringArray` - history of inserted commands.
    Latest command is last. Duplicate commands not stored.

**Methods**

* `register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void` - makes a new
    CVAR available with default value and optional help note.
* `register_cmd(cmd_name: String, help_text: String = "") -> void` - makes a new
    CMD available with an optional help note.
* `call_cmd(cmd_name: String, args: PackedStringArray) -> void` - manually call a command,
    as if the call was parsed from user input.
* `set_cvar(cvar_name: String, value: Variant) -> void` - assign new value to the CVAR.
* `get_cvar(cvar_name: String) -> Variant` - inspect the current CVAR value.
* `list_cvars() -> Array` - list all CVAR names.
* `has_cvar(cvar_name: String) -> bool` - check if there is a CVAR with given name.
* `has_cmd(cmd_name: String) -> bool` - check if there is a CMD with given name.
* `get_matches(text: String) -> PackedStringArray` - get a list of CVAR and CMD names that start with the given `text`.
* `hide() -> void` - set `is_visible` to `false` if it was `true`.
    Only emits `toggled` if indeed changed.
* `show() -> void` - set `is_visible` to `true` if it was `false`.
    Only emits `toggled` if indeed changed.
* `toggle() -> void` - change the `is_visible` value to the opposite and emits `toggled`.
* `submit(expression: String) -> void` - submit user input for parsing.
* `log(msg: String) -> void` - appends `msg` to `log_text` and emits `logged`.
* `info(msg: String) -> void` - wraps `msg` with color BBCode and calls `log`.
* `debug(msg: String) -> void` - wraps `msg` with color BBCode and calls `log`.
* `warn(msg: String) -> void` - wraps `msg` with color BBCode and calls `log`.
* `error(msg: String) -> void` - wraps `msg` with color BBCode and calls `log`.

**Commands**:

* `help [name1, name2, ...]` - collect and display the currently available CVARs and CMDs.
    If any optional parameters `nameN` are provided, the console will
    only display the matching info.
* `quit` - immediately closes the application.


## GsomConsolePanel

The default UI console panel, available as a descendant of `Control` node.

**Properties**

* `float blur` [default: 0.6] [property: setter, getter] -
    Background blur intensity. Blur is only visible while `color.a` is below 1.

* `Color color` [default: Color(0, 0, 0, 0.3)] [property: setter, getter] -
    Panel background color. When alpha is 0 - only blur applied, if 1 no blur visible.

* `String label_window` [default: "Console"] [property: setter, getter] -
    The window title displayed at the top left corner.

* `String label_submit` [default: "submit"] [property: setter, getter] -
    The label on "submit" button at the bottom right.

* `bool is_resize_enabled` [default: true] [property: setter, getter] -
    Makes window borders draggable.

* `bool is_draggable` [default: true] [property: setter, getter] -
    Makes window panel draggable.
