# gsom_console

A Half-Life 1 inspired console for Godot projects.
* There is a singleton, and optional UI (that doesn't autoload).
* It's also possible to craft your own UI.
* Implements variables, commands, aliases, input, logic, etc.
* There are useful built-in commands as described below.

See [example](preview.gd) script.

[![screenshot_1](/gdignore/thumbnail_1.jpg)](/gdignore/screenshot_1.jpg)
[![screenshot_2](/gdignore/thumbnail_2.jpg)](/gdignore/screenshot_2.jpg)

You can only register CVARs/CMDs/actions from code. Most other things can be then
acheived through console scripting. Including direct calls to
`GsomConsole.submit("any kind of command; as if from UI window")`.

**CVARs**

`GsomConsole.register_cvar("test", 5, "Description.")` - will register an `int` CVAR.

Supported variable types: `bool, int, float, String` - the variable type
is determined when it is registered with an initial value.
After that, new values are interpreted as being of that type.

* `test` -> output 5
* `test 6` -> now `test` is `6`
* `test 7.1` -> now test is `7` because it is `int`

Registering commands simply declares them for future calls. The console
doesn't do anything specific per CMD call - only emits the `called_cmd` signal.

**CMDs**

`GsomConsole.register_cmd("do_something", "Description.")` - will register the `do_something` CMD.

* `do_something` -> will emit `called_cmd.emit("do_something", [])`.
* `do_something abc -1 20 true 3.3` -> will
    emit `called_cmd.emit("do_something", ["abc", "-1", "20", "true", "3.3"])`.

**Actions**

`GsomConsole.register_action("jump")` - will register the `jump` input action.

* `+jump;wait;-jump` - performs a single-frame long jump press. During that frame,
    `GsomConsole.read_action("jump")` will return true.
* `bind space +jump` - activates the jump action while spacebar is pressed.


## Built-in Commands

* `;` - Not exactly a command, but a way to write multiple commands into one line.
    Even more useful in context of **alias**. E.g. `alias x "echo hi; alias x echo bye"`.
* `wait` - A special command to postpone the execution by 1 tick. This makes most sense
    together with `alias` and some frame-by-frame logic. For example,
    `cmd1; wait; cmd2` - the two commands will be executed on different frames.
* `alias` - Create a named shortcut for any input text. Use `alias say echo` or `alias smile \"echo :)\"`.
* `bind` - Assign input name to commands or actions. Pass input name and then a valid console command: `bind w +forward` or `bind x \"say hi;wait;say bye\"`.
* `clear` - Clears the console output.
* `condump` - Dumps all the console content into a text file. Takes filename as an optional parameter.
* `dec` - Decrements CVAR value by -1, -1.0, false, 1-char (depending on type), or your custom values. Use `dec x` or `dec s xyz`.
* `echo` - Print back any input. Use `echo text1 2 3` or `echo \"text1 2 3\".`
* `exec` - Parse and execute commands line by line from a file. Use `exec my_conf` or `exec user.cfg`.
* `find` - Find matching symbols - similar to how hints work. Use `find ec` or find `it`.
* `greet` - Show introduction/greeting message. Use `greet \"Your message here\"`.
* `help` - Display available commands and variables. Use `help name1 name2` or `help`.
* `ifvi` - Takes 4+ args: `variable, cmp, immediate, ...command`. Cmp is one of: `==,!=,>,>=,<,<=`. E.g.: `ifvi x == 10 echo x is 10`. True > false, string comparison rules apply too.
* `ifvv` - Takes 4+ args: `variable1, cmp, variable2, ...command`. Cmp is one of: `==,!=,>,>=,<,<=`. E.g.: `ifvv var1 < var2 \"alias out echo var1\"`.
* `inc` - Increments CVAR value by `1, 1.0, true, ' '` (depending on type), or your custom values. Use `inc x` or `inc s abcd`.
* `list_bind_names` - List all available input names, or a filtered subset.
* `list_bound_commands` - Shows currently bound inputs. Either all, or filtered, if query arguments presend: `list_bound_commands w a s d`.
* `mainscene` - Reload the main scene (as in project settings).
* `map` - Switch to a scene by path, or show path to the current one. Use `map test` or `map scenes/test.tscn`.
* `open_user` - Opens the platform-specific location of the `user://` directory. Optionally accepts additional path.
* `quit` - Close the application, exit to desktop.
* `set` - Explicit notation of CVAR assignment. Syntax `set x 1` is equal to `x 1` if `x` is a CVAR. And this will only work on a CVAR.
* `toggle_console` - Toggles the console UI on or off (based on built-in state).
* `toggle` - Toggles a CVAR - `toggle x`. Rules are: `true<->false; 1<->0; +f<->-f; ''/'no'<->'yes'/'...'`.
* `unbind` - Erase the bound command text for a given input name: `unbind w` - pressing W does nothing after that.
* `unbindall` - Erase all the command binds.
* `write_cvars` - Save a script file with all or specific CVARs. Use `write_cvars my_conf x y z` or `write_cvars user.cfg`
* `write_groups` - Save a script file with all or specific groups of symbols - cvar, alias, bind. Use `write_groups my_conf alias bind` or `write_groups user.cfg`

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
    is passed to the signal. The argument contains the added text as-is, including the newline.
* `signal cleared()` - Cleared the console output by a call to `clear()`.

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

**CVAR Methods**

* `register_cvar(cvar_name: String, value: Variant, help_text: String = "") -> void` - makes a new
    CVAR available with default value and optional help note.
* `set_cvar(cvar_name: String, value: Variant) -> void` - assign new value to the CVAR.
* `get_cvar(cvar_name: String) -> Variant` - inspect the current CVAR value.
* `list_cvars() -> Array` - list all CVAR names.
* `has_cvar(cvar_name: String) -> bool` - check if there is a CVAR with given name.
* `convert_value(value_type: int, new_value: String) -> Variant` - Converts strings to other supported console types (use `Variant.Type`).
* `show_cvar(cvar_name: String) -> void` - Displays a CVAR (type and value) through console log.
* `freeze_cvar(cvar_name: String, is_frozen: bool = true) -> void` - Sets CVAR to read-only state.
* `get_cvar_help(cvar_name: String) -> String` - Fetch CVAR help text.

**CMD Methods**

* `register_cmd(cmd_name: String, help_text: String = "") -> void` - makes a new
    CMD available with an optional help note.
* `call_cmd(cmd_name: String, args: PackedStringArray) -> void` - manually call a command,
    as if the call was parsed from user input.
* `has_cmd(cmd_name: String) -> bool` - check if there is a CMD with given name.
* `get_cmd_help(cmd_name: String) -> String` - Fetch CMD help text.
* `list_cmds() -> Array[String]` - List all CMD names.
* `has_cmd(cmd_name: String) -> bool` - Check if there is a CMD with given name.

**Console Methods**

* `alias(alias_name: String, alias_text: String = "") -> void` - makes a new
    ALIAS available, or removes an existing one if `alias_text` is empty.
* `has_alias(alias_name: String) -> bool` - check if there is an ALIAS with given name.
* `has_key(key: String) -> bool` - Check if a CMD/CVAR name is already taken.
* `get_matches(text: String) -> PackedStringArray` - get a list of CVAR and CMD
    names that start with the given `text`.
* `tick() -> void` - calls the enqueued by "wait" commands, if any. By default
    it is called automatically every frame.
* `submit(expression: String) -> void` - submit user input for parsing.
* `push_history(expression: String) -> void` - Adds a history item to previously accepted commands.
* `submit_ast(ast: Array[PackedStringArray]) -> void` - Same as submit, but takes pre-parsed AST.

**Logging Methods**

* `log(msg: String) -> void` - Appends `msg` to `log_text` and emits `logged`.
* `info(msg: String) -> void` - Wraps `msg` with color BBCode and calls `log`.
* `debug(msg: String) -> void` - Wraps `msg` with color BBCode and calls `log`.
* `warn(msg: String) -> void` - Wraps `msg` with color BBCode and calls `log`.
* `error(msg: String) -> void` - Wraps `msg` with color BBCode and calls `log`.
* `clear() -> void` - Crears the output logs and emits `cleared`.

**Visibility Methods**

* `hide() -> void` - set `is_visible` to `false` if it was `true`.
    Only emits `toggled` if indeed changed.
* `show() -> void` - set `is_visible` to `true` if it was `false`.
    Only emits `toggled` if indeed changed.
* `toggle() -> void` - change the `is_visible` value to the opposite and emits `toggled`.

**Input Methods**

Shortcuts for `GsomConsole.io_manager`.

* `handle_input(event: InputEvent) -> void` - Passes input events into the input manager instance.
* `register_action(action_name: String) -> void` - Registers a new action name for your game.
* `erase_action(action_name: String) -> void` - Removes a previously registered game action by name.
* `read_action(action_name: String) -> bool` - Fetch the action status by name - pressed or not.
* `bind_input(input_name: String, command: String) -> void` - Binds any console command to the given input name.
    An input name is always bound to only 1 command.
    If you need multiple things per input - use ";" or "alias".
    - With ";" - `bind x "+jump; say hello; say there"`.
    - With "alias" - `alias +greet "+jump; say hello; say there"; bind x +greet`.
* `unbind_input(input_name: String) -> void` - Clears the bound command for the given input name.
* `unbind_all_inputs() -> void` - Clears all bound commands.

Full list of supported inputs (as in `list_bind_names`):
```
escape tab backspace enter kp_enter insert delete pause home end
left up right down page_up page_down shift ctrl alt caps_lock num_lock
f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 kp_multiply kp_divide kp_subtract
kp_period kp_add kp_0 kp_1 kp_2 kp_3 kp_4 kp_5 kp_6 kp_7 kp_8 kp_9
menu back forward space apostrophe comma minus period slash semicolon equal
0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z
bracket_left back_slash bracket_right quote_left ascii_tilde
left_mouse right_mouse middle_mouse
wheel_up wheel_down wheel_left wheel_right thumb_1 thumb_2
joystick_0 joystick_1 joystick_2 joystick_3 joystick_4 joystick_5
joystick_6 joystick_7 joystick_8 joystick_9 joystick_10
joystick_11 joystick_12 joystick_13 joystick_14 joystick_15
joystick_16 joystick_17 joystick_18 joystick_19 joystick_20
```

**Types**

* `class GsomConsole.CommonUi` - Incapsulates common UI logic - you can use it for custom console windows.
* `class GsomConsole.AstParser` - Validates (the syntax of) console commands and parses them into AST.
* `class GsomConsole.TextMatcher` - Finds "similar" commands (for hints or built-in "find x").
* `class GsomConsole.Interceptor` - Handles the built-in commands.
* `class GsomConsole.IoManager` - Half-Life like input handler to support "bind" and other input features.
* `class GsomConsole.CvarDesc` - Type declaration for CVAR data entry.
* `class GsomConsole.CmdDesc` - Type declaration for CMD data entry.
* `enum GsomConsole.TickMode` - Determines how the postponed commands are handled.


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


## Console Feature Checklist

**Command Definition System**

- [x] Register variables from code
- [x] Declare new commands from code
- [x] Override/intercept commands
- [x] Command aliases via `alias`

**Command Input and Execution**

- [x] Multiple commands per line using semicolon `;`
- [x] Command postponement using `wait`
- [x] Command history recall
- [x] Command auto-completion
- [x] Print messages to console with `echo`

**Variables and CVars**

- [x] Set variable with implicit assignment
- [x] Read variable value by typing its name
- [x] Set variable with `set`
- [x] Toggle boolean variables with `toggle`
- [x] Protect read-only variables

**Script Files and Execution**

- [x] Execute script files via `exec`
- [x] Comments support - `//` and `#`
- [x] Support for line continuation - `\`

**Output and Logging**

- [x] Colored or formatted output (BBCode)
- [x] Console output for executed commands
- [x] Save specific variables to configuration files
- [x] Save all CVARs, aliases, etc. to files
- [x] Dump all console content to text file.

**Input and Binding Integration**

- [x] Keybinding support via `bind`, `unbind`, `unbindall`
- [x] Modifier-aware input - `+command` / `-command`
- [x] Multiple binds per key via aliases

**Advanced Usability**

- [x] Console UI
- [x] Command/variable help text
- [x] Print list of all registered symbols
- [x] Search/filter commands - `find`
- [x] Conditional logic
- [x] Increment/decrement variables
- [x] Open the `user://` folder.
- [x] Switch to any scene or to the main one.
- [x] Clear console from code or command.
