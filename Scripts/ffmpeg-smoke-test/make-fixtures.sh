#!/bin/bash
# Generates small media fixtures for the FFmpeg smoke test.
# Requires a host ffmpeg with libx264, libx265, libvpx, libopus, libmp3lame (brew install ffmpeg).
# usage: make-fixtures.sh <output dir>
set -e
mkdir -p "$1"
cd "$1"
F() { ffmpeg -hide_banner -loglevel error -y "$@"; }
SRC_VIDEO=(-f lavfi -i "testsrc=size=64x48:rate=25:d=2" -f lavfi -i "sine=f=440:d=2")

# 1s tone, 1s silence, 1s tone: SilenceDetector must report silence_start
F -f lavfi -i "sine=f=440:d=1" -f lavfi -i "anullsrc=r=44100:cl=mono:d=1" -f lavfi -i "sine=f=660:d=1" \
  -filter_complex "[0][1][2]concat=n=3:v=0:a=1" -ar 44100 -ac 1 -b:a 64k tone.mp3
F -i tone.mp3 -c:a aac -b:a 64k tone.m4a
F -i tone.mp3 tone.wav
F -i tone.mp3 -c:a flac tone.flac
F -i tone.mp3 -c:a libopus tone.opus.ogg

# Video containers/codecs the player opens; the h264 one is interlaced to exercise yadif
F "${SRC_VIDEO[@]}" -c:v libx264 -pix_fmt yuv420p -flags +ildct+ilme -x264-params interlaced=1 -c:a aac -shortest clip_h264.mp4
F "${SRC_VIDEO[@]}" -c:v mpeg4 -c:a libmp3lame -shortest clip_mpeg4.avi
F "${SRC_VIDEO[@]}" -c:v libvpx-vp9 -c:a libopus -shortest clip_vp9.mkv
F "${SRC_VIDEO[@]}" -c:v libx265 -tag:v hvc1 -c:a ac3 -shortest clip_hevc.mov

# Rotated video: ffmpeg autorotate inserts transpose when re-encoding
F "${SRC_VIDEO[@]}" -c:v libx264 -c:a aac -shortest rot_tmp.mp4
F -display_rotation 90 -i rot_tmp.mp4 -c copy clip_rot90.mp4
rm -f rot_tmp.mp4

# Audio with cover art (attached picture stream)
F -f lavfi -i "testsrc=size=64x48:rate=1:d=1" -frames:v 1 cover.png
F -i tone.mp3 -i cover.png -map 0 -map 1 -c:a copy -c:v png -disposition:v attached_pic -id3v2_version 3 tone_cover.mp3
F -i tone.m4a -i cover.png -map 0 -map 1 -c copy -disposition:v attached_pic tone_cover.m4a
rm -f cover.png
