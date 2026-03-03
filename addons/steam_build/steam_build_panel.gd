@tool
extends PanelContainer

const CONFIG_PATH := "user://steam_build.cfg"

# UI — global settings (shared across all profiles)
var _steamcmd_path_edit: LineEdit
var _username_edit: LineEdit
var _password_edit: LineEdit

# UI — profile selector
var _profile_option: OptionButton
var _profile_name_edit: LineEdit

# UI — per-profile settings
var _working_dir_edit: LineEdit
var _app_id_edit: LineEdit
var _description_edit: LineEdit
var _depot_list_container: VBoxContainer
var _status_label: Label
var _log_output: RichTextLabel

# File dialogs
var _steamcmd_dialog: EditorFileDialog
var _workdir_dialog: EditorFileDialog

# Thread and captured values for thread-safe execution
var _build_thread: Thread
var _thread_steamcmd_path: String
var _thread_username: String
var _thread_password: String
var _thread_app_vdf: String

# Profiles — each entry: { name, working_dir, app_id, description, depots: [...] }
# depots entries: { id, label, subdir }
var _profiles: Array = []
var _active_profile: int = 0
var _loading: bool = false


func _ready() -> void:
	_build_ui()
	_build_dialogs()
	_load_config()
	_log_header()


# ─── UI construction ────────────────────────────────────────────────────────

func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.set("theme_override_constants/margin_top", 8)
	margin.set("theme_override_constants/margin_bottom", 8)
	margin.set("theme_override_constants/margin_left", 8)
	margin.set("theme_override_constants/margin_right", 8)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root_vbox)

	# Title
	var title := Label.new()
	title.text = "Steam Publisher"
	title.add_theme_font_size_override("font_size", 18)
	root_vbox.add_child(title)
	root_vbox.add_child(HSeparator.new())

	# Main horizontal split: settings on left, log on right
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 0)
	root_vbox.add_child(columns)

	# ── LEFT column: scrollable settings + action buttons ──────────────────
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_stretch_ratio = 1.4
	columns.add_child(left_vbox)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)

	var scroll_vbox := VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_vbox)

	_build_steamcmd_section(scroll_vbox)
	scroll_vbox.add_child(HSeparator.new())
	_build_profile_section(scroll_vbox)
	scroll_vbox.add_child(HSeparator.new())
	_build_app_section(scroll_vbox)
	scroll_vbox.add_child(HSeparator.new())
	_build_depots_section(scroll_vbox)
	scroll_vbox.add_child(HSeparator.new())

	var hint := Label.new()
	hint.text = "Export your game into each depot's subfolder inside the working directory before uploading."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	scroll_vbox.add_child(hint)

	# Action buttons pinned below the settings
	left_vbox.add_child(HSeparator.new())
	_build_action_row(left_vbox)

	# ── Divider ─────────────────────────────────────────────────────────────
	columns.add_child(VSeparator.new())

	# ── RIGHT column: build log ──────────────────────────────────────────────
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 1.0
	columns.add_child(right_vbox)

	_build_log_section(right_vbox)


func _build_steamcmd_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "SteamCmd Settings"
	heading.add_theme_font_size_override("font_size", 14)
	parent.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	_add_grid_label(grid, "SteamCmd Path:")
	var path_hbox := HBoxContainer.new()
	path_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steamcmd_path_edit = _make_line_edit("Path to steamcmd.exe")
	path_hbox.add_child(_steamcmd_path_edit)
	var browse_steamcmd := Button.new()
	browse_steamcmd.text = "Browse..."
	browse_steamcmd.pressed.connect(_on_browse_steamcmd_pressed)
	path_hbox.add_child(browse_steamcmd)
	grid.add_child(path_hbox)

	_add_grid_label(grid, "Username:")
	_username_edit = _make_line_edit("Steam username")
	grid.add_child(_username_edit)

	_add_grid_label(grid, "Password:")
	_password_edit = _make_line_edit("Steam password")
	_password_edit.secret = true
	grid.add_child(_password_edit)


func _build_profile_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "Build Profile"
	heading.add_theme_font_size_override("font_size", 14)
	parent.add_child(heading)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_profile_option = OptionButton.new()
	_profile_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_option.item_selected.connect(_on_profile_selected)
	hbox.add_child(_profile_option)

	_profile_name_edit = LineEdit.new()
	_profile_name_edit.custom_minimum_size = Vector2(120, 0)
	_profile_name_edit.placeholder_text = "Profile name"
	_profile_name_edit.text_changed.connect(_on_profile_name_changed)
	hbox.add_child(_profile_name_edit)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_profile_pressed)
	hbox.add_child(new_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(_on_delete_profile_pressed)
	hbox.add_child(delete_btn)

	parent.add_child(hbox)


func _build_app_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "App Settings"
	heading.add_theme_font_size_override("font_size", 14)
	parent.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(grid)

	_add_grid_label(grid, "Working Dir:")
	var dir_hbox := HBoxContainer.new()
	dir_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_working_dir_edit = _make_line_edit("Directory for VDF files and game exports")
	dir_hbox.add_child(_working_dir_edit)
	var browse_workdir := Button.new()
	browse_workdir.text = "Browse..."
	browse_workdir.pressed.connect(_on_browse_workdir_pressed)
	dir_hbox.add_child(browse_workdir)
	grid.add_child(dir_hbox)

	_add_grid_label(grid, "App ID:")
	_app_id_edit = _make_line_edit("e.g. 3291440")
	grid.add_child(_app_id_edit)

	_add_grid_label(grid, "Description:")
	_description_edit = _make_line_edit("Build description / version")
	grid.add_child(_description_edit)


func _build_depots_section(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	var heading := Label.new()
	heading.text = "Depots"
	heading.add_theme_font_size_override("font_size", 14)
	header.add_child(heading)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var add_btn := Button.new()
	add_btn.text = "+ Add Depot"
	add_btn.pressed.connect(func(): _add_depot("", "", ""))
	header.add_child(add_btn)
	parent.add_child(header)

	_depot_list_container = VBoxContainer.new()
	_depot_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_depot_list_container)


func _build_action_row(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_SHRINK_END

	var generate_btn := Button.new()
	generate_btn.text = "Generate VDF Files"
	generate_btn.pressed.connect(_on_generate_pressed)
	hbox.add_child(generate_btn)

	var upload_btn := Button.new()
	upload_btn.text = "Generate & Upload to Steam"
	upload_btn.pressed.connect(_on_upload_pressed)
	hbox.add_child(upload_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_status_label = Label.new()
	_status_label.text = "Ready"
	hbox.add_child(_status_label)

	parent.add_child(hbox)


func _build_log_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "Build Log"
	heading.add_theme_font_size_override("font_size", 14)
	parent.add_child(heading)

	parent.add_child(HSeparator.new())

	_log_output = RichTextLabel.new()
	_log_output.bbcode_enabled = true
	_log_output.scroll_following = true
	_log_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_log_output)

	parent.add_child(HSeparator.new())

	var clear_btn := Button.new()
	clear_btn.text = "Clear Log"
	clear_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	clear_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	clear_btn.pressed.connect(func(): _log_output.clear(); _log_header())
	parent.add_child(clear_btn)


# ─── Helpers ────────────────────────────────────────────────────────────────

func _make_line_edit(placeholder: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder
	edit.text_changed.connect(_save_config.unbind(1))
	return edit


func _add_grid_label(grid: GridContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(label)


# ─── File dialogs ────────────────────────────────────────────────────────────

func _build_dialogs() -> void:
	_steamcmd_dialog = EditorFileDialog.new()
	_steamcmd_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_steamcmd_dialog.title = "Select steamcmd.exe"
	_steamcmd_dialog.add_filter("*.exe", "Executable")
	_steamcmd_dialog.file_selected.connect(_on_steamcmd_file_selected)
	add_child(_steamcmd_dialog)

	_workdir_dialog = EditorFileDialog.new()
	_workdir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_workdir_dialog.title = "Select Working Directory"
	_workdir_dialog.dir_selected.connect(_on_workdir_selected)
	add_child(_workdir_dialog)


func _on_browse_steamcmd_pressed() -> void:
	_steamcmd_dialog.popup_centered_ratio(0.7)


func _on_browse_workdir_pressed() -> void:
	_workdir_dialog.popup_centered_ratio(0.7)


func _on_steamcmd_file_selected(path: String) -> void:
	_steamcmd_path_edit.text = path
	_save_config()


func _on_workdir_selected(dir: String) -> void:
	_working_dir_edit.text = dir
	_save_config()


# ─── Profiles ────────────────────────────────────────────────────────────────

func _new_profile_data(name: String) -> Dictionary:
	return {
		"name": name,
		"working_dir": "",
		"app_id": "",
		"description": "",
		"depots": [],
	}


func _sync_ui_to_profile(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	var p: Dictionary = _profiles[index]
	p["name"] = _profile_name_edit.text
	p["working_dir"] = _working_dir_edit.text
	p["app_id"] = _app_id_edit.text
	p["description"] = _description_edit.text
	p["depots"] = []
	for row in _get_depot_rows():
		p["depots"].append(_get_depot_data(row))
	_profile_option.set_item_text(index, p["name"])


func _sync_profile_to_ui(index: int) -> void:
	if index < 0 or index >= _profiles.size():
		return
	var p: Dictionary = _profiles[index]
	_profile_name_edit.text = p["name"]
	_working_dir_edit.text = p["working_dir"]
	_app_id_edit.text = p["app_id"]
	_description_edit.text = p["description"]
	for child in _depot_list_container.get_children():
		child.queue_free()
	for depot in p["depots"]:
		_add_depot(depot["id"], depot["label"], depot["subdir"])


func _update_profile_dropdown() -> void:
	_profile_option.clear()
	for p in _profiles:
		_profile_option.add_item(p["name"])
	_profile_option.selected = _active_profile


func _on_profile_selected(index: int) -> void:
	if index == _active_profile:
		return
	_loading = true
	_sync_ui_to_profile(_active_profile)
	_active_profile = index
	_sync_profile_to_ui(_active_profile)
	_loading = false
	_save_config()


func _on_profile_name_changed(new_name: String) -> void:
	if _loading:
		return
	if _active_profile < _profiles.size():
		_profiles[_active_profile]["name"] = new_name
		_profile_option.set_item_text(_active_profile, new_name)
	_save_config()


func _on_new_profile_pressed() -> void:
	_loading = true
	_sync_ui_to_profile(_active_profile)
	_profiles.append(_new_profile_data("New Profile"))
	_active_profile = _profiles.size() - 1
	_update_profile_dropdown()
	_sync_profile_to_ui(_active_profile)
	_loading = false
	_save_config()


func _on_delete_profile_pressed() -> void:
	if _profiles.size() <= 1:
		_append_log("[color=yellow]Cannot delete the only profile.[/color]")
		return
	_loading = true
	_profiles.remove_at(_active_profile)
	_active_profile = clampi(_active_profile, 0, _profiles.size() - 1)
	_update_profile_dropdown()
	_sync_profile_to_ui(_active_profile)
	_loading = false
	_save_config()


# ─── Depot rows ──────────────────────────────────────────────────────────────

func _add_depot(id: String, label_text: String, subdir: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var id_label := Label.new()
	id_label.text = "ID:"
	row.add_child(id_label)

	var id_edit := LineEdit.new()
	id_edit.custom_minimum_size = Vector2(80, 0)
	id_edit.placeholder_text = "3291441"
	id_edit.text = id
	id_edit.text_changed.connect(_save_config.unbind(1))
	row.add_child(id_edit)

	var lbl_label := Label.new()
	lbl_label.text = "  Label:"
	row.add_child(lbl_label)

	var lbl_edit := LineEdit.new()
	lbl_edit.custom_minimum_size = Vector2(100, 0)
	lbl_edit.placeholder_text = "Windows"
	lbl_edit.text = label_text
	lbl_edit.text_changed.connect(_save_config.unbind(1))
	row.add_child(lbl_edit)

	var subdir_label := Label.new()
	subdir_label.text = "  Subdir:"
	row.add_child(subdir_label)

	var subdir_edit := LineEdit.new()
	subdir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subdir_edit.custom_minimum_size = Vector2(150, 0)
	subdir_edit.placeholder_text = "windows"
	subdir_edit.text = subdir
	subdir_edit.text_changed.connect(_save_config.unbind(1))
	row.add_child(subdir_edit)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func():
		row.queue_free()
		_save_config()
	)
	row.add_child(remove_btn)

	row.set_meta("id_edit", id_edit)
	row.set_meta("lbl_edit", lbl_edit)
	row.set_meta("subdir_edit", subdir_edit)

	_depot_list_container.add_child(row)
	_save_config()


func _get_depot_rows() -> Array:
	var rows: Array = []
	for child in _depot_list_container.get_children():
		if child is HBoxContainer and not child.is_queued_for_deletion():
			rows.append(child)
	return rows


func _get_depot_data(row: HBoxContainer) -> Dictionary:
	return {
		"id": (row.get_meta("id_edit") as LineEdit).text,
		"label": (row.get_meta("lbl_edit") as LineEdit).text,
		"subdir": (row.get_meta("subdir_edit") as LineEdit).text,
	}


# ─── Config ──────────────────────────────────────────────────────────────────

func _load_config() -> void:
	_loading = true

	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		_profiles = [_new_profile_data("Default")]
		_active_profile = 0
		_update_profile_dropdown()
		_sync_profile_to_ui(0)
		_loading = false
		return

	_steamcmd_path_edit.text = cfg.get_value("steam", "steamcmd_path", "")
	_username_edit.text = cfg.get_value("steam", "username", "")
	_password_edit.text = cfg.get_value("steam", "password", "")

	# Migrate old single-profile config format
	if not cfg.has_section("profiles") and cfg.has_section("app"):
		var p := _new_profile_data("Default")
		p["working_dir"] = cfg.get_value("app", "working_dir", "")
		p["app_id"] = cfg.get_value("app", "app_id", "")
		p["description"] = cfg.get_value("app", "description", "")
		var old_count: int = cfg.get_value("depots", "count", 0)
		for i in range(old_count):
			p["depots"].append({
				"id": cfg.get_value("depots", "depot_%d_id" % i, ""),
				"label": cfg.get_value("depots", "depot_%d_label" % i, ""),
				"subdir": cfg.get_value("depots", "depot_%d_subdir" % i, ""),
			})
		_profiles = [p]
		_active_profile = 0
		_update_profile_dropdown()
		_sync_profile_to_ui(0)
		_loading = false
		return

	_active_profile = cfg.get_value("profiles", "active", 0)
	var count: int = cfg.get_value("profiles", "count", 0)

	_profiles = []
	for i in range(count):
		var s := "profile_%d" % i
		var p := _new_profile_data(cfg.get_value(s, "name", "Profile %d" % i))
		p["working_dir"] = cfg.get_value(s, "working_dir", "")
		p["app_id"] = cfg.get_value(s, "app_id", "")
		p["description"] = cfg.get_value(s, "description", "")
		var depot_count: int = cfg.get_value(s, "depot_count", 0)
		for j in range(depot_count):
			p["depots"].append({
				"id": cfg.get_value(s, "depot_%d_id" % j, ""),
				"label": cfg.get_value(s, "depot_%d_label" % j, ""),
				"subdir": cfg.get_value(s, "depot_%d_subdir" % j, ""),
			})
		_profiles.append(p)

	if _profiles.is_empty():
		_profiles = [_new_profile_data("Default")]
		_active_profile = 0
	else:
		_active_profile = clampi(_active_profile, 0, _profiles.size() - 1)

	_update_profile_dropdown()
	_sync_profile_to_ui(_active_profile)
	_loading = false


func _save_config() -> void:
	if _loading:
		return

	# Flush current UI state into the active profile before writing
	_sync_ui_to_profile(_active_profile)

	var cfg := ConfigFile.new()
	cfg.set_value("steam", "steamcmd_path", _steamcmd_path_edit.text)
	cfg.set_value("steam", "username", _username_edit.text)
	cfg.set_value("steam", "password", _password_edit.text)

	cfg.set_value("profiles", "active", _active_profile)
	cfg.set_value("profiles", "count", _profiles.size())

	for i in range(_profiles.size()):
		var p: Dictionary = _profiles[i]
		var s := "profile_%d" % i
		cfg.set_value(s, "name", p["name"])
		cfg.set_value(s, "working_dir", p["working_dir"])
		cfg.set_value(s, "app_id", p["app_id"])
		cfg.set_value(s, "description", p["description"])
		cfg.set_value(s, "depot_count", p["depots"].size())
		for j in range(p["depots"].size()):
			var d: Dictionary = p["depots"][j]
			cfg.set_value(s, "depot_%d_id" % j, d["id"])
			cfg.set_value(s, "depot_%d_label" % j, d["label"])
			cfg.set_value(s, "depot_%d_subdir" % j, d["subdir"])

	cfg.save(CONFIG_PATH)


# ─── VDF generation ──────────────────────────────────────────────────────────

func _generate_vdfs() -> bool:
	var working_dir := _working_dir_edit.text.strip_edges()
	var app_id := _app_id_edit.text.strip_edges()
	var description := _description_edit.text.strip_edges()

	if working_dir.is_empty():
		_append_log("[color=red]Error: Working directory is required.[/color]")
		return false
	if app_id.is_empty():
		_append_log("[color=red]Error: App ID is required.[/color]")
		return false

	var rows := _get_depot_rows()
	if rows.is_empty():
		_append_log("[color=red]Error: At least one depot is required.[/color]")
		return false

	var depots: Array = []
	for row in rows:
		var data := _get_depot_data(row)
		if data["id"].is_empty() or data["subdir"].is_empty():
			_append_log("[color=red]Error: Each depot must have an ID and a subdirectory.[/color]")
			return false
		depots.append(data)

	DirAccess.make_dir_recursive_absolute(working_dir + "/output")
	for depot in depots:
		DirAccess.make_dir_recursive_absolute(working_dir + "/" + depot["subdir"])

	var app_vdf_path := working_dir + "/app_" + app_id + ".vdf"
	var app_file := FileAccess.open(app_vdf_path, FileAccess.WRITE)
	if app_file == null:
		_append_log("[color=red]Error: Cannot write app VDF to: %s[/color]" % app_vdf_path)
		return false

	app_file.store_string('"appbuild"\n{\n')
	app_file.store_string('\t"appid"\t"%s"\n' % app_id)
	app_file.store_string('\t"desc"\t"%s"\n' % description)
	app_file.store_string('\t"buildoutput"\t"%s"\n' % (working_dir + "/output"))
	app_file.store_string('\t"contentroot"\t""\n')
	app_file.store_string('\t"setlive"\t""\n')
	app_file.store_string('\t"preview"\t"0"\n')
	app_file.store_string('\t"local"\t""\n')
	app_file.store_string('\t"depots"\n\t{\n')
	for depot in depots:
		app_file.store_string('\t\t"%s"\t"%s"\n' % [depot["id"], working_dir + "/depot_" + depot["id"] + ".vdf"])
	app_file.store_string('\t}\n}\n')
	app_file.close()

	for depot in depots:
		var depot_vdf_path := working_dir + "/depot_" + depot["id"] + ".vdf"
		var depot_file := FileAccess.open(depot_vdf_path, FileAccess.WRITE)
		if depot_file == null:
			_append_log("[color=red]Error: Cannot write depot VDF to: %s[/color]" % depot_vdf_path)
			return false
		depot_file.store_string('"DepotBuildConfig"\n{\n')
		depot_file.store_string('\t"DepotID"\t"%s"\n' % depot["id"])
		depot_file.store_string('\t"contentroot"\t"%s"\n' % (working_dir + "/" + depot["subdir"]))
		depot_file.store_string('\t"FileMapping"\n\t{\n')
		depot_file.store_string('\t\t"LocalPath"\t"*"\n')
		depot_file.store_string('\t\t"DepotPath"\t"."\n')
		depot_file.store_string('\t\t"recursive"\t"1"\n')
		depot_file.store_string('\t}\n')
		depot_file.store_string('\t"FileExclusion"\t"*.pdb"\n')
		depot_file.store_string('}\n')
		depot_file.close()

	_append_log("[color=green]VDF files generated in: %s[/color]" % working_dir)
	return true


# ─── Actions ─────────────────────────────────────────────────────────────────

func _on_generate_pressed() -> void:
	_set_status("Generating...", Color.YELLOW)
	if _generate_vdfs():
		_set_status("VDF files generated!", Color.GREEN)
	else:
		_set_status("Generation failed.", Color.RED)


func _on_upload_pressed() -> void:
	if _build_thread != null and _build_thread.is_alive():
		_append_log("[color=yellow]Upload already in progress.[/color]")
		return

	if not _generate_vdfs():
		_set_status("Generation failed.", Color.RED)
		return

	var steamcmd_path := _steamcmd_path_edit.text.strip_edges()
	if steamcmd_path.is_empty():
		_append_log("[color=red]Error: SteamCmd path is required.[/color]")
		_set_status("Upload failed.", Color.RED)
		return

	_thread_steamcmd_path = steamcmd_path
	_thread_username = _username_edit.text.strip_edges()
	_thread_password = _password_edit.text.strip_edges()
	var working_dir := _working_dir_edit.text.strip_edges()
	var app_id := _app_id_edit.text.strip_edges()
	_thread_app_vdf = working_dir + "/app_" + app_id + ".vdf"

	_set_status("Uploading...", Color.YELLOW)
	_append_log("Starting steamcmd upload...")
	_build_thread = Thread.new()
	_build_thread.start(_run_steamcmd)


# ─── Background thread ───────────────────────────────────────────────────────

func _run_steamcmd() -> void:
	var args := [
		"+login", _thread_username, _thread_password,
		"+run_app_build", _thread_app_vdf,
		"+quit"
	]

	var result := OS.execute_with_pipe(_thread_steamcmd_path, args)
	if result.is_empty():
		call_deferred("_on_build_complete", false)
		return

	var pipe: FileAccess = result["stdio"]

	while true:
		var line := pipe.get_line()
		if pipe.get_error() != OK:
			break
		call_deferred("_append_log", line)

	pipe = null
	call_deferred("_on_build_complete", true)


func _on_build_complete(success: bool) -> void:
	if _build_thread != null:
		_build_thread.wait_to_finish()
		_build_thread = null

	if success:
		_set_status("steamcmd finished — check log", Color.GREEN)
		_append_log("[color=green]--- steamcmd process finished ---[/color]")
	else:
		_set_status("Failed to launch steamcmd", Color.RED)
		_append_log("[color=red]Error: Could not start steamcmd. Check the executable path.[/color]")


# ─── Log helpers ─────────────────────────────────────────────────────────────

func _log_header() -> void:
	_append_log("[color=cyan][b]Note:[/b] If Steam Guard is enabled on your account, steamcmd will pause and wait for you to approve the login on your phone before proceeding.[/color]")
	_append_log("[color=gray]Note: On Windows, output may arrive in batches rather than line by line due to pipe buffering.[/color]")


func _append_log(text: String) -> void:
	_log_output.append_text(text + "\n")


func _set_status(msg: String, color: Color) -> void:
	_status_label.text = msg
	_status_label.modulate = color
