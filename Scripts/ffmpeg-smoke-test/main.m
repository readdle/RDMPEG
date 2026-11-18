// FFmpeg A/B smoke harness for DOC-15161.
// Exercises the libav* APIs RDMPEGDecoder uses and the exact ffmpeg CLI
// invocations the app issues through FFmpegKit. Prints one line per check.
#import <Foundation/Foundation.h>
#import <ffmpegkit/FFmpegKit.h>
#import <ffmpegkit/FFmpegKitConfig.h>
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavfilter/avfilter.h>
#include <libavfilter/buffersrc.h>
#include <libavfilter/buffersink.h>
#include <libswscale/swscale.h>
#include <libswresample/swresample.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>

static int yadifFrames(AVCodecContext *ctx, AVStream *st, AVFrame *frame, AVFilterGraph **graph, AVFilterContext **src, AVFilterContext **sink) {
    if (*graph == NULL) {
        *graph = avfilter_graph_alloc();
        char args[512];
        snprintf(args, sizeof(args), "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d",
                 ctx->width, ctx->height, frame->format, st->time_base.num, st->time_base.den,
                 ctx->sample_aspect_ratio.num, ctx->sample_aspect_ratio.den ?: 1);
        if (avfilter_graph_create_filter(src, avfilter_get_by_name("buffer"), "in", args, NULL, *graph) < 0) return -1;
        if (avfilter_graph_create_filter(sink, avfilter_get_by_name("buffersink"), "out", NULL, NULL, *graph) < 0) return -2;
        AVFilterInOut *outputs = avfilter_inout_alloc();
        AVFilterInOut *inputs = avfilter_inout_alloc();
        outputs->name = av_strdup("in"); outputs->filter_ctx = *src; outputs->pad_idx = 0; outputs->next = NULL;
        inputs->name = av_strdup("out"); inputs->filter_ctx = *sink; inputs->pad_idx = 0; inputs->next = NULL;
        if (avfilter_graph_parse_ptr(*graph, "yadif=0:-1:0", &inputs, &outputs, NULL) < 0) return -3;
        if (avfilter_graph_config(*graph, NULL) < 0) return -4;
        avfilter_inout_free(&inputs); avfilter_inout_free(&outputs);
    }
    if (av_buffersrc_add_frame_flags(*src, frame, AV_BUFFERSRC_FLAG_KEEP_REF) < 0) return -5;
    int n = 0;
    AVFrame *out = av_frame_alloc();
    while (av_buffersink_get_frame(*sink, out) >= 0) { n++; av_frame_unref(out); }
    av_frame_free(&out);
    return n;
}

static NSString *decodeFile(NSString *path) {
    AVFormatContext *fmt = NULL;
    if (avformat_open_input(&fmt, path.UTF8String, NULL, NULL) < 0) return @"open=FAIL";
    if (avformat_find_stream_info(fmt, NULL) < 0) return @"info=FAIL";
    NSMutableString *res = [NSMutableString stringWithFormat:@"fmt=%s", fmt->iformat->name];
    AVCodecContext *ctxs[16] = {0};
    int frames[16] = {0}, yadif[16] = {0}, scaled[16] = {0}, resampled[16] = {0};
    AVFilterGraph *graphs[16] = {0}; AVFilterContext *srcs[16] = {0}, *sinks[16] = {0};
    for (unsigned i = 0; i < fmt->nb_streams && i < 16; i++) {
        AVCodecParameters *par = fmt->streams[i]->codecpar;
        const AVCodec *codec = avcodec_find_decoder(par->codec_id);
        if (codec == NULL) { [res appendFormat:@" s%u=%s:NODEC", i, avcodec_get_name(par->codec_id)]; continue; }
        AVCodecContext *c = avcodec_alloc_context3(codec);
        avcodec_parameters_to_context(c, par);
        if (avcodec_open2(c, codec, NULL) < 0) { [res appendFormat:@" s%u=%s:OPENFAIL", i, codec->name]; avcodec_free_context(&c); continue; }
        ctxs[i] = c;
    }
    AVPacket *pkt = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    while (av_read_frame(fmt, pkt) >= 0) {
        int i = pkt->stream_index;
        AVCodecContext *c = (i < 16) ? ctxs[i] : NULL;
        if (c && avcodec_send_packet(c, pkt) >= 0) {
            while (avcodec_receive_frame(c, frame) >= 0) {
                frames[i]++;
                if (c->codec_type == AVMEDIA_TYPE_VIDEO) {
                    struct SwsContext *sws = sws_getContext(frame->width, frame->height, frame->format, frame->width, frame->height, AV_PIX_FMT_RGBA, SWS_FAST_BILINEAR, NULL, NULL, NULL);
                    if (sws) {
                        uint8_t *dst[4]; int ls[4];
                        av_image_alloc(dst, ls, frame->width, frame->height, AV_PIX_FMT_RGBA, 1);
                        if (sws_scale(sws, (const uint8_t * const *)frame->data, frame->linesize, 0, frame->height, dst, ls) > 0) scaled[i]++;
                        av_freep(&dst[0]); sws_freeContext(sws);
                    }
                    int y = yadifFrames(c, fmt->streams[i], frame, &graphs[i], &srcs[i], &sinks[i]);
                    if (y < 0) yadif[i] = y; else if (yadif[i] >= 0) yadif[i] += y;
                } else if (c->codec_type == AVMEDIA_TYPE_AUDIO) {
                    SwrContext *swr = swr_alloc_set_opts(NULL, av_get_default_channel_layout(c->channels), AV_SAMPLE_FMT_S16, c->sample_rate,
                                                         av_get_default_channel_layout(c->channels), c->sample_fmt, c->sample_rate, 0, NULL);
                    if (swr && swr_init(swr) >= 0) {
                        uint8_t *buf = NULL;
                        av_samples_alloc(&buf, NULL, c->channels, frame->nb_samples, AV_SAMPLE_FMT_S16, 0);
                        if (swr_convert(swr, &buf, frame->nb_samples, (const uint8_t **)frame->data, frame->nb_samples) >= 0) resampled[i]++;
                        av_freep(&buf);
                    }
                    swr_free(&swr);
                }
                av_frame_unref(frame);
            }
        }
        av_packet_unref(pkt);
    }
    for (unsigned i = 0; i < fmt->nb_streams && i < 16; i++) {
        if (ctxs[i] == NULL) continue;
        [res appendFormat:@" s%u=%s:frames>0=%d", i, ctxs[i]->codec->name, frames[i] > 0];
        if (ctxs[i]->codec_type == AVMEDIA_TYPE_VIDEO) [res appendFormat:@",sws=%d,yadif=%@", scaled[i] > 0, yadif[i] < 0 ? [NSString stringWithFormat:@"ERR%d", yadif[i]] : @(yadif[i] > 0)];
        if (ctxs[i]->codec_type == AVMEDIA_TYPE_AUDIO) [res appendFormat:@",swr=%d", resampled[i] > 0];
        avcodec_free_context(&ctxs[i]);
        avfilter_graph_free(&graphs[i]);
    }
    av_frame_free(&frame); av_packet_free(&pkt);
    avformat_close_input(&fmt);
    return res;
}

static NSString *runCLI(NSArray<NSString *> *args, NSString *expectInLog) {
    FFmpegSession *s = [FFmpegKit executeWithArguments:args];
    int rc = [[s getReturnCode] getValue];
    NSMutableString *r = [NSMutableString stringWithFormat:@"rc=%d", rc];
    if (expectInLog) [r appendFormat:@" log_has_%@=%d", expectInLog, [[s getAllLogsAsString] containsString:expectInLog]];
    NSString *outPath = args.lastObject;
    if ([outPath hasPrefix:@"/"]) {
        NSDictionary *a = [[NSFileManager defaultManager] attributesOfItemAtPath:outPath error:nil];
        [r appendFormat:@" out_nonempty=%d", [a fileSize] > 0];
        if ([a fileSize] > 0) [r appendFormat:@" | out:%@", decodeFile(outPath)];
    }
    if (rc != 0) {
        NSArray *lines = [[s getAllLogsAsString] componentsSeparatedByString:@"\n"];
        NSArray *tail = [lines subarrayWithRange:NSMakeRange(lines.count > 4 ? lines.count - 4 : 0, MIN(lines.count, (NSUInteger)4))];
        [r appendFormat:@" ERRLOG[%@]", [tail componentsJoinedByString:@" / "]];
    }
    return r;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [FFmpegKitConfig setLogLevel:32 /* AV_LOG_INFO, silencedetect logs at info */];
        av_log_set_level(AV_LOG_QUIET);
        NSString *dir = [NSString stringWithUTF8String:argv[1]];
        NSString *outDir = [NSString stringWithUTF8String:argv[2]];
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];
        printf("version: %s | %s\n", av_version_info(), [[FFmpegKitConfig getFFmpegVersion] UTF8String]);
        NSArray *files = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] sortedArrayUsingSelector:@selector(compare:)];
        for (NSString *name in files) {
            NSString *in = [dir stringByAppendingPathComponent:name];
            NSString *base = [outDir stringByAppendingPathComponent:name.stringByDeletingPathExtension];
            NSString *ext = name.pathExtension;
            printf("%s DECODE %s\n", name.UTF8String, decodeFile(in).UTF8String);
            // RDExtractAudioOperation (mp3 / wav)
            printf("%s EXTRACT_MP3 %s\n", name.UTF8String, runCLI(@[@"-y", @"-i", in, @"-vn", [base stringByAppendingString:@".x.mp3"]], nil).UTF8String);
            printf("%s EXTRACT_WAV %s\n", name.UTF8String, runCLI(@[@"-y", @"-i", in, @"-vn", [base stringByAppendingString:@".x.wav"]], nil).UTF8String);
            // AudioFileConverter (mp3 with explicit rate/channels/bitrate)
            printf("%s CONVERT_MP3 %s\n", name.UTF8String, runCLI(@[@"-y", @"-i", in, @"-vn", @"-ar", @"44100", @"-ac", @"1", @"-b:a", @"64k", [base stringByAppendingString:@".c.mp3"]], nil).UTF8String);
            // SilenceDetector
            printf("%s SILENCE %s\n", name.UTF8String, runCLI(@[@"-i", in, @"-af", @"silencedetect=n=-50dB:d=0.5", @"-f", @"null", @"-"], @"silence_start").UTF8String);
            // FileIntegrityRestorer (re-encode into the same container)
            printf("%s RESTORE %s\n", name.UTF8String, runCLI(@[@"-y", @"-i", in, [base stringByAppendingFormat:@".r.%@", ext]], nil).UTF8String);
        }
    }
    return 0;
}
