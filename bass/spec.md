## Goal

Provide LuaJIT FFI bindings and small native extensions for BASS audio playback and decoding.

The local FFmpeg plugin in `ffmpeg_plugin.c` lets BASS decode formats that are already supported by the bundled FFmpeg build while keeping encoded audio streaming through the normal BASS decoder path.

## User Experience

- BASS can decode FFmpeg-supported audio formats through the plugin.
- Audio that is mixed sample-perfectly by downstream code must sound the same after seeks as it does during continuous playback.

## Architecture Decisions

### Local BASS FFmpeg Plugin

`ffmpeg_plugin.c` implements the BASS add-on interface directly instead of using a third-party BASS_FFMPEG binary. The build system compiles it into the platform plugin names BASS expects:

- Linux: `libbass_ffmpeg.so`
- Windows: `bass_ffmpeg.dll`
- macOS: `libbass_ffmpeg.dylib`

The plugin registers one FFmpeg stream type and advertises a catch-all extension:

```text
*.*
```

Unsupported files still fail when FFmpeg cannot open the input or find an audio stream.

### Plugin Loading

`init.lua` loads the native FFmpeg plugin during BASS initialization. Unsupported files still fail when FFmpeg cannot open the input or find an audio stream.

### Exact Seeking

The plugin intentionally uses exact decoded-byte seeking for every format. `addon_set_position()` seeks FFmpeg back to stream start, resets decoder/resampler state, and calls `discard_to_position()` to decode and discard PCM until the requested byte position.

This is slower than timestamp seeking, but it is required by consumers that do sample-perfect software mixing. Approximate compressed seeks can change transients after editor or preview seeks, producing audible mix differences even when continuous full renders match.

### Length Reporting

Stream length is derived from FFmpeg stream/container duration when available. The plugin does not currently keep format-specific length hacks. If a future format needs special length handling, add a documented test case that compares downstream decoded PCM and mixer behavior before introducing a codec-specific branch.

### Output Format

The plugin returns interleaved PCM in the format requested by BASS flags:

- `BASS_SAMPLE_FLOAT`: 32-bit float samples.
- otherwise: signed 16-bit samples.

Downstream soundsphere decoders currently use 16-bit stereo sample-perfect mixing, so changes to sample format, channel layout, resampling, seeking, or length reporting should be verified against `rizu/engine/audio` tests and at least one real chart with seeked playback.

## Verification

After editing `ffmpeg_plugin.c`:

1. Rebuild the platform plugin binary, for example on Linux:

```bash
gcc -shared -fPIC -O2 -Wl,-rpath,'$ORIGIN' \
	-Ibuild/deps/ffmpeg-linux/include -Iaqua \
	-o bin/linux64/libbass_ffmpeg.so aqua/bass/ffmpeg_plugin.c \
	-Lbuild/deps/ffmpeg-linux/lib -Lbin/linux64 \
	-lavformat -lavcodec -lswresample -lavutil -lbass
```

2. Run focused downstream tests:

```bash
./test rizu/engine/audio
./test rizu/preview
./test chart/format/iidx/S3PAudio_test.lua
```

3. For seek-sensitive regressions, verify that a decoded chunk after `setBytesPosition()` matches the same chunk from continuous decode.
