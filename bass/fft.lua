-- BASS_ChannelGetData flags
return {
	BASS_DATA_AVAILABLE = 0, -- query how much data is buffered
	BASS_DATA_NOREMOVE = 0x10000000, -- flag: don't remove data from recording buffer
	BASS_DATA_FLOAT	= 0x40000000, -- flag: return floating-point sample data
	BASS_DATA_FFT256 = 0x80000000, -- 256 sample FFT
	BASS_DATA_FFT512 = 0x80000001, -- 512 FFT
	BASS_DATA_FFT1024 = 0x80000002, -- 1024 FFT
	BASS_DATA_FFT2048 = 0x80000003, -- 2048 FFT
	BASS_DATA_FFT4096 = 0x80000004, -- 4096 FFT
	BASS_DATA_FFT8192 = 0x80000005, -- 8192 FFT
	BASS_DATA_FFT16384 = 0x80000006, -- 16384 FFT
	BASS_DATA_FFT32768 = 0x80000007, -- 32768 FFT
	BASS_DATA_FFT_INDIVIDUAL = 0x10, -- FFT flag: FFT for each channel, else all combined
	BASS_DATA_FFT_NOWINDOW = 0x20, -- FFT flag: no Hanning window
	BASS_DATA_FFT_REMOVEDC = 0x40, -- FFT flag: pre-remove DC bias
	BASS_DATA_FFT_COMPLEX = 0x80, -- FFT flag: return complex data
	BASS_DATA_FFT_NYQUIST = 0x100, -- FFT flag: return extra Nyquist value
}
