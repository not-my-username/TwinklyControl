# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the TwinklyControl software, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name TwinklyControlUI extends PanelContainer
## UI script for TwinklyControl


## Color for when artnet is active
const ART_NET_ACTIVE_COLOR: Color = Color.GREEN

## Color for when artnet is inactive
const ART_NET_INACTIVE_COLOR: Color = Color.GRAY


## Enum for Columns
enum Columns {
	NAME,
	IP_ADDR,
	CONNECTION_STATE,
	DMX_PATCH,
	CHANNELS_PER_PIXEL,
}


## The Tree to show all discovred devices
@export var device_tree: Tree

## The Connect button
@export var connect_button: Button

## The Disconenct button
@export var disconnect_button: Button

## The PanelContainer for artnet status
@export var art_net_status: Control


## RefMap for TwinklyDevice: Tree
var _devices: RefMap = RefMap.new()

## The current selected device
var _selected_device: TwinklyDevice


## ready
func _ready() -> void:
	OS.low_processor_usage_mode = true
	
	for column: int in Columns.values():
		device_tree.set_column_title(column, Columns.keys()[column].capitalize())
	
	device_tree.create_item()
	
	TC.device_discovred.connect(_add_device)
	TC.art_net_status_changed.connect(_set_artnet_status)
	
	_set_artnet_status(TC.get_artnet_status())


## Called when the art net status changes
func _set_artnet_status(p_status: bool) -> void:
	art_net_status.set_modulate(ART_NET_ACTIVE_COLOR if p_status else ART_NET_INACTIVE_COLOR)
	

## Adds a TwinklyDevice to the tree
func _add_device(p_device: TwinklyDevice) -> void:
	if _devices.has_left(_devices):
		return
	
	var tree_item: TreeItem = device_tree.create_item()
	
	tree_item.set_text(Columns.NAME, p_device.get_device_name())
	tree_item.set_text(Columns.IP_ADDR, p_device.get_device_ip())
	tree_item.set_text(Columns.CONNECTION_STATE, TwinklyDevice.ConnectionState.keys()[p_device.get_connection_state()])
	tree_item.set_text(Columns.DMX_PATCH, str(p_device.get_universe_patch()) + "." + str(p_device.get_channel_patch()))
	tree_item.set_text(Columns.CHANNELS_PER_PIXEL, str(p_device.get_channels_per_pixel()))
	
	tree_item.set_editable(Columns.DMX_PATCH, true)
	tree_item.set_editable(Columns.CHANNELS_PER_PIXEL, true)
	
	p_device.connection_state_changed.connect(_on_device_connection_state_changed.bind(p_device))
	p_device.patched_changed.connect(_on_device_patch_changed.bind(p_device))
	p_device.channels_per_pixel_changed.connect(_on_device_channels_per_pixel_changed.bind(p_device))
	
	_devices.map(p_device, tree_item)


## Called when a device patch is changed
func _on_device_patch_changed(p_channel: int, p_universe: int, p_device: TwinklyDevice) -> void:
	_devices.left(p_device).set_text(Columns.DMX_PATCH, str(p_universe) + "." + str(p_channel))


## Called when the ConnectionState is changed on a device
func _on_device_connection_state_changed(p_connection_state: TwinklyDevice.ConnectionState, p_device: TwinklyDevice) -> void:
	_devices.left(p_device).set_text(Columns.CONNECTION_STATE, TwinklyDevice.ConnectionState.keys()[p_connection_state])
	
	if p_device == _selected_device:
		_update_buttons()


## Called when the channels per pixel is changed
func _on_device_channels_per_pixel_changed(p_channels_per_pixel: int, p_device: TwinklyDevice) -> void:
	_devices.left(p_device).set_text(Columns.CHANNELS_PER_PIXEL, str(p_channels_per_pixel))


## updates buttons disabled state from the current selected device
func _update_buttons() -> void:
	if not _selected_device:
		disconnect_button.set_disabled(true)
		connect_button.set_disabled(true)
		return
	
	if _selected_device.get_connection_state() != TwinklyDevice.ConnectionState.DISCONNECTED:
		disconnect_button.set_disabled(false)
		connect_button.set_disabled(true)
	else:
		connect_button.set_disabled(false)
		disconnect_button.set_disabled(true)


## Called when an TreeItem is edited
func _on_device_tree_item_edited() -> void:
	var item: TreeItem = device_tree.get_edited()
	var column: int = device_tree.get_edited_column()
	
	var device: TwinklyDevice = _devices.right(item)
	
	match column:
		Columns.DMX_PATCH:
			var data: PackedStringArray = item.get_text(column).split(".")
			var universe: int = device.get_universe_patch()
			var channel: int = device.get_channel_patch()
			
			if data.size() == 2:
				universe = clamp(int(data[0]), 0, 65535)
				channel = clamp(int(data[1]), 1, 255)
			
			device.set_patch(channel, universe)
		
		Columns.CHANNELS_PER_PIXEL:
			var channels: int = int(item.get_text(column))
			device.set_channels_per_pixel(channels)



## Called when something is selected in the Tree
func _on_device_tree_item_selected() -> void:
	var selected: TreeItem = device_tree.get_selected()
	var device: TwinklyDevice = _devices.right(selected)
	
	_selected_device = device
	_update_buttons()


## Called when nothing is selected in the Tree
func _on_device_tree_nothing_selected() -> void:
	device_tree.deselect_all()
	
	_selected_device = null
	_update_buttons()


## Called when the connect button is pressed
func _on_connect_pressed() -> void:
	if _selected_device:
		TC.start_device_control(_selected_device)


## Called when the disconenct button is pressed
func _on_disconnect_pressed() -> void:
	if _selected_device:
		TC.stop_device_control(_selected_device)
