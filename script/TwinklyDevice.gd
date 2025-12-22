# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the TwinklyControl software, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name TwinklyDevice extends Node
## TwinklyDevice


## Emitted when the connection state is found
signal connection_state_changed(connecion_state: ConnectionState)

## Emitted when the channel or universe patch is changed
signal patched_changed(channel: int, universe: int)

## Emitted when the number of channels per pixel is changed
signal channels_per_pixel_changed(channels_per_pixel: int)


## API base endpoint
const API_BASE: String = "/xled/v1/"

## Endpoint of the login api
const LOGIN_ENDPOINT: String = API_BASE + "login/"

## Endpoint for setting the LED mode
const LED_MODE_ENDPOINT: String = API_BASE + "led/mode"

## Endpint for verifying the auth code
const VERIFY_TOKEN_ENDPOINT: String = API_BASE + "verify"

## Endpoint for getting the LED layout
const LAYOUT_ENDPOINT: String = API_BASE + "led/layout/full"

## ContentType for application/json
const CONTENT_TYPE_JSON = "Content-Type: application/json"

## LED mode for realtime control
const LED_MODE_REALTIME: String = "rt"

## UDP port for realtime control
const REALTIME_CONTROL_PORT: int = 7777

## Current proto version
const PROTOCALL_VERSION: int = 03


## Enum for ConnectionState
enum ConnectionState {
	DISCONNECTED,				## Disconnected from device
	AWAITING_AUTH_TOKEN,		## Awaitin an auth token from LOGIN_ENDPOINT
	VERIFYING_AUTH_TOKEN,		## Verifying the auth token
	SETTING_REALTIME_CONTROL,	## Setting the realtime control option
	GETTING_CHANNEL_COUNT,		## Getting the channel count from the remote device
	CONNECTED,					## Connected and ready for control
	ERROR,						## Error in connection
}


## The Ip Address of the remote device
var _ip_addr: String 

## The name of the remote device
var _name: String

## Current ConnectionState
var _connection_state: ConnectionState = ConnectionState.DISCONNECTED

## HTTPRequest to comunicate to API_BASE
var _requests: HTTPRequest = HTTPRequest.new()

## The PacketPeerUDP for realtime control
var _realtime_peer: PacketPeerUDP = PacketPeerUDP.new()

## Auth token to send to the device
var _auth_token: PackedByteArray = PackedByteArray()

## Auth token as a Base64 string
var _auth_token_base64: String = ""

## Array of the LED layout
var _led_layout: Array

## Channel length of the device
var _num_of_pixels: int = 570

## Number of channels per pixel on the device
var _channels_per_pixel: int = 3

## DMX channel patch
var _channel_patch: int = 1

## DMX universe patch
var _universe_patch: int = 0


## init
func _init(p_ip_addr: String = "", p_name: String = "") -> void:
	_ip_addr = p_ip_addr
	_name = p_name
	
	_requests.request_completed.connect(_request_complete)
	add_child(_requests)


## Starts control of the device
func start_control() -> void:
	_requests.request(
		"http://" + _ip_addr + LOGIN_ENDPOINT, 
		[CONTENT_TYPE_JSON], 
		HTTPClient.METHOD_POST, 
		'{"challenge": "xlights"}'
	)
	_set_connection_state( ConnectionState.AWAITING_AUTH_TOKEN)
	_realtime_peer.connect_to_host(_ip_addr, REALTIME_CONTROL_PORT)


## Stops control of the remote device
func stop_control() -> void:
	_realtime_peer.close()
	_enable_realtime_control(false)
	
	_set_connection_state(ConnectionState.DISCONNECTED)


## Sends DMX data to the remote device
func send_dmx_data(p_data: Array[int]) -> void:
	var buffer: PackedByteArray = PackedByteArray()
	
	buffer.append(PROTOCALL_VERSION)
	buffer.append_array(_auth_token)
	buffer.append_array([0x00, 0x00])
	buffer.append(0x00)
	buffer.append_array(p_data)
	
	_realtime_peer.put_packet(buffer)


## Sets the DMX patch of this device
func set_patch(p_channel: int, p_universe: int) -> void:
	_channel_patch = p_channel
	_universe_patch = p_universe
	
	patched_changed.emit(_channel_patch, _universe_patch)


## Sets the number of channed used on each pixel
func set_channels_per_pixel(p_channels: int) -> void:
	_channels_per_pixel = clamp(p_channels, 1, INF)
	channels_per_pixel_changed.emit(_channels_per_pixel)


## Gets the channel patch of the device
func get_channel_patch() -> int:
	return _channel_patch


## Gets the universe patch of a device
func get_universe_patch() -> int:
	return _universe_patch


## Gets the number of channels per pixel
func get_channels_per_pixel() -> int:
	return _channels_per_pixel


## Gets the device name
func get_device_name() -> String:
	return _name


## Gets the device IP address
func get_device_ip() -> String:
	return _ip_addr


## Gets the auth token as a X-Auth-Token headder
func get_auth_token_as_headder() -> String:
	return "X-Auth-Token: " + _auth_token_base64


## Gets the channel length of the light
func get_channel_length() -> int:
	return _num_of_pixels * get_channels_per_pixel()


## Gets the current Connection State
func get_connection_state() -> ConnectionState:
	return _connection_state


## Sets the connection state
func _set_connection_state(p_connection_state: ConnectionState) -> void:
	if p_connection_state == _connection_state:
		return
	
	_connection_state = p_connection_state
	connection_state_changed.emit(_connection_state)


## Verifys the auth token
func _verify_token() -> void:
	_requests.request(
		"http://" + _ip_addr + VERIFY_TOKEN_ENDPOINT, 
		[CONTENT_TYPE_JSON, get_auth_token_as_headder()], 
		HTTPClient.METHOD_POST, 
		''
	)
	
	_set_connection_state(ConnectionState.VERIFYING_AUTH_TOKEN)


## Enabled realtime control
func _enable_realtime_control(p_enabled: bool = true) -> void:
	_requests.request(
		"http://" + _ip_addr + LED_MODE_ENDPOINT, 
		[CONTENT_TYPE_JSON, get_auth_token_as_headder()], 
		HTTPClient.METHOD_POST, 
		'{"mode": "' + ("rt" if p_enabled else "off") + '"}'
	)
	_set_connection_state(ConnectionState.SETTING_REALTIME_CONTROL)


## Gets the pixel count from the remote device 
func _fetch_pixel_count() -> void:
	_requests.request(
		"http://" + _ip_addr + LAYOUT_ENDPOINT, 
		[],
		HTTPClient.METHOD_GET, 
		''
	)
	_set_connection_state(ConnectionState.GETTING_CHANNEL_COUNT)


## Called when an HTTPRequest is complete
func _request_complete(_p_result: int, p_response_code: int, _p_headers: PackedStringArray, p_body: PackedByteArray) -> void:
	if p_response_code != HTTPClient.RESPONSE_OK:
		_set_connection_state(ConnectionState.ERROR)
		return
	
	match _connection_state:
		ConnectionState.AWAITING_AUTH_TOKEN:
			_handle_auth_token(p_body)
		
		ConnectionState.SETTING_REALTIME_CONTROL:
			_set_connection_state(ConnectionState.CONNECTED)
		
		ConnectionState.VERIFYING_AUTH_TOKEN:
			_fetch_pixel_count()
		
		ConnectionState.GETTING_CHANNEL_COUNT:
			_handle_channel_count(p_body)


## Handles an incomming auth token
func _handle_auth_token(p_packet: PackedByteArray) -> void:
	var string: String = p_packet.get_string_from_utf8()
	
	if not string:
		_set_connection_state(ConnectionState.ERROR)
		return
	
	var json: Dictionary = JSON.parse_string(string)
	var auth_token: String = type_convert(json.get("authentication_token", ""), TYPE_STRING)
	
	if not auth_token:
		_set_connection_state(ConnectionState.ERROR)
		return
	
	_auth_token_base64 = auth_token
	_auth_token = Marshalls.base64_to_raw(auth_token).slice(0, 9)
	
	print("Connected and got auth token: ", _auth_token, " / ", _auth_token_base64)
	_verify_token()


## Handles an incomming led layout message
func _handle_channel_count(p_packet: PackedByteArray) -> void:
	var string: String = p_packet.get_string_from_utf8()
	
	if not string:
		_set_connection_state(ConnectionState.ERROR)
		return
	
	var json: Dictionary = JSON.parse_string(string)
	var lights: Array = type_convert(json.get("coordinates", ""), TYPE_ARRAY)
	
	_led_layout = lights
	_num_of_pixels = lights.size()
	
	print("Found: ", get_channel_length(), " Channels on device")
	_enable_realtime_control(true)
