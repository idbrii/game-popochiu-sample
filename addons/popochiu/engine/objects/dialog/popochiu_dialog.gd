@tool
@icon('res://addons/popochiu/icons/dialog.png')
class_name PopochiuDialog
extends Resource
## A class for branching dialogs. The dialog options can be used to trigger events.

## The identifier of the object used in scripts.
@export var script_name := ''
## The array of [PopochiuDialogOption] to show on screen when the dialog is running.
@export var options: Array[PopochiuDialogOption] = [] : set = set_options

var has_done_init := false


#region Virtual ####################################################################################

## Called when the dialog is first accessed (before it starts). [b]Return an
## array of PopochiuDialogOptions created with [code]create_option()[/code][/b].
## To mix creating options from code and inspector, add your options to
## [code]existing_options[/code]:
## [code]
## existing_options.append_array([
##     create_option("Joke1", {
##       text = "How do you call a magic dog?",
##     }),
## ]
## return existing_options
## [/code]
##
## Overriding this function is optional and unnecessary if you prefer to
## configure your dialog using the Inspector.
## [i]Virtual[/i].
func _on_build_options(existing_options: Array[PopochiuDialogOption]) -> Array[PopochiuDialogOption]:
	return existing_options


## Called when the dialog starts. [b]You have to use an [code]await[/code] in this method in order
## to make the dialog to work properly[/b].
## [i]Virtual[/i].
func _on_start() -> void:
	pass


## Called when the [param opt] dialog option is clicked. The [member PopochiuDialogOption.id] in
## [param opt] can be used to check which was the selected option.
##
## Instead of overriding this function, you can write functions for each option using their
## [snake_case](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-to-snake-case)
## name (option BYE2 will call [code]_on_option_bye_2[/code]).
## [i]Virtual[/i].
func _option_selected(opt: PopochiuDialogOption) -> void:
	_show_options()


## Called when the game is saved.
## [i]Virtual[/i].
func _on_save() -> Dictionary:
	return {}


## Called when the game is loaded. The structure of [param data] is the same returned by
## [method _on_save].
## [i]Virtual[/i].
func _on_load(_data: Dictionary) -> void:
	pass


#endregion

#region Public #####################################################################################

## Called before when a dialog is accessed. Internal-only; Do not call.
func ensure_init():
	if has_done_init:
		return
	has_done_init = true

	var opts = _on_build_options(options) as Array[PopochiuDialogOption]

	# Avoid array type mismatch error in set_options so users aren't required
	# to use type hints.
	var typed_opts: Array[PopochiuDialogOption] = []
	typed_opts.assign(opts)
	options = typed_opts


## Call from within _on_build_options to populate your dialog options (instead
## of using the Inspector).
## [code]config[/code]
func create_option(id: String, config: Dictionary = {}) -> PopochiuDialogOption:
	var opt = PopochiuDialogOption.new()
	opt.set_id(id)
	if not config.is_empty():
		opt.configure(config)
		if opt.text.is_empty():
			# User made a typo or forgot essential element in their construction dictionary.
			PopochiuUtils.print_error("PopochiuDialogOption '%s' needs text to appear in a conversation: create_option('%s', { text = 'Hello.' })" % [id, id])
	return opt


## Starts this dialog, then [method _on_start] is called.[br][br]
## [i]This method is intended to be used inside a [method Popochiu.queue] of instructions.[/i]
func queue_start() -> Callable:
	return func (): await start()


## Starts this dialog, then [method _on_start] is called.
func start() -> void:
	if PopochiuUtils.d.current_dialog == self:
		return
	
	# Start this dialog
	PopochiuUtils.d.current_dialog = self
	await _start()


## Stops the dialog (which makes the menu with the options to disappear).[br][br]
## [i]This method is intended to be used inside a [method Popochiu.queue] of instructions.[/i]
func queue_stop() -> Callable:
	return func (): await stop()


## Stops the dialog (which makes the menu with the options to disappear).
func stop() -> void:
	PopochiuUtils.d.finish_dialog()


## Enables each [PopochiuDialogOption] which [member PopochiuDialogOption.id] matches each of the
## values in the [param ids] array.
func turn_on_options(ids: Array) -> void:
	for id in ids:
		var opt: PopochiuDialogOption = get_option(id)
		if opt: opt.turn_on()


## Disables each [PopochiuDialogOption] which [member PopochiuDialogOption.id] matches each of the
## values in the [param ids] array.
func turn_off_options(ids: Array) -> void:
	for id in ids:
		var opt: PopochiuDialogOption = get_option(id)
		if opt: opt.turn_off()


## Disables [b]forever[/b] each [PopochiuDialogOption] which [member PopochiuDialogOption.id]
## matches each of the values in the [param ids] array.
func turn_off_forever_options(ids: Array) -> void:
	for id in ids:
		var opt: PopochiuDialogOption = get_option(id)
		if opt: opt.turn_off_forever()


## Use this to save custom data when saving the game. The returned [Dictionary] must contain only
## JSON supported types: [bool], [int], [float], [String].
func on_save() -> Dictionary:
	return _on_save()


## Called when the game is loaded. [param data] will have the same structure you defined for the
## returned [Dictionary] by [method _on_save].
func on_load(data: Dictionary) -> void:
	_on_load(data)


## Returns the dilog option which [member PopochiuDialogOption.id] matches [param opt_id].
func get_option(opt_id: String) -> PopochiuDialogOption:
	for o in options:
		if (o as PopochiuDialogOption).id == opt_id:
			return o
	return null


#endregion

#region SetGet #####################################################################################
func set_options(value: Array[PopochiuDialogOption]) -> void:
	options = value
	
	for idx in value.size():
		if not value[idx]:
			var new_opt: PopochiuDialogOption = PopochiuDialogOption.new()
			var id := 'Opt%d' % options.size()
			
			new_opt.id = id
			new_opt.text = 'Option %d' % options.size()
			options[idx] = new_opt

#endregion

#region Private ####################################################################################
func _start() -> void:
	PopochiuUtils.g.block()
	PopochiuUtils.d.dialog_started.emit(self)
	
	await _on_start()
	
	_show_options()
	
	await PopochiuUtils.d.dialog_finished
	
	PopochiuUtils.g.unblock()
	PopochiuUtils.d.option_selected.disconnect(_on_option_selected)


func _show_options() -> void:
	if not PopochiuUtils.d.active: return
	
	PopochiuUtils.d.dialog_options_requested.emit(options)
	
	if not PopochiuUtils.d.option_selected.is_connected(_on_option_selected):
		PopochiuUtils.d.option_selected.connect(_on_option_selected)


func _on_option_selected(opt: PopochiuDialogOption) -> void:
	opt.used = true
	opt.used_times += 1
	PopochiuUtils.d.selected_option = opt
	
	_option_selected(opt)

	var fn = "_on_option_" + opt.id.to_snake_case()
	if has_method(fn):
		await call(fn, opt)


#endregion
