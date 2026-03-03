#include <libavformat/avformat.h>
#include <libavutil/mem.h>
#include <libavutil/error.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef __AFL_HAVE_MANUAL_CONTROL
__AFL_FUZZ_INIT();
#endif

int main(int argc, char **argv) {

#ifdef __AFL_HAVE_MANUAL_CONTROL
    __AFL_INIT();
#endif

    while (__AFL_LOOP(1000)) {

        size_t len = __AFL_FUZZ_TESTCASE_LEN;
        if (len < 4) continue;  // avoid trivial junk

        uint8_t *data = __AFL_FUZZ_TESTCASE_BUF;

        AVFormatContext *fmt_ctx = avformat_alloc_context();
        if (!fmt_ctx)
            continue;

        uint8_t *avio_ctx_buffer = av_malloc(len);
        if (!avio_ctx_buffer) {
            avformat_free_context(fmt_ctx);
            continue;
        }

        memcpy(avio_ctx_buffer, data, len);

        AVIOContext *avio_ctx = avio_alloc_context(
            avio_ctx_buffer,
            len,
            0,
            NULL,
            NULL,
            NULL,
            NULL
        );

        if (!avio_ctx) {
            av_free(avio_ctx_buffer);
            avformat_free_context(fmt_ctx);
            continue;
        }

        fmt_ctx->pb = avio_ctx;
        fmt_ctx->flags |= AVFMT_FLAG_CUSTOM_IO;

        if (avformat_open_input(&fmt_ctx, NULL, NULL, NULL) == 0) {

            avformat_find_stream_info(fmt_ctx, NULL);

            AVPacket pkt;
            while (av_read_frame(fmt_ctx, &pkt) >= 0) {
                av_packet_unref(&pkt);
            }
        }

        avformat_close_input(&fmt_ctx);

        av_freep(&avio_ctx->buffer);
        avio_context_free(&avio_ctx);
    }

    return 0;
}
