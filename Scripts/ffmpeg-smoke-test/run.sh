#!/bin/bash
#
# FFmpeg smoke test for the prebuilt xcframeworks in Dependencies/.
#
# Builds a command line tool for the iOS Simulator against the xcframeworks and runs,
# for every fixture, the libav* calls RDMPEGDecoder makes (demux, decode, sws_scale,
# swr_convert, yadif filter graph) and the ffmpeg commands the app issues through
# FFmpegKit (RDExtractAudioOperation, AudioFileConverter, SilenceDetector,
# FileIntegrityRestorer). Prints one line per check.
#
# Use it as an A/B test when rebuilding FFmpeg: run it before and after, then diff.
#
# usage: run.sh <simulator udid> <output file> [xcframeworks dir] [arch]
#   xcframeworks dir  defaults to RDMPEG/Dependencies
#   arch              arm64 (default) or x86_64 (needs a simulator runtime with x86_64 support)
#
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="$1"
OUTPUT="$2"
XCFRAMEWORKS="${3:-${HERE}/../../Dependencies}"
ARCH="${4:-arm64}"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

"${HERE}/make-fixtures.sh" "${WORK}/fixtures"

SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
FRAMEWORK_SEARCH_PATHS=()
for XCFRAMEWORK in "${XCFRAMEWORKS}"/*.xcframework; do
  FRAMEWORK_SEARCH_PATHS+=("-F$(ls -d "${XCFRAMEWORK}"/ios-*simulator)")
done

# -fatal_warnings: the FFmpeg libraries must link without linker warnings (DOC-15161)
xcrun clang -fobjc-arc -Wno-deprecated-declarations \
  -target "${ARCH}-apple-ios16.0-simulator" -isysroot "${SDK}" "${FRAMEWORK_SEARCH_PATHS[@]}" \
  "${HERE}/main.m" -o "${WORK}/ffmpeg-smoke-test" -Wl,-fatal_warnings \
  -framework ffmpegkit -framework libavformat -framework libavcodec -framework libavfilter \
  -framework libavdevice -framework libswscale -framework libswresample -framework libavutil -framework lame \
  -liconv -lz -lbz2 -lc++ -framework Foundation

xcrun simctl spawn "${UDID}" "${WORK}/ffmpeg-smoke-test" "${WORK}/fixtures" "${WORK}/output" > "${OUTPUT}"
cat "${OUTPUT}"
