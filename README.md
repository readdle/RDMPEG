# RDMPEG

### FFmpegKit
The `*.xcframework` bundles in `Dependencies/` are prebuilt from the `Dependencies/FFmpegKit` subrepo (FFmpeg + LAME + FFmpegKit, static, iOS arm64 + simulator arm64/x86_64).

#### Prerequisites
- Install additional tools: `brew install autoconf automake libtool pkg-config nasm`. Read details [here](https://github.com/readdle/ffmpeg-kit/tree/main/apple).

#### Rebuilding
- Execute `Scripts/build-ffmpeg.sh`. It builds everything and installs the xcframeworks into `Dependencies/`.
- The script lists the FFmpeg components that are trimmed (filters and video encoders the app never uses). Update the lists there if new FFmpeg features are needed.
- FFmpeg must be compiled with `-fno-common` (already set in FFmpegKit's `scripts/function-ios.sh`). Otherwise the linker warns `reducing alignment of section __DATA,__common from 0x8000 to 0x4000` (DOC-15161).
