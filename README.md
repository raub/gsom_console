# gsom_console

A Half-Life 1 inspired console for Godot projects.
There is a singleton, and optional UI (that doesn't autoload).
It's also possible to craft your own UI instead.
Future versions may provide additional UI implementations as well.

The core idea: you have CVARs (console variables) and CMDs (commands).
You can use CVARs as global variables and settings. CMDs are like global events/signals.

There are special built-in commands like `alias`, `exec`, `wait`, `echo`, `map`, `quit`.

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

[![screenshot_1](/gdignore/thumbnail_1.jpg)](/gdignore/screenshot_1.jpg)
[![screenshot_2](/gdignore/thumbnail_2.jpg)](/gdignore/screenshot_2.jpg)


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

* `tick_mode: TickMode` - default `TickMode.TICK_MODE_AUTO`,
    the mode of calling postponed (by `wait`) commands. By default, it happens every
    frame automatically. But you can seize manual control over this process.
* `exec_paths: PackedStringArray` - default `['user://', 'res://']`,
    the list of search directories to load console scripts from. The loader
    will look through the directories in that very order. So if you want to add a
    high-priority directory - you are to **prepend** it, and not append.
* `log_text: String` - the whole log text content. This may be also used to reset the log.
* `is_visible: bool` - current visibility status. As the UI is not directly linked to
    the singleton, this visibility flag is just for convenience. You can implement any
    other visibility logic separately and disregard this flag.
* `history: PackedStringArray` - history of inserted commands.
    Latest command is last. Duplicate commands not stored.
* `COLORS_HELP: Array[String]` - default `["#d4fdeb", "#d4e6fd", "#fdd4e6", "#fdebd4"]`,
    a set of colors that help lists will use to alternate between strings. There
    may be any number of colors - the strings will cycle through them.
* `COLOR_PRIMARY: String` - default `"#ecf4fe"`, color to display names of CVARs.
* `COLOR_SECONDARY: String` - default `"#a3b0c7"`, secondary color related
    to names of CVARs (used for ":").
* `COLOR_TYPE: String` - default `"#95c1fb"`, color to display types of CVARs.
* `COLOR_VALUE: String` - default `"#f6d386"`, color to display values of CVARs.
* `COLOR_INFO: String` - default `"#a29cf5"`, color for `info()` logging.
* `COLOR_DEBUG: String` - default `"#c3e2e5"`, color for `debug()` logging.
* `COLOR_WARN: String` - default `"#f89d2c"`, color for `warn()` logging.
* `COLOR_ERROR: String` - default `"#ff3c2c"`, color for `error()` logging.
* `CMD_SEPARATOR: String` - default `";"`, a character to use as a separator between commands.
* `CMD_WAIT: String` - default `"wait"`, this command is treated as `wait`,
    if you want to change the default name.
* `EXEC_EXT: String` - default `".cfg"`, used to facilitate the search for config scripts
    by automatically checking the provided path with this suffix.


**Methods**

* `register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void` - makes a new
    CVAR available with default value and optional help note.
* `register_cmd(cmd_name: String, help_text: String = "") -> void` - makes a new
    CMD available with an optional help note.
* `alias(alias_name: String, alias_text: String = "") -> void` - makes a new
    ALIAS available, or removes an existing one if `alias_text` is empty.
* `call_cmd(cmd_name: String, args: PackedStringArray) -> void` - manually call a command,
    as if the call was parsed from user input.
* `set_cvar(cvar_name: String, value: Variant) -> void` - assign new value to the CVAR.
* `get_cvar(cvar_name: String) -> Variant` - inspect the current CVAR value.
* `list_cvars() -> Array` - list all CVAR names.
* `has_cvar(cvar_name: String) -> bool` - check if there is a CVAR with given name.
* `has_cmd(cmd_name: String) -> bool` - check if there is a CMD with given name.
* `has_alias(alias_name: String) -> bool` - check if there is an ALIAS with given name.
* `get_matches(text: String) -> PackedStringArray` - get a list of CVAR and CMD
    names that start with the given `text`.
* `tick() -> void` - calls the enqueued by "wait" commands, if any. By default
    it is called automatically every frame.
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
* `exec name[.ext]` - executes a config script line-by-line.
* `alias [name, "any text"]` - without arguments it will list all available aliases.
    If only name is given, it will erase the alias. If the alias text is also provided,
    then it will be stored for future use under that name.
* `echo "any text"` - logs back the given text.
* `map [name]` - if called without arguments, shows the current scene name. With an argument,
    it will try to change scene to the given one (by path). E.g. `map a/b/c` -> change
    scene to `res://a/b/c.tscn`. The `.tscn` suffix is optional for this command.
* `mainscene` - immediately switch to the project's main scene, as per project settings.
* `quit` - immediately closes the application.
* `wait` - a special command to postpone the execution by 1 tick. This makes most sense
    together with `alias` and some frame-by-frame logic. For example,
    `cmd1; wait; cmd2` - the two commands will be executed on different frames.


## GsomConsolePanel

The default UI console panel (like Half-Life 1 Steam),
available as a descendant of `Control` node.

**Properties**

* `float blur` [default: 0.6] [property: setter, getter] -
    Background blur intensity. Blur is only visible while `color.a` is below 1.
* `Color color` [default: Color(0.1, 0.1, 0.1, 0.4)] [property: setter, getter] -
    Panel background color. When alpha is 0 - only blur applied, if 1 no blur visible.
* `String label_window` [default: "Console"] [property: setter, getter] -
    The window title displayed at the top left corner.
* `String label_submit` [default: "submit"] [property: setter, getter] -
    The label on "submit" button at the bottom right.
* `bool is_resize_enabled` [default: true] [property: setter, getter] -
    Makes window borders draggable.
* `bool is_draggable` [default: true] [property: setter, getter] -
    Makes window panel draggable.
* `bool is_disabled` [default: false] [property: setter, getter] -
    Hides this console UI regardless of the singleton visibility state.


## GsomPlaquePanel

The plaque-mode UI (like Q1, Serious Sam),
available as a descendant of `Control` node.

**Properties**

* `float blur` [default: 0.6] [property: setter, getter] -
    Background blur intensity. Blur is only visible while `color.a` is below 1.
* `Color color` [default: Color(0.1, 0.1, 0.1, 0.4)] [property: setter, getter] -
    Panel background color. When alpha is 0 - only blur applied, if 1 no blur visible.
* `String label_submit` [default: "submit"] [property: setter, getter] -
    The label on "submit" button at the bottom right.
* `bool is_resize_enabled` [default: true] [property: setter, getter] -
    Makes window borders draggable.
* `bool is_disabled` [default: false] [property: setter, getter] -
    Hides this console UI regardless of the singleton visibility state.

## Future Work / Contributions

The development focus of this plugin is following:

* Consider allowing the `+/-` commands if that is going to work at all.
* Add components: log overlay, bottom-left console (TES Oblivion/Skyrim).
* Expand component options: colors, verbosity/log levels - maybe also
    add cvars that control those on runtime.
* Improve autocompletion/matching and hints.
* Think about some generic commands/cvars that are relevant for ALL projects.
