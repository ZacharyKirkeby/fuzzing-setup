#include <libavformat/avformat.h>
#include <libavutil/error.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

static int read_packet(void *opaque, uint8_t *buf, int buf_size) {
    FILE *f = (FILE *)opaque;
    return fread(buf, 1, buf_size, f);
}

int main(int argc, char **argv) {
    if (argc < 2)
        return 0;

    FILE *f = fopen(argv[1], "rb");
    if (!f)
        return 0;

    AVFormatContext *fmt_ctx = avformat_alloc_context();
    if (!fmt_ctx) {
        fclose(f);
        return 0;
    }

    uint8_t *avio_ctx_buffer = av_malloc(4096);
    AVIOContext *avio_ctx = avio_alloc_context(
        avio_ctx_buffer,
        4096,
        0,
        f,
        read_packet,
        NULL,
        NULL
    );

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
    av_free(avio_ctx_buffer);
    fclose(f);
    return 0;
}
