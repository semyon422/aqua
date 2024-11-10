#include "Alloc.c"
#include "CpuArch.c"
#include "LzFind.c"
#include "LzFindMt.c"
#include "LzFindOpt.c"
#include "LzmaDec.c"
#include "LzmaEnc.c"
#include "LzmaLib.c"
#include "Threads.c"

// https://www.7-zip.org/sdk.html
// gcc -IC -shared -fPIC -o 7z.dll 7z.c
// gcc -D_GNU_SOURCE -IC -shared -fPIC -o lib7z.so 7z.c
