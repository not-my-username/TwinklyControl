# Copyright (c) 2025 Liam Sherwin. All rights reserved.
# This file is part of the TwinklyControl software, licensed under the GPL v3.0 or later.
# See the LICENSE file for details.

class_name TwinklyControl extends Node
## Class to repersent a Twinkly device


## Emitted when a device is discovred
signal device_discovred(p_device: TwinklyDevice)


## Twinkly discovery port
const BROADCAST_DISCO_PORT: int = 5555

## Network broadcast port
const BROADCAST_ADDRESS: String = "255.255.255.255"

## Interval in seconds to send a discovery message
const DISCOVERY_TIME: int = 5

## The UDP port for artnet
const ART_NET_PORT: int = 6454

## Min length for an incomming artnet packet
const ART_NET_MIN_LENGTH: int = 18

## Oppcode for Art-DMX packet
const ART_DMX_OPCODE: int = 0x5000


## UDP discovery peer for finding Twinkly devices
var _discovery_peer: PacketPeerUDP = PacketPeerUDP.new()

## UDP discovery packed to send to discovery
var _discovery_message: PackedByteArray = PackedByteArray([0x01, 0x64, 0x69, 0x73, 0x63, 0x6f, 0x76, 0x65, 0x72])

## List of known devices
var _known_devices: Dictionary[String, TwinklyDevice]

## PacketPeerUDP for ArtNet input
var _art_net_input: PacketPeerUDP = PacketPeerUDP.new()

## All active device being controlled currently
var _active_devices: Array[TwinklyDevice] = []

## Current DMX data
var _current_dmx: Dictionary[int, int] = {}

## The Timer used for discovery messages
var _discovery_timer: Timer = Timer.new()

## Output queued state
var _output_queued: bool = false
 
## Ready
func _ready() -> void:
	_discovery_peer.bind(BROADCAST_DISCO_PORT)
	_discovery_peer.set_broadcast_enabled(true)
	
	_art_net_input.bind(ART_NET_PORT)
	_discovery_peer.set_dest_address(BROADCAST_ADDRESS, BROADCAST_DISCO_PORT)
	
	send_discovery()
	add_child(_discovery_timer)
	
	_discovery_timer.timeout.connect(send_discovery)
	_discovery_timer.start(DISCOVERY_TIME)


## Process
func _process(_p_delta: float) -> void:
	while _discovery_peer.get_available_packet_count():
		var buffer: PackedByteArray = _discovery_peer.get_packet()
		
		if buffer.size() >= 6 and buffer[4] == 0x4f:
			add_device(_discovery_peer.get_packet_ip(), buffer.slice(6).get_string_from_utf8())
	
	while _art_net_input.get_available_packet_count():
		_handle_artnet_input(_art_net_input.get_packet())


## Adds a device to the known list
func add_device(p_ip_addr: String, p_name: String) -> void:
	if _known_devices.has(p_name):
		return
	
	print("Creating Device: ", p_name, ". IP: ", p_ip_addr)
	
	var device: TwinklyDevice = TwinklyDevice.new(p_ip_addr, p_name)
	_known_devices[p_name] = device
	
	add_child(device)
	device_discovred.emit(device)


## Starts control of a device from a given name
func start_device_control(p_device: TwinklyDevice) -> void:
	if not p_device or _active_devices.has(p_device):
		return
	
	print("Starting control of device: ", p_device.get_device_name())
	
	_active_devices.append(p_device)
	p_device.start_control()


## Stops control of a device
func stop_device_control(p_device: TwinklyDevice) -> void:
	if not p_device or not _active_devices.has(p_device):
		return
	
	print("Stopping contorl of device: ", p_device.get_device_name())
	
	_active_devices.erase(p_device)
	p_device.stop_control()


## Sends a discovey packet to broadcast
func send_discovery() -> void:
	if _discovery_peer.is_bound():
		_discovery_peer.put_packet(_discovery_message)


## Handles an incomming art-net packet
func _handle_artnet_input(p_packet: PackedByteArray) -> void:
	if p_packet.size() < ART_NET_MIN_LENGTH or (p_packet.get(9) << 8) | p_packet.get(8) != ART_DMX_OPCODE:
		return
	
	var universe: int = (p_packet.get(15) << 8) | p_packet.get(14)
	var data_length: int = (p_packet.get(16) << 8) | p_packet.get(17)
	var dmx_offset: int = 512 * universe
	
	if p_packet.size() < data_length:
		return
	
	for index: int in range(0, data_length):
		_current_dmx[index + dmx_offset] = p_packet[index + ART_NET_MIN_LENGTH]
	
	if not _output_queued:
		_output_dmx.call_deferred()
		_output_queued = true


## Outputs dmx data to the devices
func _output_dmx() -> void:
	_output_queued = false
	
	for device: TwinklyDevice in _active_devices: 
		var dmx_base: int = (512 * device.get_universe_patch() + device.get_channel_patch()) - 1
		var data_range: Array = range(dmx_base, dmx_base + device.get_channel_length()) 
		
		var buffer: Array[int] = [] 
		buffer.resize(device.get_channel_length()) 
		
		for index: int in data_range: 
			buffer[index - dmx_base] = _current_dmx.get(index, 0) 
		
		device.send_dmx_data(buffer)
