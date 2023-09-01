-- BASS_DEVICEINFO flags
return {
	BASS_DEVICE_ENABLED = 1,
	BASS_DEVICE_DEFAULT = 2,
	BASS_DEVICE_INIT = 4,
	BASS_DEVICE_LOOPBACK = 8,
	BASS_DEVICE_DEFAULTCOM = 128,

	BASS_DEVICE_TYPE_MASK = 0xff000000,
	BASS_DEVICE_TYPE_NETWORK = 0x01000000,
	BASS_DEVICE_TYPE_SPEAKERS = 0x02000000,
	BASS_DEVICE_TYPE_LINE = 0x03000000,
	BASS_DEVICE_TYPE_HEADPHONES = 0x04000000,
	BASS_DEVICE_TYPE_MICROPHONE = 0x05000000,
	BASS_DEVICE_TYPE_HEADSET = 0x06000000,
	BASS_DEVICE_TYPE_HANDSET = 0x07000000,
	BASS_DEVICE_TYPE_DIGITAL = 0x08000000,
	BASS_DEVICE_TYPE_SPDIF = 0x09000000,
	BASS_DEVICE_TYPE_HDMI = 0x0a000000,
	BASS_DEVICE_TYPE_DISPLAYPORT = 0x40000000,
}