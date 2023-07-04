/*
gcc -fPIC -shared -o avbuf.so avbuf.c
gcc -Iffmpeg/include -fPIC -shared -o avbuf.dll avbuf.c
*/

#include <stdbool.h>
#include <stdint.h>
#include <math.h>
#include <libavutil/error.h>
#include <libavformat/avformat.h>

typedef struct {
	uint8_t *ptr;
	int64_t offset;
	int64_t size;
} Avbuf;

int Avbuf_read(void *ptr, uint8_t *buf, int len) {
	Avbuf *avbuf = (Avbuf *)ptr;

	if (avbuf->offset + len > avbuf->size)
		len = avbuf->size - avbuf->offset;
	if (len == 0)
		return AVERROR_EOF;

	memcpy(buf, avbuf->ptr + avbuf->offset, len);
	avbuf->offset += len;

	return len;
}

int64_t Avbuf_seek(void *ptr, int64_t pos, int whence) {
	Avbuf *avbuf = (Avbuf *)ptr;

	if (whence == AVSEEK_SIZE)
		return avbuf->size;

	avbuf->offset = pos;

	return pos;
}
