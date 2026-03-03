#include <libavformat/avformat.h>
#include <libavutil/mem.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __AFL_HAVE_MANUAL_CONTROL
__AFL_FUZZ_INIT();
#endif

typedef struct {
    const uint8_t *data;
    size_t size;
    size_t pos;
} MemBuffer;

static int read_packet(void *opaque, uint8_t *buf, int buf_size) {
    MemBuffer *mb = (MemBuffer *)opaque;
    if (mb->pos >= mb->size)
        return AVERROR_EOF;
    size_t remaining = mb->size - mb->pos;
    size_t to_copy = remaining < (size_t)buf_size ? remaining : buf_size;
    memcpy(buf, mb->data + mb->pos, to_copy);
    mb->pos += to_copy;
    return (int)to_copy;
}

static int64_t mem_seek(void *opaque, int64_t offset, int whence) {
    MemBuffer *mb = (MemBuffer *)opaque;
    int64_t new_pos;
    if (whence == AVSEEK_SIZE)
        return (int64_t)mb->size;
    else if (whence == SEEK_SET)
        new_pos = offset;
    else if (whence == SEEK_CUR)
        new_pos = (int64_t)mb->pos + offset;
    else if (whence == SEEK_END)
        new_pos = (int64_t)mb->size + offset;
    else
        return -1;
    if (new_pos < 0 || new_pos > (int64_t)mb->size)
        return -1;
    mb->pos = (size_t)new_pos;
    return new_pos;
}

int main(void) {
#ifdef __AFL_HAVE_MANUAL_CONTROL
    __AFL_INIT();
#endif

    while (__AFL_LOOP(1000)) {
        size_t len = __AFL_FUZZ_TESTCASE_LEN;
        if (len < 4 || len > (1 << 20))
            continue;

        uint8_t *data = __AFL_FUZZ_TESTCASE_BUF;

        MemBuffer mb = { data, len, 0 };

        AVFormatContext *fmt_ctx = avformat_alloc_context();
        if (!fmt_ctx)
            continue;

        uint8_t *avio_buf = av_malloc(4096);
        if (!avio_buf) {
            avformat_free_context(fmt_ctx);
            continue;
        }

        AVIOContext *avio_ctx = avio_alloc_context(
            avio_buf, 4096,
            0,
            &mb,
            read_packet,
            NULL,
            mem_seek
        );
        if (!avio_ctx) {
            av_free(avio_buf);
            avformat_free_context(fmt_ctx);
            continue;
        }

        fmt_ctx->pb    = avio_ctx;
        fmt_ctx->flags |= AVFMT_FLAG_CUSTOM_IO;

        int ret = avformat_open_input(&fmt_ctx, NULL, NULL, NULL);
        if (ret == 0) {
            /*
             * avformat_open_input succeeded: FFmpeg now owns both fmt_ctx
             * and fmt_ctx->pb (avio_ctx). Do NOT free them separately —
             * avformat_close_input handles both.
             */
            avformat_find_stream_info(fmt_ctx, NULL);

            AVPacket *pkt = av_packet_alloc();
            if (pkt) {
                while (av_read_frame(fmt_ctx, pkt) >= 0)
                    av_packet_unref(pkt);
                av_packet_free(&pkt);
            }

            avformat_close_input(&fmt_ctx); /* frees fmt_ctx and avio_ctx */
        } else {
            /*
             * avformat_open_input failed: it freed fmt_ctx and set it to
             * NULL, but it did NOT free avio_ctx — we must do that here.
             */
            avio_context_free(&avio_ctx);
            /* fmt_ctx is already NULL; this is a no-op but kept for clarity */
            avformat_free_context(fmt_ctx);
        }
    }

    return 0;
}
