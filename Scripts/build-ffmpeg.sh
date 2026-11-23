#!/bin/bash
#
# Rebuilds the FFmpeg / FFmpegKit / LAME xcframeworks in Dependencies/ from the
# Dependencies/FFmpegKit sources and installs them in place.
#
# Usage: Scripts/build-ffmpeg.sh [--no-install]
#   --no-install  only build; xcframeworks stay in Dependencies/FFmpegKit/prebuilt/bundle-apple-xcframework-ios
#
# Prerequisites (Homebrew): autoconf automake libtool pkg-config nasm
#
# Notes:
# - Objects are compiled with -fno-common (see scripts/function-ios.sh in FFmpegKit).
#   Without it, uninitialised tables such as ff_table_4_3_exp end up as common
#   symbols, ld derives a 0x8000 alignment from their size and warns:
#   "reducing alignment of section __DATA,__common from 0x8000 to 0x4000" (DOC-15161).
# - Only the components the app uses are trimmed. All decoders, demuxers, parsers,
#   bitstream filters, protocols and muxers stay enabled because the player and
#   FFmpegKit commands accept arbitrary user files.

set -euo pipefail

RDMPEG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FFMPEG_KIT_DIR="${RDMPEG_DIR}/Dependencies/FFmpegKit"

# Filters: fftools inserts these on its own (format conversion, -ar/-ac, autorotate,
# trimming, -f null), RDMPEGDecoder uses yadif, SilenceDetector uses silencedetect.
# buffer/abuffer/buffersink/abuffersink are always built by FFmpeg.
ENABLED_FILTERS=(
  aformat anull apad aresample asetpts atrim
  format fps hflip null pan rotate scale setpts silencedetect transpose trim vflip volume yadif
)

# Video encoders nothing in the app produces. The ones that stay are still reachable:
# mpeg4 (+ the h263 encoder it selects) is the default video encoder of mp4/mov/avi/mkv
# when FileIntegrityRestorer re-muxes a file with a video track, mjpeg/png/bmp/gif/tiff
# can re-encode cover art, wrapped_avframe/rawvideo serve "-f null".
# All audio and subtitle encoders stay enabled.
DISABLED_VIDEO_ENCODERS=(
  a64multi a64multi5 alias_pix amv apng asv1 asv2 avrp avui ayuv cfhd cinepak cljr
  dnxhd dpx dvvideo ffv1 ffvhuff fits flashsv flashsv2 flv h261 h263p hap huffyuv
  jpeg2000 jpegls ljpeg magicyuv mpeg1video mpeg2video msmpeg4v2 msmpeg4v3 msvideo1
  pam pbm pcx pfm pgm pgmyuv ppm prores prores_aw prores_ks qtrle r10k r210 roq rpza
  rv10 rv20 sgi snow speedhq sunrast svq1 targa utvideo v210 v308 v408 v410 vc2 wmv1
  wmv2 xbm xface xwd y41p yuv4 zlib zmbv
)

join_by_comma() { local IFS=,; echo "$*"; }

export FFMPEG_KIT_EXTRA_CONFIGURE_OPTIONS="\
 --disable-indevs --disable-outdevs\
 --disable-filters --enable-filter=$(join_by_comma "${ENABLED_FILTERS[@]}")\
 --disable-encoder=$(join_by_comma "${DISABLED_VIDEO_ENCODERS[@]}")"

cd "${FFMPEG_KIT_DIR}"
rm -rf prebuilt
./ios.sh -x --enable-lame \
  --disable-armv7 --disable-armv7s --disable-arm64e --disable-i386 \
  --disable-x86-64-mac-catalyst --disable-arm64-mac-catalyst

if [[ "${1:-}" == "--no-install" ]]; then
  echo "Built xcframeworks into ${FFMPEG_KIT_DIR}/prebuilt/bundle-apple-xcframework-ios"
  exit 0
fi

for XCFRAMEWORK in prebuilt/bundle-apple-xcframework-ios/*.xcframework; do
  rsync -a --delete --exclude .DS_Store "${XCFRAMEWORK}/" "${RDMPEG_DIR}/Dependencies/$(basename "${XCFRAMEWORK}")/"
done

echo "Installed xcframeworks into ${RDMPEG_DIR}/Dependencies"
