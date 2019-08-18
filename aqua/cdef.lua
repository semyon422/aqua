local ffi = require("ffi")

return ffi.cdef([[
typedef int error_t;
typedef long int ptrdiff_t;
typedef long unsigned int size_t;
typedef short unsigned int wchar_t;
typedef struct {
long long __max_align_ll __attribute__((__aligned__(__alignof__(long long))));
long double __max_align_ld __attribute__((__aligned__(__alignof__(long double))));
} max_align_t;
typedef signed char __int8_t;
typedef unsigned char __uint8_t;
typedef short int __int16_t;
typedef short unsigned int __uint16_t;
typedef int __int32_t;
typedef unsigned int __uint32_t;
typedef long int __int64_t;
typedef long unsigned int __uint64_t;
typedef signed char __int_least8_t;
typedef unsigned char __uint_least8_t;
typedef short int __int_least16_t;
typedef short unsigned int __uint_least16_t;
typedef int __int_least32_t;
typedef unsigned int __uint_least32_t;
typedef long int __int_least64_t;
typedef long unsigned int __uint_least64_t;
typedef long int __intmax_t;
typedef long unsigned int __uintmax_t;
typedef long int __intptr_t;
typedef long unsigned int __uintptr_t;
typedef __int64_t __blkcnt_t;
typedef __int32_t __blksize_t;
typedef __uint32_t __dev_t;
typedef unsigned long __fsblkcnt_t;
typedef unsigned long __fsfilcnt_t;
typedef __uint32_t __uid_t;
typedef __uint32_t __gid_t;
typedef __uint64_t __ino_t;
typedef long long __key_t;
typedef __uint16_t __sa_family_t;
typedef int __socklen_t;
typedef void *_LOCK_T;
void __cygwin_lock_init(_LOCK_T *);
void __cygwin_lock_init_recursive(_LOCK_T *);
void __cygwin_lock_fini(_LOCK_T *);
void __cygwin_lock_lock(_LOCK_T *);
int __cygwin_lock_trylock(_LOCK_T *);
void __cygwin_lock_unlock(_LOCK_T *);
typedef long _off_t;
typedef int __pid_t;
typedef __uint32_t __id_t;
typedef __uint32_t __mode_t;
__extension__ typedef long long _off64_t;
typedef _off_t __off_t;
typedef _off64_t __loff_t;
typedef long _fpos_t;
typedef _off64_t _fpos64_t;
typedef long unsigned int __size_t;
typedef long signed int _ssize_t;
typedef _ssize_t __ssize_t;
typedef unsigned int wint_t;
typedef struct
{
int __count;
union
{
wint_t __wch;
unsigned char __wchb[4];
} __value;
} _mbstate_t;
typedef _LOCK_T _flock_t;
typedef void *_iconv_t;
typedef unsigned long __clock_t;
typedef long __time_t;
typedef unsigned long __clockid_t;
typedef unsigned long __timer_t;
typedef unsigned short __nlink_t;
typedef long __suseconds_t;
typedef unsigned long __useconds_t;
typedef char * __va_list;
typedef unsigned int __ULong;
struct _reent;
struct __locale_t;
struct _Bigint
{
struct _Bigint *_next;
int _k, _maxwds, _sign, _wds;
__ULong _x[1];
};
struct __tm
{
int __tm_sec;
int __tm_min;
int __tm_hour;
int __tm_mday;
int __tm_mon;
int __tm_year;
int __tm_wday;
int __tm_yday;
int __tm_isdst;
};
struct _on_exit_args {
void * _fnargs[32];
void * _dso_handle[32];
__ULong _fntypes;
__ULong _is_cxa;
};
struct _atexit {
struct _atexit *_next;
int _ind;
void (*_fns[32])(void);
struct _on_exit_args _on_exit_args;
};
struct __sbuf {
unsigned char *_base;
int _size;
};
struct __sFILE {
unsigned char *_p;
int _r;
int _w;
short _flags;
short _file;
struct __sbuf _bf;
int _lbfsize;
void * _cookie;
_ssize_t (__attribute__((__cdecl__)) * _read) (struct _reent *, void *, char *, size_t)
;
_ssize_t (__attribute__((__cdecl__)) * _write) (struct _reent *, void *, const char *, size_t)
;
_fpos_t (__attribute__((__cdecl__)) * _seek) (struct _reent *, void *, _fpos_t, int);
int (__attribute__((__cdecl__)) * _close) (struct _reent *, void *);
struct __sbuf _ub;
unsigned char *_up;
int _ur;
unsigned char _ubuf[3];
unsigned char _nbuf[1];
struct __sbuf _lb;
int _blksize;
_off_t _offset;
struct _reent *_data;
_flock_t _lock;
_mbstate_t _mbstate;
int _flags2;
};
struct __sFILE64 {
unsigned char *_p;
int _r;
int _w;
short _flags;
short _file;
struct __sbuf _bf;
int _lbfsize;
struct _reent *_data;
void * _cookie;
_ssize_t (__attribute__((__cdecl__)) * _read) (struct _reent *, void *, char *, size_t)
;
_ssize_t (__attribute__((__cdecl__)) * _write) (struct _reent *, void *, const char *, size_t)
;
_fpos_t (__attribute__((__cdecl__)) * _seek) (struct _reent *, void *, _fpos_t, int);
int (__attribute__((__cdecl__)) * _close) (struct _reent *, void *);
struct __sbuf _ub;
unsigned char *_up;
int _ur;
unsigned char _ubuf[3];
unsigned char _nbuf[1];
struct __sbuf _lb;
int _blksize;
int _flags2;
_off64_t _offset;
_fpos64_t (__attribute__((__cdecl__)) * _seek64) (struct _reent *, void *, _fpos64_t, int);
_flock_t _lock;
_mbstate_t _mbstate;
};
typedef struct __sFILE64 __FILE;
struct _glue
{
struct _glue *_next;
int _niobs;
__FILE *_iobs;
};
struct _rand48 {
unsigned short _seed[3];
unsigned short _mult[3];
unsigned short _add;
};
struct _reent
{
int _errno;
__FILE *_stdin, *_stdout, *_stderr;
int _inc;
char _emergency[25];
int _unspecified_locale_info;
struct __locale_t *_locale;
int __sdidinit;
void (__attribute__((__cdecl__)) * __cleanup) (struct _reent *);
struct _Bigint *_result;
int _result_k;
struct _Bigint *_p5s;
struct _Bigint **_freelist;
int _cvtlen;
char *_cvtbuf;
union
{
struct
{
unsigned int _unused_rand;
char * _strtok_last;
char _asctime_buf[26];
struct __tm _localtime_buf;
int _gamma_signgam;
__extension__ unsigned long long _rand_next;
struct _rand48 _r48;
_mbstate_t _mblen_state;
_mbstate_t _mbtowc_state;
_mbstate_t _wctomb_state;
char _l64a_buf[8];
char _signal_buf[24];
int _getdate_err;
_mbstate_t _mbrlen_state;
_mbstate_t _mbrtowc_state;
_mbstate_t _mbsrtowcs_state;
_mbstate_t _wcrtomb_state;
_mbstate_t _wcsrtombs_state;
int _h_errno;
} _reent;
struct
{
unsigned char * _nextf[30];
unsigned int _nmalloc[30];
} _unused;
} _new;
struct _atexit *_atexit;
struct _atexit _atexit0;
void (**(_sig_func))(int);
struct _glue __sglue;
__FILE __sf[3];
};
extern struct _reent *_impure_ptr ;
extern struct _reent *const _global_impure_ptr ;
void _reclaim_reent (struct _reent *);
struct _reent * __attribute__((__cdecl__)) __getreent (void);
extern int *__errno (void);
extern __attribute__((dllimport)) const char * const _sys_errlist[];
extern __attribute__((dllimport)) int _sys_nerr;
extern __attribute__((dllimport)) const char * const sys_errlist[];
extern __attribute__((dllimport)) int sys_nerr;
extern __attribute__((dllimport)) char *program_invocation_name;
extern __attribute__((dllimport)) char *program_invocation_short_name;
typedef __int8_t int8_t ;
typedef __uint8_t uint8_t ;
typedef __int16_t int16_t ;
typedef __uint16_t uint16_t ;
typedef __int32_t int32_t ;
typedef __uint32_t uint32_t ;
typedef __int64_t int64_t ;
typedef __uint64_t uint64_t ;
typedef __intmax_t intmax_t;
typedef __uintmax_t uintmax_t;
typedef __intptr_t intptr_t;
typedef __uintptr_t uintptr_t;
typedef __int_least8_t int_least8_t;
typedef __uint_least8_t uint_least8_t;
typedef __int_least16_t int_least16_t;
typedef __uint_least16_t uint_least16_t;
typedef __int_least32_t int_least32_t;
typedef __uint_least32_t uint_least32_t;
typedef __int_least64_t int_least64_t;
typedef __uint_least64_t uint_least64_t;
typedef signed char int_fast8_t;
typedef unsigned char uint_fast8_t;
typedef long int int_fast16_t;
typedef long unsigned int uint_fast16_t;
typedef long int int_fast32_t;
typedef long unsigned int uint_fast32_t;
typedef long int int_fast64_t;
typedef long unsigned int uint_fast64_t;
unsigned avutil_version(void);
const char *av_version_info(void);
const char *avutil_configuration(void);
const char *avutil_license(void);
enum AVMediaType {
AVMEDIA_TYPE_UNKNOWN = -1,
AVMEDIA_TYPE_VIDEO,
AVMEDIA_TYPE_AUDIO,
AVMEDIA_TYPE_DATA,
AVMEDIA_TYPE_SUBTITLE,
AVMEDIA_TYPE_ATTACHMENT,
AVMEDIA_TYPE_NB
};
const char *av_get_media_type_string(enum AVMediaType media_type);
enum AVPictureType {
AV_PICTURE_TYPE_NONE = 0,
AV_PICTURE_TYPE_I,
AV_PICTURE_TYPE_P,
AV_PICTURE_TYPE_B,
AV_PICTURE_TYPE_S,
AV_PICTURE_TYPE_SI,
AV_PICTURE_TYPE_SP,
AV_PICTURE_TYPE_BI,
};
char av_get_picture_type_char(enum AVPictureType pict_type);
struct __locale_t;
typedef struct __locale_t *locale_t;
typedef struct {
intmax_t quot;
intmax_t rem;
} imaxdiv_t;
struct _reent;
extern intmax_t imaxabs(intmax_t j);
extern imaxdiv_t imaxdiv(intmax_t numer, intmax_t denomer);
extern intmax_t strtoimax(const char *__restrict, char **__restrict, int);
extern intmax_t _strtoimax_r(struct _reent *, const char *__restrict, char **__restrict, int);
extern uintmax_t strtoumax(const char *__restrict, char **__restrict, int);
extern uintmax_t _strtoumax_r(struct _reent *, const char *__restrict, char **__restrict, int);
extern intmax_t wcstoimax(const wchar_t *__restrict, wchar_t **__restrict, int);
extern intmax_t _wcstoimax_r(struct _reent *, const wchar_t *__restrict, wchar_t **__restrict, int);
extern uintmax_t wcstoumax(const wchar_t *__restrict, wchar_t **__restrict, int);
extern uintmax_t _wcstoumax_r(struct _reent *, const wchar_t *__restrict, wchar_t **__restrict, int);
extern intmax_t strtoimax_l(const char *__restrict, char **_restrict, int, locale_t);
extern uintmax_t strtoumax_l(const char *__restrict, char **_restrict, int, locale_t);
extern intmax_t wcstoimax_l(const wchar_t *__restrict, wchar_t **_restrict, int, locale_t);
extern uintmax_t wcstoumax_l(const wchar_t *__restrict, wchar_t **_restrict, int, locale_t);
extern double atan (double);
extern double cos (double);
extern double sin (double);
extern double tan (double);
extern double tanh (double);
extern double frexp (double, int *);
extern double modf (double, double *);
extern double ceil (double);
extern double fabs (double);
extern double floor (double);
extern double acos (double);
extern double asin (double);
extern double atan2 (double, double);
extern double cosh (double);
extern double sinh (double);
extern double exp (double);
extern double ldexp (double, int);
extern double log (double);
extern double log10 (double);
extern double pow (double, double);
extern double sqrt (double);
extern double fmod (double, double);
extern int finite (double);
extern int finitef (float);
extern int finitel (long double);
extern int isinff (float);
extern int isnanf (float);
extern int isinfl (long double);
extern int isnanl (long double);
extern int isinf (double);
extern int isnan (double);
typedef float float_t;
typedef double double_t;
extern int __isinff (float x);
extern int __isinfd (double x);
extern int __isnanf (float x);
extern int __isnand (double x);
extern int __fpclassifyf (float x);
extern int __fpclassifyd (double x);
extern int __signbitf (float x);
extern int __signbitd (double x);
extern double infinity (void);
extern double nan (const char *);
extern double copysign (double, double);
extern double logb (double);
extern int ilogb (double);
extern double asinh (double);
extern double cbrt (double);
extern double nextafter (double, double);
extern double rint (double);
extern double scalbn (double, int);
extern double exp2 (double);
extern double scalbln (double, long int);
extern double tgamma (double);
extern double nearbyint (double);
extern long int lrint (double);
extern long long int llrint (double);
extern double round (double);
extern long int lround (double);
extern long long int llround (double);
extern double trunc (double);
extern double remquo (double, double, int *);
extern double fdim (double, double);
extern double fmax (double, double);
extern double fmin (double, double);
extern double fma (double, double, double);
extern double log1p (double);
extern double expm1 (double);
extern double acosh (double);
extern double atanh (double);
extern double remainder (double, double);
extern double gamma (double);
extern double lgamma (double);
extern double erf (double);
extern double erfc (double);
extern double log2 (double);
extern double hypot (double, double);
extern float atanf (float);
extern float cosf (float);
extern float sinf (float);
extern float tanf (float);
extern float tanhf (float);
extern float frexpf (float, int *);
extern float modff (float, float *);
extern float ceilf (float);
extern float fabsf (float);
extern float floorf (float);
extern float acosf (float);
extern float asinf (float);
extern float atan2f (float, float);
extern float coshf (float);
extern float sinhf (float);
extern float expf (float);
extern float ldexpf (float, int);
extern float logf (float);
extern float log10f (float);
extern float powf (float, float);
extern float sqrtf (float);
extern float fmodf (float, float);
extern float exp2f (float);
extern float scalblnf (float, long int);
extern float tgammaf (float);
extern float nearbyintf (float);
extern long int lrintf (float);
extern long long int llrintf (float);
extern float roundf (float);
extern long int lroundf (float);
extern long long int llroundf (float);
extern float truncf (float);
extern float remquof (float, float, int *);
extern float fdimf (float, float);
extern float fmaxf (float, float);
extern float fminf (float, float);
extern float fmaf (float, float, float);
extern float infinityf (void);
extern float nanf (const char *);
extern float copysignf (float, float);
extern float logbf (float);
extern int ilogbf (float);
extern float asinhf (float);
extern float cbrtf (float);
extern float nextafterf (float, float);
extern float rintf (float);
extern float scalbnf (float, int);
extern float log1pf (float);
extern float expm1f (float);
extern float acoshf (float);
extern float atanhf (float);
extern float remainderf (float, float);
extern float gammaf (float);
extern float lgammaf (float);
extern float erff (float);
extern float erfcf (float);
extern float log2f (float);
extern float hypotf (float, float);
extern long double atanl (long double);
extern long double cosl (long double);
extern long double sinl (long double);
extern long double tanl (long double);
extern long double tanhl (long double);
extern long double frexpl (long double, int *);
extern long double modfl (long double, long double *);
extern long double ceill (long double);
extern long double fabsl (long double);
extern long double floorl (long double);
extern long double log1pl (long double);
extern long double expm1l (long double);
extern long double acosl (long double);
extern long double asinl (long double);
extern long double atan2l (long double, long double);
extern long double coshl (long double);
extern long double sinhl (long double);
extern long double expl (long double);
extern long double ldexpl (long double, int);
extern long double logl (long double);
extern long double log10l (long double);
extern long double powl (long double, long double);
extern long double sqrtl (long double);
extern long double fmodl (long double, long double);
extern long double hypotl (long double, long double);
extern long double copysignl (long double, long double);
extern long double nanl (const char *);
extern int ilogbl (long double);
extern long double asinhl (long double);
extern long double cbrtl (long double);
extern long double nextafterl (long double, long double);
extern float nexttowardf (float, long double);
extern double nexttoward (double, long double);
extern long double nexttowardl (long double, long double);
extern long double logbl (long double);
extern long double log2l (long double);
extern long double rintl (long double);
extern long double scalbnl (long double, int);
extern long double exp2l (long double);
extern long double scalblnl (long double, long);
extern long double tgammal (long double);
extern long double nearbyintl (long double);
extern long int lrintl (long double);
extern long long int llrintl (long double);
extern long double roundl (long double);
extern long lroundl (long double);
extern long long int llroundl (long double);
extern long double truncl (long double);
extern long double remquol (long double, long double, int *);
extern long double fdiml (long double, long double);
extern long double fmaxl (long double, long double);
extern long double fminl (long double, long double);
extern long double fmal (long double, long double, long double);
extern long double acoshl (long double);
extern long double atanhl (long double);
extern long double remainderl (long double, long double);
extern long double lgammal (long double);
extern long double erfl (long double);
extern long double erfcl (long double);
extern double drem (double, double);
extern float dremf (float, float);
extern float dreml (long double, long double);
extern double gamma_r (double, int *);
extern double lgamma_r (double, int *);
extern float gammaf_r (float, int *);
extern float lgammaf_r (float, int *);
extern double y0 (double);
extern double y1 (double);
extern double yn (int, double);
extern double j0 (double);
extern double j1 (double);
extern double jn (int, double);
extern float y0f (float);
extern float y1f (float);
extern float ynf (int, float);
extern float j0f (float);
extern float j1f (float);
extern float jnf (int, float);
extern int *__signgam (void);
struct exception
{
int type;
char *name;
double arg1;
double arg2;
double retval;
int err;
};
extern int matherr (struct exception *e);
enum __fdlibm_version
{
__fdlibm_ieee = -1,
__fdlibm_svid,
__fdlibm_xopen,
__fdlibm_posix
};
extern __attribute__((dllimport)) enum __fdlibm_version __fdlib_version;
typedef __builtin_va_list __gnuc_va_list;
typedef __gnuc_va_list va_list;
typedef __uint8_t u_int8_t;
typedef __uint16_t u_int16_t;
typedef __uint32_t u_int32_t;
typedef __uint64_t u_int64_t;
typedef int register_t;
static __inline__ __uint32_t __ntohl(__uint32_t);
static __inline__ __uint16_t __ntohs(__uint16_t);
static __inline__ __uint32_t
__ntohl(__uint32_t _x)
{
__asm__("bswap %0" : "=r" (_x) : "0" (_x));
return _x;
}
static __inline__ __uint16_t
__ntohs(__uint16_t _x)
{
__asm__("xchgb %b0,%h0"
: "=Q" (_x)
: "0" (_x));
return _x;
}
typedef unsigned long __sigset_t;
typedef __suseconds_t suseconds_t;
typedef long time_t;
struct timeval {
time_t tv_sec;
suseconds_t tv_usec;
};
struct timespec {
time_t tv_sec;
long tv_nsec;
};
struct itimerspec {
struct timespec it_interval;
struct timespec it_value;
};
typedef __sigset_t sigset_t;
typedef unsigned long fd_mask;
typedef struct _types_fd_set {
fd_mask fds_bits[(((64)+(((sizeof (fd_mask) * 8))-1))/((sizeof (fd_mask) * 8)))];
} _types_fd_set;
int select (int __n, _types_fd_set *__readfds, _types_fd_set *__writefds, _types_fd_set *__exceptfds, struct timeval *__timeout)
;
int pselect (int __n, _types_fd_set *__readfds, _types_fd_set *__writefds, _types_fd_set *__exceptfds, const struct timespec *__timeout, const sigset_t *__set)
;
typedef __uint32_t in_addr_t;
typedef __uint16_t in_port_t;
typedef unsigned char u_char;
typedef unsigned short u_short;
typedef unsigned int u_int;
typedef unsigned long u_long;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef __blkcnt_t blkcnt_t;
typedef __blksize_t blksize_t;
typedef unsigned long clock_t;
typedef long daddr_t;
typedef char * caddr_t;
typedef __fsblkcnt_t fsblkcnt_t;
typedef __fsfilcnt_t fsfilcnt_t;
typedef __id_t id_t;
typedef __ino_t ino_t;
typedef __off_t off_t;
typedef __dev_t dev_t;
typedef __uid_t uid_t;
typedef __gid_t gid_t;
typedef __pid_t pid_t;
typedef __key_t key_t;
typedef _ssize_t ssize_t;
typedef __mode_t mode_t;
typedef __nlink_t nlink_t;
typedef __clockid_t clockid_t;
typedef __timer_t timer_t;
typedef __useconds_t useconds_t;
typedef __int64_t sbintime_t;
typedef struct __pthread_t {char __dummy;} *pthread_t;
typedef struct __pthread_mutex_t {char __dummy;} *pthread_mutex_t;
typedef struct __pthread_key_t {char __dummy;} *pthread_key_t;
typedef struct __pthread_attr_t {char __dummy;} *pthread_attr_t;
typedef struct __pthread_mutexattr_t {char __dummy;} *pthread_mutexattr_t;
typedef struct __pthread_condattr_t {char __dummy;} *pthread_condattr_t;
typedef struct __pthread_cond_t {char __dummy;} *pthread_cond_t;
typedef struct __pthread_barrierattr_t {char __dummy;} *pthread_barrierattr_t;
typedef struct __pthread_barrier_t {char __dummy;} *pthread_barrier_t;
typedef struct
{
pthread_mutex_t mutex;
int state;
}
pthread_once_t;
typedef struct __pthread_spinlock_t {char __dummy;} *pthread_spinlock_t;
typedef struct __pthread_rwlock_t {char __dummy;} *pthread_rwlock_t;
typedef struct __pthread_rwlockattr_t {char __dummy;} *pthread_rwlockattr_t;
static __inline unsigned short
__bswap_16 (unsigned short __x)
{
return (__x >> 8) | (__x << 8);
}
static __inline unsigned int
__bswap_32 (unsigned int __x)
{
return (__bswap_16 (__x & 0xffff) << 16) | (__bswap_16 (__x >> 16));
}
static __inline unsigned long long
__bswap_64 (unsigned long long __x)
{
return (((unsigned long long) __bswap_32 (__x & 0xffffffffull)) << 32) | (__bswap_32 (__x >> 32));
}
typedef struct timespec timespec_t;
typedef struct timespec timestruc_t;
typedef __loff_t loff_t;
struct flock {
short l_type;
short l_whence;
off_t l_start;
off_t l_len;
pid_t l_pid;
};
typedef unsigned long vm_offset_t;
typedef unsigned long vm_size_t;
typedef void *vm_object_t;
typedef char *addr_t;
static __inline__ int gnu_dev_major(dev_t);
static __inline__ int gnu_dev_minor(dev_t);
static __inline__ dev_t gnu_dev_makedev(int, int);
static __inline__ int
gnu_dev_major(dev_t dev)
{
return (int)(((dev) >> 16) & 0xffff);
}
static __inline__ int
gnu_dev_minor(dev_t dev)
{
return (int)((dev) & 0xffff);
}
static __inline__ dev_t
gnu_dev_makedev(int maj, int min)
{
return (((maj) << 16) | ((min) & 0xffff));
}
typedef __FILE FILE;
typedef _fpos64_t fpos_t;
ssize_t __attribute__((__cdecl__)) getline (char **, size_t *, FILE *);
ssize_t __attribute__((__cdecl__)) getdelim (char **, size_t *, int, FILE *);
char * __attribute__((__cdecl__)) ctermid (char *);
FILE * __attribute__((__cdecl__)) tmpfile (void);
char * __attribute__((__cdecl__)) tmpnam (char *);
char * __attribute__((__cdecl__)) tempnam (const char *, const char *);
int __attribute__((__cdecl__)) fclose (FILE *);
int __attribute__((__cdecl__)) fflush (FILE *);
FILE * __attribute__((__cdecl__)) freopen (const char *restrict, const char *restrict, FILE *restrict);
void __attribute__((__cdecl__)) setbuf (FILE *restrict, char *restrict);
int __attribute__((__cdecl__)) setvbuf (FILE *restrict, char *restrict, int, size_t);
int __attribute__((__cdecl__)) fprintf (FILE *restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) fscanf (FILE *restrict, const char *restrict, ...) __attribute__ ((__format__ (__scanf__, 2, 3)))
;
int __attribute__((__cdecl__)) printf (const char *restrict, ...) __attribute__ ((__format__ (__printf__, 1, 2)))
;
int __attribute__((__cdecl__)) scanf (const char *restrict, ...) __attribute__ ((__format__ (__scanf__, 1, 2)))
;
int __attribute__((__cdecl__)) sscanf (const char *restrict, const char *restrict, ...) __attribute__ ((__format__ (__scanf__, 2, 3)))
;
int __attribute__((__cdecl__)) vfprintf (FILE *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) vprintf (const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 1, 0)))
;
int __attribute__((__cdecl__)) vsprintf (char *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) fgetc (FILE *);
char * __attribute__((__cdecl__)) fgets (char *restrict, int, FILE *restrict);
int __attribute__((__cdecl__)) fputc (int, FILE *);
int __attribute__((__cdecl__)) fputs (const char *restrict, FILE *restrict);
int __attribute__((__cdecl__)) getc (FILE *);
int __attribute__((__cdecl__)) getchar (void);
char * __attribute__((__cdecl__)) gets (char *);
int __attribute__((__cdecl__)) putc (int, FILE *);
int __attribute__((__cdecl__)) putchar (int);
int __attribute__((__cdecl__)) puts (const char *);
int __attribute__((__cdecl__)) ungetc (int, FILE *);
size_t __attribute__((__cdecl__)) fread (void * restrict, size_t _size, size_t _n, FILE *restrict);
size_t __attribute__((__cdecl__)) fwrite (const void * restrict , size_t _size, size_t _n, FILE *);
int __attribute__((__cdecl__)) fgetpos (FILE *restrict, fpos_t *restrict);
int __attribute__((__cdecl__)) fseek (FILE *, long, int);
int __attribute__((__cdecl__)) fsetpos (FILE *, const fpos_t *);
long __attribute__((__cdecl__)) ftell ( FILE *);
void __attribute__((__cdecl__)) rewind (FILE *);
void __attribute__((__cdecl__)) clearerr (FILE *);
int __attribute__((__cdecl__)) feof (FILE *);
int __attribute__((__cdecl__)) ferror (FILE *);
void __attribute__((__cdecl__)) perror (const char *);
FILE * __attribute__((__cdecl__)) fopen (const char *restrict _name, const char *restrict _type);
int __attribute__((__cdecl__)) sprintf (char *restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) remove (const char *);
int __attribute__((__cdecl__)) rename (const char *, const char *);
int __attribute__((__cdecl__)) fseeko (FILE *, off_t, int);
off_t __attribute__((__cdecl__)) ftello ( FILE *);
int __attribute__((__cdecl__)) snprintf (char *restrict, size_t, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) vsnprintf (char *restrict, size_t, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) vfscanf (FILE *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 2, 0)))
;
int __attribute__((__cdecl__)) vscanf (const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 1, 0)))
;
int __attribute__((__cdecl__)) vsscanf (const char *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 2, 0)))
;
int __attribute__((__cdecl__)) asiprintf (char **, const char *, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
char * __attribute__((__cdecl__)) asniprintf (char *, size_t *, const char *, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
char * __attribute__((__cdecl__)) asnprintf (char *restrict, size_t *restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) diprintf (int, const char *, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) fiprintf (FILE *, const char *, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) fiscanf (FILE *, const char *, ...) __attribute__ ((__format__ (__scanf__, 2, 3)))
;
int __attribute__((__cdecl__)) iprintf (const char *, ...) __attribute__ ((__format__ (__printf__, 1, 2)))
;
int __attribute__((__cdecl__)) iscanf (const char *, ...) __attribute__ ((__format__ (__scanf__, 1, 2)))
;
int __attribute__((__cdecl__)) siprintf (char *, const char *, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) siscanf (const char *, const char *, ...) __attribute__ ((__format__ (__scanf__, 2, 3)))
;
int __attribute__((__cdecl__)) sniprintf (char *, size_t, const char *, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) vasiprintf (char **, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
char * __attribute__((__cdecl__)) vasniprintf (char *, size_t *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
char * __attribute__((__cdecl__)) vasnprintf (char *, size_t *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) vdiprintf (int, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) vfiprintf (FILE *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) vfiscanf (FILE *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 2, 0)))
;
int __attribute__((__cdecl__)) viprintf (const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 1, 0)))
;
int __attribute__((__cdecl__)) viscanf (const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 1, 0)))
;
int __attribute__((__cdecl__)) vsiprintf (char *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) vsiscanf (const char *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 2, 0)))
;
int __attribute__((__cdecl__)) vsniprintf (char *, size_t, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
FILE * __attribute__((__cdecl__)) fdopen (int, const char *);
int __attribute__((__cdecl__)) fileno (FILE *);
int __attribute__((__cdecl__)) pclose (FILE *);
FILE * __attribute__((__cdecl__)) popen (const char *, const char *);
void __attribute__((__cdecl__)) setbuffer (FILE *, char *, int);
int __attribute__((__cdecl__)) setlinebuf (FILE *);
int __attribute__((__cdecl__)) getw (FILE *);
int __attribute__((__cdecl__)) putw (int, FILE *);
int __attribute__((__cdecl__)) getc_unlocked (FILE *);
int __attribute__((__cdecl__)) getchar_unlocked (void);
void __attribute__((__cdecl__)) flockfile (FILE *);
int __attribute__((__cdecl__)) ftrylockfile (FILE *);
void __attribute__((__cdecl__)) funlockfile (FILE *);
int __attribute__((__cdecl__)) putc_unlocked (int, FILE *);
int __attribute__((__cdecl__)) putchar_unlocked (int);
int __attribute__((__cdecl__)) dprintf (int, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
FILE * __attribute__((__cdecl__)) fmemopen (void *restrict, size_t, const char *restrict);
FILE * __attribute__((__cdecl__)) open_memstream (char **, size_t *);
int __attribute__((__cdecl__)) vdprintf (int, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) renameat (int, const char *, int, const char *);
int __attribute__((__cdecl__)) renameat2 (int, const char *, int, const char *, unsigned int);
int __attribute__((__cdecl__)) _asiprintf_r (struct _reent *, char **, const char *, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
char * __attribute__((__cdecl__)) _asniprintf_r (struct _reent *, char *, size_t *, const char *, ...) __attribute__ ((__format__ (__printf__, 4, 5)))
;
char * __attribute__((__cdecl__)) _asnprintf_r (struct _reent *, char *restrict, size_t *restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 4, 5)))
;
int __attribute__((__cdecl__)) _asprintf_r (struct _reent *, char **restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _diprintf_r (struct _reent *, int, const char *, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _dprintf_r (struct _reent *, int, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _fclose_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) _fcloseall_r (struct _reent *);
FILE * __attribute__((__cdecl__)) _fdopen_r (struct _reent *, int, const char *);
int __attribute__((__cdecl__)) _fflush_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) _fgetc_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) _fgetc_unlocked_r (struct _reent *, FILE *);
char * __attribute__((__cdecl__)) _fgets_r (struct _reent *, char *restrict, int, FILE *restrict);
char * __attribute__((__cdecl__)) _fgets_unlocked_r (struct _reent *, char *restrict, int, FILE *restrict);
int __attribute__((__cdecl__)) _fgetpos_r (struct _reent *, FILE *, fpos_t *);
int __attribute__((__cdecl__)) _fsetpos_r (struct _reent *, FILE *, const fpos_t *);
int __attribute__((__cdecl__)) _fiprintf_r (struct _reent *, FILE *, const char *, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _fiscanf_r (struct _reent *, FILE *, const char *, ...) __attribute__ ((__format__ (__scanf__, 3, 4)))
;
FILE * __attribute__((__cdecl__)) _fmemopen_r (struct _reent *, void *restrict, size_t, const char *restrict);
FILE * __attribute__((__cdecl__)) _fopen_r (struct _reent *, const char *restrict, const char *restrict);
FILE * __attribute__((__cdecl__)) _freopen_r (struct _reent *, const char *restrict, const char *restrict, FILE *restrict);
int __attribute__((__cdecl__)) _fprintf_r (struct _reent *, FILE *restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _fpurge_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) _fputc_r (struct _reent *, int, FILE *);
int __attribute__((__cdecl__)) _fputc_unlocked_r (struct _reent *, int, FILE *);
int __attribute__((__cdecl__)) _fputs_r (struct _reent *, const char *restrict, FILE *restrict);
int __attribute__((__cdecl__)) _fputs_unlocked_r (struct _reent *, const char *restrict, FILE *restrict);
size_t __attribute__((__cdecl__)) _fread_r (struct _reent *, void * restrict, size_t _size, size_t _n, FILE *restrict);
size_t __attribute__((__cdecl__)) _fread_unlocked_r (struct _reent *, void * restrict, size_t _size, size_t _n, FILE *restrict);
int __attribute__((__cdecl__)) _fscanf_r (struct _reent *, FILE *restrict, const char *restrict, ...) __attribute__ ((__format__ (__scanf__, 3, 4)))
;
int __attribute__((__cdecl__)) _fseek_r (struct _reent *, FILE *, long, int);
int __attribute__((__cdecl__)) _fseeko_r (struct _reent *, FILE *, _off_t, int);
long __attribute__((__cdecl__)) _ftell_r (struct _reent *, FILE *);
_off_t __attribute__((__cdecl__)) _ftello_r (struct _reent *, FILE *);
void __attribute__((__cdecl__)) _rewind_r (struct _reent *, FILE *);
size_t __attribute__((__cdecl__)) _fwrite_r (struct _reent *, const void * restrict, size_t _size, size_t _n, FILE *restrict);
size_t __attribute__((__cdecl__)) _fwrite_unlocked_r (struct _reent *, const void * restrict, size_t _size, size_t _n, FILE *restrict);
int __attribute__((__cdecl__)) _getc_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) _getc_unlocked_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) _getchar_r (struct _reent *);
int __attribute__((__cdecl__)) _getchar_unlocked_r (struct _reent *);
char * __attribute__((__cdecl__)) _gets_r (struct _reent *, char *);
int __attribute__((__cdecl__)) _iprintf_r (struct _reent *, const char *, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) _iscanf_r (struct _reent *, const char *, ...) __attribute__ ((__format__ (__scanf__, 2, 3)))
;
FILE * __attribute__((__cdecl__)) _open_memstream_r (struct _reent *, char **, size_t *);
void __attribute__((__cdecl__)) _perror_r (struct _reent *, const char *);
int __attribute__((__cdecl__)) _printf_r (struct _reent *, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 2, 3)))
;
int __attribute__((__cdecl__)) _putc_r (struct _reent *, int, FILE *);
int __attribute__((__cdecl__)) _putc_unlocked_r (struct _reent *, int, FILE *);
int __attribute__((__cdecl__)) _putchar_unlocked_r (struct _reent *, int);
int __attribute__((__cdecl__)) _putchar_r (struct _reent *, int);
int __attribute__((__cdecl__)) _puts_r (struct _reent *, const char *);
int __attribute__((__cdecl__)) _remove_r (struct _reent *, const char *);
int __attribute__((__cdecl__)) _rename_r (struct _reent *, const char *_old, const char *_new)
;
int __attribute__((__cdecl__)) _scanf_r (struct _reent *, const char *restrict, ...) __attribute__ ((__format__ (__scanf__, 2, 3)))
;
int __attribute__((__cdecl__)) _siprintf_r (struct _reent *, char *, const char *, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _siscanf_r (struct _reent *, const char *, const char *, ...) __attribute__ ((__format__ (__scanf__, 3, 4)))
;
int __attribute__((__cdecl__)) _sniprintf_r (struct _reent *, char *, size_t, const char *, ...) __attribute__ ((__format__ (__printf__, 4, 5)))
;
int __attribute__((__cdecl__)) _snprintf_r (struct _reent *, char *restrict, size_t, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 4, 5)))
;
int __attribute__((__cdecl__)) _sprintf_r (struct _reent *, char *restrict, const char *restrict, ...) __attribute__ ((__format__ (__printf__, 3, 4)))
;
int __attribute__((__cdecl__)) _sscanf_r (struct _reent *, const char *restrict, const char *restrict, ...) __attribute__ ((__format__ (__scanf__, 3, 4)))
;
char * __attribute__((__cdecl__)) _tempnam_r (struct _reent *, const char *, const char *);
FILE * __attribute__((__cdecl__)) _tmpfile_r (struct _reent *);
char * __attribute__((__cdecl__)) _tmpnam_r (struct _reent *, char *);
int __attribute__((__cdecl__)) _ungetc_r (struct _reent *, int, FILE *);
int __attribute__((__cdecl__)) _vasiprintf_r (struct _reent *, char **, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
char * __attribute__((__cdecl__)) _vasniprintf_r (struct _reent*, char *, size_t *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 4, 0)))
;
char * __attribute__((__cdecl__)) _vasnprintf_r (struct _reent*, char *, size_t *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 4, 0)))
;
int __attribute__((__cdecl__)) _vasprintf_r (struct _reent *, char **, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vdiprintf_r (struct _reent *, int, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vdprintf_r (struct _reent *, int, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vfiprintf_r (struct _reent *, FILE *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vfiscanf_r (struct _reent *, FILE *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vfprintf_r (struct _reent *, FILE *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vfscanf_r (struct _reent *, FILE *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 3, 0)))
;
int __attribute__((__cdecl__)) _viprintf_r (struct _reent *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) _viscanf_r (struct _reent *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 2, 0)))
;
int __attribute__((__cdecl__)) _vprintf_r (struct _reent *, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 2, 0)))
;
int __attribute__((__cdecl__)) _vscanf_r (struct _reent *, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 2, 0)))
;
int __attribute__((__cdecl__)) _vsiprintf_r (struct _reent *, char *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vsiscanf_r (struct _reent *, const char *, const char *, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vsniprintf_r (struct _reent *, char *, size_t, const char *, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 4, 0)))
;
int __attribute__((__cdecl__)) _vsnprintf_r (struct _reent *, char *restrict, size_t, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 4, 0)))
;
int __attribute__((__cdecl__)) _vsprintf_r (struct _reent *, char *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__printf__, 3, 0)))
;
int __attribute__((__cdecl__)) _vsscanf_r (struct _reent *, const char *restrict, const char *restrict, __gnuc_va_list) __attribute__ ((__format__ (__scanf__, 3, 0)))
;
int __attribute__((__cdecl__)) fpurge (FILE *);
ssize_t __attribute__((__cdecl__)) __getdelim (char **, size_t *, int, FILE *);
ssize_t __attribute__((__cdecl__)) __getline (char **, size_t *, FILE *);
void __attribute__((__cdecl__)) clearerr_unlocked (FILE *);
int __attribute__((__cdecl__)) feof_unlocked (FILE *);
int __attribute__((__cdecl__)) ferror_unlocked (FILE *);
int __attribute__((__cdecl__)) fileno_unlocked (FILE *);
int __attribute__((__cdecl__)) fflush_unlocked (FILE *);
int __attribute__((__cdecl__)) fgetc_unlocked (FILE *);
int __attribute__((__cdecl__)) fputc_unlocked (int, FILE *);
size_t __attribute__((__cdecl__)) fread_unlocked (void * restrict, size_t _size, size_t _n, FILE *restrict);
size_t __attribute__((__cdecl__)) fwrite_unlocked (const void * restrict , size_t _size, size_t _n, FILE *);
int __attribute__((__cdecl__)) __srget_r (struct _reent *, FILE *);
int __attribute__((__cdecl__)) __swbuf_r (struct _reent *, int, FILE *);
FILE *__attribute__((__cdecl__)) funopen (const void * __cookie, int (*__readfn)(void * __c, char *__buf, size_t __n), int (*__writefn)(void * __c, const char *__buf, size_t __n), _fpos64_t (*__seekfn)(void * __c, _fpos64_t __off, int __whence), int (*__closefn)(void * __c))
;
FILE *__attribute__((__cdecl__)) _funopen_r (struct _reent *, const void * __cookie, int (*__readfn)(void * __c, char *__buf, size_t __n), int (*__writefn)(void * __c, const char *__buf, size_t __n), _fpos64_t (*__seekfn)(void * __c, _fpos64_t __off, int __whence), int (*__closefn)(void * __c))
;
static __inline__ int __sgetc_r(struct _reent *__ptr, FILE *__p);
static __inline__ int __sgetc_r(struct _reent *__ptr, FILE *__p)
{
int __c = (--(__p)->_r < 0 ? __srget_r(__ptr, __p) : (int)(*(__p)->_p++));
if ((__p->_flags & 0x4000) && (__c == '\r'))
{
int __c2 = (--(__p)->_r < 0 ? __srget_r(__ptr, __p) : (int)(*(__p)->_p++));
if (__c2 == '\n')
__c = __c2;
else
ungetc(__c2, __p);
}
return __c;
}
static __inline__ int __sputc_r(struct _reent *_ptr, int _c, FILE *_p) {
if ((_p->_flags & 0x4000) && _c == '\n')
__sputc_r (_ptr, '\r', _p);
if (--_p->_w >= 0 || (_p->_w >= _p->_lbfsize && (char)_c != '\n'))
return (*_p->_p++ = _c);
else
return (__swbuf_r(_ptr, _c, _p));
}
static __inline int
_getchar_unlocked(void)
{
struct _reent *_ptr;
_ptr = (__getreent());
return (__sgetc_r(_ptr, ((_ptr)->_stdin)));
}
static __inline int
_putchar_unlocked(int _c)
{
struct _reent *_ptr;
_ptr = (__getreent());
return (__sputc_r(_ptr, _c, ((_ptr)->_stdout)));
}
char *mkdtemp (char *);
const char *getprogname (void);
void setprogname (const char *);
int unsetenv (const char *);
extern void * memalign (size_t, size_t);
extern void * valloc (size_t);
int getloadavg(double loadavg[], int nelem);
typedef struct
{
int quot;
int rem;
} div_t;
typedef struct
{
long quot;
long rem;
} ldiv_t;
typedef struct
{
long long int quot;
long long int rem;
} lldiv_t;
typedef int (*__compar_fn_t) (const void *, const void *);
int __attribute__((__cdecl__)) __locale_mb_cur_max (void);
void __attribute__((__cdecl__)) abort (void) __attribute__ ((__noreturn__));
int __attribute__((__cdecl__)) abs (int);
__uint32_t __attribute__((__cdecl__)) arc4random (void);
__uint32_t __attribute__((__cdecl__)) arc4random_uniform (__uint32_t);
void __attribute__((__cdecl__)) arc4random_buf (void *, size_t);
int __attribute__((__cdecl__)) atexit (void (*__func)(void));
double __attribute__((__cdecl__)) atof (const char *__nptr);
float __attribute__((__cdecl__)) atoff (const char *__nptr);
int __attribute__((__cdecl__)) atoi (const char *__nptr);
int __attribute__((__cdecl__)) _atoi_r (struct _reent *, const char *__nptr);
long __attribute__((__cdecl__)) atol (const char *__nptr);
long __attribute__((__cdecl__)) _atol_r (struct _reent *, const char *__nptr);
void * __attribute__((__cdecl__)) bsearch (const void * __key, const void * __base, size_t __nmemb, size_t __size, __compar_fn_t _compar)
;
void * __attribute__((__cdecl__)) calloc (size_t __nmemb, size_t __size) ;
div_t __attribute__((__cdecl__)) div (int __numer, int __denom);
void __attribute__((__cdecl__)) exit (int __status) __attribute__ ((__noreturn__));
void __attribute__((__cdecl__)) free (void *) ;
char * __attribute__((__cdecl__)) getenv (const char *__string);
char * __attribute__((__cdecl__)) _getenv_r (struct _reent *, const char *__string);
char * __attribute__((__cdecl__)) _findenv (const char *, int *);
char * __attribute__((__cdecl__)) _findenv_r (struct _reent *, const char *, int *);
extern char *suboptarg;
int __attribute__((__cdecl__)) getsubopt (char **, char * const *, char **);
long __attribute__((__cdecl__)) labs (long);
ldiv_t __attribute__((__cdecl__)) ldiv (long __numer, long __denom);
void * __attribute__((__cdecl__)) malloc (size_t __size) ;
int __attribute__((__cdecl__)) mblen (const char *, size_t);
int __attribute__((__cdecl__)) _mblen_r (struct _reent *, const char *, size_t, _mbstate_t *);
int __attribute__((__cdecl__)) mbtowc (wchar_t *restrict, const char *restrict, size_t);
int __attribute__((__cdecl__)) _mbtowc_r (struct _reent *, wchar_t *restrict, const char *restrict, size_t, _mbstate_t *);
int __attribute__((__cdecl__)) wctomb (char *, wchar_t);
int __attribute__((__cdecl__)) _wctomb_r (struct _reent *, char *, wchar_t, _mbstate_t *);
size_t __attribute__((__cdecl__)) mbstowcs (wchar_t *restrict, const char *restrict, size_t);
size_t __attribute__((__cdecl__)) _mbstowcs_r (struct _reent *, wchar_t *restrict, const char *restrict, size_t, _mbstate_t *);
size_t __attribute__((__cdecl__)) wcstombs (char *restrict, const wchar_t *restrict, size_t);
size_t __attribute__((__cdecl__)) _wcstombs_r (struct _reent *, char *restrict, const wchar_t *restrict, size_t, _mbstate_t *);
char * __attribute__((__cdecl__)) mkdtemp (char *);
int __attribute__((__cdecl__)) mkstemp (char *);
int __attribute__((__cdecl__)) mkstemps (char *, int);
char * __attribute__((__cdecl__)) mktemp (char *) __attribute__ ((__deprecated__("the use of `mktemp' is dangerous; use `mkstemp' instead")));
char * __attribute__((__cdecl__)) _mkdtemp_r (struct _reent *, char *);
int __attribute__((__cdecl__)) _mkostemp_r (struct _reent *, char *, int);
int __attribute__((__cdecl__)) _mkostemps_r (struct _reent *, char *, int, int);
int __attribute__((__cdecl__)) _mkstemp_r (struct _reent *, char *);
int __attribute__((__cdecl__)) _mkstemps_r (struct _reent *, char *, int);
char * __attribute__((__cdecl__)) _mktemp_r (struct _reent *, char *) __attribute__ ((__deprecated__("the use of `mktemp' is dangerous; use `mkstemp' instead")));
void __attribute__((__cdecl__)) qsort (void * __base, size_t __nmemb, size_t __size, __compar_fn_t _compar);
int __attribute__((__cdecl__)) rand (void);
void * __attribute__((__cdecl__)) realloc (void * __r, size_t __size) ;
void *reallocarray(void *, size_t, size_t) __attribute__((__warn_unused_result__)) __attribute__((__alloc_size__(2)))
__attribute__((__alloc_size__(3)));
void * __attribute__((__cdecl__)) reallocf (void * __r, size_t __size);
char * __attribute__((__cdecl__)) realpath (const char *restrict path, char *restrict resolved_path);
int __attribute__((__cdecl__)) rpmatch (const char *response);
void __attribute__((__cdecl__)) srand (unsigned __seed);
double __attribute__((__cdecl__)) strtod (const char *restrict __n, char **restrict __end_PTR);
double __attribute__((__cdecl__)) _strtod_r (struct _reent *,const char *restrict __n, char **restrict __end_PTR);
float __attribute__((__cdecl__)) strtof (const char *restrict __n, char **restrict __end_PTR);
long __attribute__((__cdecl__)) strtol (const char *restrict __n, char **restrict __end_PTR, int __base);
long __attribute__((__cdecl__)) _strtol_r (struct _reent *,const char *restrict __n, char **restrict __end_PTR, int __base);
unsigned long __attribute__((__cdecl__)) strtoul (const char *restrict __n, char **restrict __end_PTR, int __base);
unsigned long __attribute__((__cdecl__)) _strtoul_r (struct _reent *,const char *restrict __n, char **restrict __end_PTR, int __base);
int __attribute__((__cdecl__)) system (const char *__string);
long __attribute__((__cdecl__)) a64l (const char *__input);
char * __attribute__((__cdecl__)) l64a (long __input);
char * __attribute__((__cdecl__)) _l64a_r (struct _reent *,long __input);
int __attribute__((__cdecl__)) on_exit (void (*__func)(int, void *),void * __arg);
void __attribute__((__cdecl__)) _Exit (int __status) __attribute__ ((__noreturn__));
int __attribute__((__cdecl__)) putenv (char *__string);
int __attribute__((__cdecl__)) _putenv_r (struct _reent *, char *__string);
void * __attribute__((__cdecl__)) _reallocf_r (struct _reent *, void *, size_t);
int __attribute__((__cdecl__)) setenv (const char *__string, const char *__value, int __overwrite);
int __attribute__((__cdecl__)) _setenv_r (struct _reent *, const char *__string, const char *__value, int __overwrite);
char * __attribute__((__cdecl__)) __itoa (int, char *, int);
char * __attribute__((__cdecl__)) __utoa (unsigned, char *, int);
char * __attribute__((__cdecl__)) itoa (int, char *, int);
char * __attribute__((__cdecl__)) utoa (unsigned, char *, int);
int __attribute__((__cdecl__)) rand_r (unsigned *__seed);
double __attribute__((__cdecl__)) drand48 (void);
double __attribute__((__cdecl__)) _drand48_r (struct _reent *);
double __attribute__((__cdecl__)) erand48 (unsigned short [3]);
double __attribute__((__cdecl__)) _erand48_r (struct _reent *, unsigned short [3]);
long __attribute__((__cdecl__)) jrand48 (unsigned short [3]);
long __attribute__((__cdecl__)) _jrand48_r (struct _reent *, unsigned short [3]);
void __attribute__((__cdecl__)) lcong48 (unsigned short [7]);
void __attribute__((__cdecl__)) _lcong48_r (struct _reent *, unsigned short [7]);
long __attribute__((__cdecl__)) lrand48 (void);
long __attribute__((__cdecl__)) _lrand48_r (struct _reent *);
long __attribute__((__cdecl__)) mrand48 (void);
long __attribute__((__cdecl__)) _mrand48_r (struct _reent *);
long __attribute__((__cdecl__)) nrand48 (unsigned short [3]);
long __attribute__((__cdecl__)) _nrand48_r (struct _reent *, unsigned short [3]);
unsigned short *
__attribute__((__cdecl__)) seed48 (unsigned short [3]);
unsigned short *
__attribute__((__cdecl__)) _seed48_r (struct _reent *, unsigned short [3]);
void __attribute__((__cdecl__)) srand48 (long);
void __attribute__((__cdecl__)) _srand48_r (struct _reent *, long);
char * __attribute__((__cdecl__)) initstate (unsigned, char *, size_t);
long __attribute__((__cdecl__)) random (void);
char * __attribute__((__cdecl__)) setstate (char *);
void __attribute__((__cdecl__)) srandom (unsigned);
long long __attribute__((__cdecl__)) atoll (const char *__nptr);
long long __attribute__((__cdecl__)) _atoll_r (struct _reent *, const char *__nptr);
long long __attribute__((__cdecl__)) llabs (long long);
lldiv_t __attribute__((__cdecl__)) lldiv (long long __numer, long long __denom);
long long __attribute__((__cdecl__)) strtoll (const char *restrict __n, char **restrict __end_PTR, int __base);
long long __attribute__((__cdecl__)) _strtoll_r (struct _reent *, const char *restrict __n, char **restrict __end_PTR, int __base);
unsigned long long __attribute__((__cdecl__)) strtoull (const char *restrict __n, char **restrict __end_PTR, int __base);
unsigned long long __attribute__((__cdecl__)) _strtoull_r (struct _reent *, const char *restrict __n, char **restrict __end_PTR, int __base);
int __attribute__((__cdecl__)) __attribute__((__nonnull__(1))) posix_memalign (void **, size_t, size_t);
char * __attribute__((__cdecl__)) _dtoa_r (struct _reent *, double, int, int, int *, int*, char**);
int __attribute__((__cdecl__)) _system_r (struct _reent *, const char *);
void __attribute__((__cdecl__)) __eprintf (const char *, const char *, unsigned int, const char *);
void __attribute__((__cdecl__)) qsort_r (void * __base, size_t __nmemb, size_t __size, void * __thunk, int (*_compar)(void *, const void *, const void *))
__asm__ ("" "__bsd_qsort_r");
extern long double _strtold_r (struct _reent *, const char *restrict, char **restrict);
extern long double strtold (const char *restrict, char **restrict);
void * aligned_alloc(size_t, size_t) __attribute__((__malloc__)) __attribute__((__alloc_align__(1)))
__attribute__((__alloc_size__(2)));
int at_quick_exit(void (*)(void));
void
quick_exit(int);
int bcmp(const void *, const void *, size_t) __attribute__((__pure__));
void bcopy(const void *, void *, size_t);
void bzero(void *, size_t);
void explicit_bzero(void *, size_t);
int ffs(int) __attribute__((__const__));
int fls(int) __attribute__((__const__));
int flsl(long) __attribute__((__const__));
int flsll(long long) __attribute__((__const__));
char *index(const char *, int) __attribute__((__pure__));
char *rindex(const char *, int) __attribute__((__pure__));
int strcasecmp(const char *, const char *) __attribute__((__pure__));
int strncasecmp(const char *, const char *, size_t) __attribute__((__pure__));
int strcasecmp_l (const char *, const char *, locale_t);
int strncasecmp_l (const char *, const char *, size_t, locale_t);
void * __attribute__((__cdecl__)) memchr (const void *, int, size_t);
int __attribute__((__cdecl__)) memcmp (const void *, const void *, size_t);
void * __attribute__((__cdecl__)) memcpy (void * restrict, const void * restrict, size_t);
void * __attribute__((__cdecl__)) memmove (void *, const void *, size_t);
void * __attribute__((__cdecl__)) memset (void *, int, size_t);
char *__attribute__((__cdecl__)) strcat (char *restrict, const char *restrict);
char *__attribute__((__cdecl__)) strchr (const char *, int);
int __attribute__((__cdecl__)) strcmp (const char *, const char *);
int __attribute__((__cdecl__)) strcoll (const char *, const char *);
char *__attribute__((__cdecl__)) strcpy (char *restrict, const char *restrict);
size_t __attribute__((__cdecl__)) strcspn (const char *, const char *);
char *__attribute__((__cdecl__)) strerror (int);
size_t __attribute__((__cdecl__)) strlen (const char *);
char *__attribute__((__cdecl__)) strncat (char *restrict, const char *restrict, size_t);
int __attribute__((__cdecl__)) strncmp (const char *, const char *, size_t);
char *__attribute__((__cdecl__)) strncpy (char *restrict, const char *restrict, size_t);
char *__attribute__((__cdecl__)) strpbrk (const char *, const char *);
char *__attribute__((__cdecl__)) strrchr (const char *, int);
size_t __attribute__((__cdecl__)) strspn (const char *, const char *);
char *__attribute__((__cdecl__)) strstr (const char *, const char *);
char *__attribute__((__cdecl__)) strtok (char *restrict, const char *restrict);
size_t __attribute__((__cdecl__)) strxfrm (char *restrict, const char *restrict, size_t);
int strcoll_l (const char *, const char *, locale_t);
char *strerror_l (int, locale_t);
size_t strxfrm_l (char *restrict, const char *restrict, size_t, locale_t);
char *__attribute__((__cdecl__)) strtok_r (char *restrict, const char *restrict, char **restrict);
int __attribute__((__cdecl__)) timingsafe_bcmp (const void *, const void *, size_t);
int __attribute__((__cdecl__)) timingsafe_memcmp (const void *, const void *, size_t);
void * __attribute__((__cdecl__)) memccpy (void * restrict, const void * restrict, int, size_t);
char *__attribute__((__cdecl__)) stpcpy (char *restrict, const char *restrict);
char *__attribute__((__cdecl__)) stpncpy (char *restrict, const char *restrict, size_t);
char *__attribute__((__cdecl__)) strdup (const char *);
char *__attribute__((__cdecl__)) _strdup_r (struct _reent *, const char *);
char *__attribute__((__cdecl__)) strndup (const char *, size_t);
char *__attribute__((__cdecl__)) _strndup_r (struct _reent *, const char *, size_t);
int __attribute__((__cdecl__)) strerror_r (int, char *, size_t)
__asm__ ("" "__xpg_strerror_r")
;
char * __attribute__((__cdecl__)) _strerror_r (struct _reent *, int, int, int *);
size_t __attribute__((__cdecl__)) strlcat (char *, const char *, size_t);
size_t __attribute__((__cdecl__)) strlcpy (char *, const char *, size_t);
size_t __attribute__((__cdecl__)) strnlen (const char *, size_t);
char *__attribute__((__cdecl__)) strsep (char **, const char *);
char *strnstr(const char *, const char *, size_t) __attribute__((__pure__));
char *__attribute__((__cdecl__)) strlwr (char *);
char *__attribute__((__cdecl__)) strupr (char *);
char *__attribute__((__cdecl__)) strsignal (int __signo);
int __attribute__((__cdecl__)) strtosigno (const char *__name);
__attribute__((const)) int av_log2(unsigned v);
__attribute__((const)) int av_log2_16bit(unsigned v);
static __attribute__((always_inline)) inline __attribute__((const)) int av_clip_c(int a, int amin, int amax)
{
if (a < amin) return amin;
else if (a > amax) return amax;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) int64_t av_clip64_c(int64_t a, int64_t amin, int64_t amax)
{
if (a < amin) return amin;
else if (a > amax) return amax;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) uint8_t av_clip_uint8_c(int a)
{
if (a&(~0xFF)) return (~a)>>31;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) int8_t av_clip_int8_c(int a)
{
if ((a+0x80U) & ~0xFF) return (a>>31) ^ 0x7F;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) uint16_t av_clip_uint16_c(int a)
{
if (a&(~0xFFFF)) return (~a)>>31;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) int16_t av_clip_int16_c(int a)
{
if ((a+0x8000U) & ~0xFFFF) return (a>>31) ^ 0x7FFF;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) int32_t av_clipl_int32_c(int64_t a)
{
if ((a+0x80000000u) & ~0xFFFFFFFFUL) return (int32_t)((a>>63) ^ 0x7FFFFFFF);
else return (int32_t)a;
}
static __attribute__((always_inline)) inline __attribute__((const)) int av_clip_intp2_c(int a, int p)
{
if (((unsigned)a + (1 << p)) & ~((2 << p) - 1))
return (a >> 31) ^ ((1 << p) - 1);
else
return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) unsigned av_clip_uintp2_c(int a, int p)
{
if (a & ~((1<<p) - 1)) return (~a) >> 31 & ((1<<p) - 1);
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) unsigned av_mod_uintp2_c(unsigned a, unsigned p)
{
return a & ((1 << p) - 1);
}
static __attribute__((always_inline)) inline int av_sat_add32_c(int a, int b)
{
return av_clipl_int32_c((int64_t)a + b);
}
static __attribute__((always_inline)) inline int av_sat_dadd32_c(int a, int b)
{
return av_sat_add32_c(a, av_sat_add32_c(b, b));
}
static __attribute__((always_inline)) inline int av_sat_sub32_c(int a, int b)
{
return av_clipl_int32_c((int64_t)a - b);
}
static __attribute__((always_inline)) inline int av_sat_dsub32_c(int a, int b)
{
return av_sat_sub32_c(a, av_sat_add32_c(b, b));
}
static __attribute__((always_inline)) inline __attribute__((const)) float av_clipf_c(float a, float amin, float amax)
{
if (a < amin) return amin;
else if (a > amax) return amax;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) double av_clipd_c(double a, double amin, double amax)
{
if (a < amin) return amin;
else if (a > amax) return amax;
else return a;
}
static __attribute__((always_inline)) inline __attribute__((const)) int av_ceil_log2_c(int x)
{
return av_log2((x - 1) << 1);
}
static __attribute__((always_inline)) inline __attribute__((const)) int av_popcount_c(uint32_t x)
{
x -= (x >> 1) & 0x55555555;
x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
x = (x + (x >> 4)) & 0x0F0F0F0F;
x += x >> 8;
return (x + (x >> 16)) & 0x3F;
}
static __attribute__((always_inline)) inline __attribute__((const)) int av_popcount64_c(uint64_t x)
{
return av_popcount_c((uint32_t)x) + av_popcount_c((uint32_t)(x >> 32));
}
static __attribute__((always_inline)) inline __attribute__((const)) int av_parity_c(uint32_t v)
{
return av_popcount_c(v) & 1;
}
int av_strerror(int errnum, char *errbuf, size_t errbuf_size);
static inline char *av_make_error_string(char *errbuf, size_t errbuf_size, int errnum)
{
av_strerror(errnum, errbuf, errbuf_size);
return errbuf;
}
void *av_malloc(size_t size) __attribute__((__malloc__)) __attribute__((alloc_size(1)));
void *av_mallocz(size_t size) __attribute__((__malloc__)) __attribute__((alloc_size(1)));
__attribute__((alloc_size(1, 2))) void *av_malloc_array(size_t nmemb, size_t size);
__attribute__((alloc_size(1, 2))) void *av_mallocz_array(size_t nmemb, size_t size);
void *av_calloc(size_t nmemb, size_t size) __attribute__((__malloc__));
void *av_realloc(void *ptr, size_t size) __attribute__((alloc_size(2)));
__attribute__((warn_unused_result))
int av_reallocp(void *ptr, size_t size);
void *av_realloc_f(void *ptr, size_t nelem, size_t elsize);
__attribute__((alloc_size(2, 3))) void *av_realloc_array(void *ptr, size_t nmemb, size_t size);
__attribute__((alloc_size(2, 3))) int av_reallocp_array(void *ptr, size_t nmemb, size_t size);
void *av_fast_realloc(void *ptr, unsigned int *size, size_t min_size);
void av_fast_malloc(void *ptr, unsigned int *size, size_t min_size);
void av_fast_mallocz(void *ptr, unsigned int *size, size_t min_size);
void av_free(void *ptr);
void av_freep(void *ptr);
char *av_strdup(const char *s) __attribute__((__malloc__));
char *av_strndup(const char *s, size_t len) __attribute__((__malloc__));
void *av_memdup(const void *p, size_t size);
void av_memcpy_backptr(uint8_t *dst, int back, int cnt);
void av_dynarray_add(void *tab_ptr, int *nb_ptr, void *elem);
__attribute__((warn_unused_result))
int av_dynarray_add_nofree(void *tab_ptr, int *nb_ptr, void *elem);
void *av_dynarray2_add(void **tab_ptr, int *nb_ptr, size_t elem_size,
const uint8_t *elem_data);
static inline int av_size_mult(size_t a, size_t b, size_t *r)
{
size_t t = a * b;
if ((a | b) >= ((size_t)1 << (sizeof(size_t) * 4)) && a && t / a != b)
return (-(
22
));
*r = t;
return 0;
}
void av_max_alloc(size_t max);
typedef struct AVRational{
int num;
int den;
} AVRational;
static inline AVRational av_make_q(int num, int den)
{
AVRational r = { num, den };
return r;
}
static inline int av_cmp_q(AVRational a, AVRational b){
const int64_t tmp= a.num * (int64_t)b.den - b.num * (int64_t)a.den;
if(tmp) return (int)((tmp ^ a.den ^ b.den)>>63)|1;
else if(b.den && a.den) return 0;
else if(a.num && b.num) return (a.num>>31) - (b.num>>31);
else return
(-0x7fffffff -1)
;
}
static inline double av_q2d(AVRational a){
return a.num / (double) a.den;
}
int av_reduce(int *dst_num, int *dst_den, int64_t num, int64_t den, int64_t max);
AVRational av_mul_q(AVRational b, AVRational c) __attribute__((const));
AVRational av_div_q(AVRational b, AVRational c) __attribute__((const));
AVRational av_add_q(AVRational b, AVRational c) __attribute__((const));
AVRational av_sub_q(AVRational b, AVRational c) __attribute__((const));
static __attribute__((always_inline)) inline AVRational av_inv_q(AVRational q)
{
AVRational r = { q.den, q.num };
return r;
}
AVRational av_d2q(double d, int max) __attribute__((const));
int av_nearer_q(AVRational q, AVRational q1, AVRational q2);
int av_find_nearest_q_idx(AVRational q, const AVRational* q_list);
uint32_t av_q2intfloat(AVRational q);
union av_intfloat32 {
uint32_t i;
float f;
};
union av_intfloat64 {
uint64_t i;
double f;
};
static __attribute__((always_inline)) inline float av_int2float(uint32_t i)
{
union av_intfloat32 v;
v.i = i;
return v.f;
}
static __attribute__((always_inline)) inline uint32_t av_float2int(float f)
{
union av_intfloat32 v;
v.f = f;
return v.i;
}
static __attribute__((always_inline)) inline double av_int2double(uint64_t i)
{
union av_intfloat64 v;
v.i = i;
return v.f;
}
static __attribute__((always_inline)) inline uint64_t av_double2int(double f)
{
union av_intfloat64 v;
v.f = f;
return v.i;
}
enum AVRounding {
AV_ROUND_ZERO = 0,
AV_ROUND_INF = 1,
AV_ROUND_DOWN = 2,
AV_ROUND_UP = 3,
AV_ROUND_NEAR_INF = 5,
AV_ROUND_PASS_MINMAX = 8192,
};
int64_t __attribute__((const)) av_gcd(int64_t a, int64_t b);
int64_t av_rescale(int64_t a, int64_t b, int64_t c) __attribute__((const));
int64_t av_rescale_rnd(int64_t a, int64_t b, int64_t c, enum AVRounding rnd) __attribute__((const));
int64_t av_rescale_q(int64_t a, AVRational bq, AVRational cq) __attribute__((const));
int64_t av_rescale_q_rnd(int64_t a, AVRational bq, AVRational cq,
enum AVRounding rnd) __attribute__((const));
int av_compare_ts(int64_t ts_a, AVRational tb_a, int64_t ts_b, AVRational tb_b);
int64_t av_compare_mod(uint64_t a, uint64_t b, uint64_t mod);
int64_t av_rescale_delta(AVRational in_tb, int64_t in_ts, AVRational fs_tb, int duration, int64_t *last, AVRational out_tb);
int64_t av_add_stable(AVRational ts_tb, int64_t ts, AVRational inc_tb, int64_t inc);
typedef enum {
AV_CLASS_CATEGORY_NA = 0,
AV_CLASS_CATEGORY_INPUT,
AV_CLASS_CATEGORY_OUTPUT,
AV_CLASS_CATEGORY_MUXER,
AV_CLASS_CATEGORY_DEMUXER,
AV_CLASS_CATEGORY_ENCODER,
AV_CLASS_CATEGORY_DECODER,
AV_CLASS_CATEGORY_FILTER,
AV_CLASS_CATEGORY_BITSTREAM_FILTER,
AV_CLASS_CATEGORY_SWSCALER,
AV_CLASS_CATEGORY_SWRESAMPLER,
AV_CLASS_CATEGORY_DEVICE_VIDEO_OUTPUT = 40,
AV_CLASS_CATEGORY_DEVICE_VIDEO_INPUT,
AV_CLASS_CATEGORY_DEVICE_AUDIO_OUTPUT,
AV_CLASS_CATEGORY_DEVICE_AUDIO_INPUT,
AV_CLASS_CATEGORY_DEVICE_OUTPUT,
AV_CLASS_CATEGORY_DEVICE_INPUT,
AV_CLASS_CATEGORY_NB
}AVClassCategory;
struct AVOptionRanges;
typedef struct AVClass {
const char* class_name;
const char* (*item_name)(void* ctx);
const struct AVOption *option;
int version;
int log_level_offset_offset;
int parent_log_context_offset;
void* (*child_next)(void *obj, void *prev);
const struct AVClass* (*child_class_next)(const struct AVClass *prev);
AVClassCategory category;
AVClassCategory (*get_category)(void* ctx);
int (*query_ranges)(struct AVOptionRanges **, void *obj, const char *key, int flags);
} AVClass;
void av_log(void *avcl, int level, const char *fmt, ...) __attribute__((__format__(__printf__, 3, 4)));
void av_vlog(void *avcl, int level, const char *fmt, va_list vl);
int av_log_get_level(void);
void av_log_set_level(int level);
void av_log_set_callback(void (*callback)(void*, int, const char*, va_list));
void av_log_default_callback(void *avcl, int level, const char *fmt,
va_list vl);
const char* av_default_item_name(void* ctx);
AVClassCategory av_default_get_category(void *ptr);
void av_log_format_line(void *ptr, int level, const char *fmt, va_list vl,
char *line, int line_size, int *print_prefix);
int av_log_format_line2(void *ptr, int level, const char *fmt, va_list vl,
char *line, int line_size, int *print_prefix);
void av_log_set_flags(int arg);
int av_log_get_flags(void);
enum AVPixelFormat {
AV_PIX_FMT_NONE = -1,
AV_PIX_FMT_YUV420P,
AV_PIX_FMT_YUYV422,
AV_PIX_FMT_RGB24,
AV_PIX_FMT_BGR24,
AV_PIX_FMT_YUV422P,
AV_PIX_FMT_YUV444P,
AV_PIX_FMT_YUV410P,
AV_PIX_FMT_YUV411P,
AV_PIX_FMT_GRAY8,
AV_PIX_FMT_MONOWHITE,
AV_PIX_FMT_MONOBLACK,
AV_PIX_FMT_PAL8,
AV_PIX_FMT_YUVJ420P,
AV_PIX_FMT_YUVJ422P,
AV_PIX_FMT_YUVJ444P,
AV_PIX_FMT_UYVY422,
AV_PIX_FMT_UYYVYY411,
AV_PIX_FMT_BGR8,
AV_PIX_FMT_BGR4,
AV_PIX_FMT_BGR4_BYTE,
AV_PIX_FMT_RGB8,
AV_PIX_FMT_RGB4,
AV_PIX_FMT_RGB4_BYTE,
AV_PIX_FMT_NV12,
AV_PIX_FMT_NV21,
AV_PIX_FMT_ARGB,
AV_PIX_FMT_RGBA,
AV_PIX_FMT_ABGR,
AV_PIX_FMT_BGRA,
AV_PIX_FMT_GRAY16BE,
AV_PIX_FMT_GRAY16LE,
AV_PIX_FMT_YUV440P,
AV_PIX_FMT_YUVJ440P,
AV_PIX_FMT_YUVA420P,
AV_PIX_FMT_RGB48BE,
AV_PIX_FMT_RGB48LE,
AV_PIX_FMT_RGB565BE,
AV_PIX_FMT_RGB565LE,
AV_PIX_FMT_RGB555BE,
AV_PIX_FMT_RGB555LE,
AV_PIX_FMT_BGR565BE,
AV_PIX_FMT_BGR565LE,
AV_PIX_FMT_BGR555BE,
AV_PIX_FMT_BGR555LE,
AV_PIX_FMT_VAAPI_MOCO,
AV_PIX_FMT_VAAPI_IDCT,
AV_PIX_FMT_VAAPI_VLD,
AV_PIX_FMT_VAAPI = AV_PIX_FMT_VAAPI_VLD,
AV_PIX_FMT_YUV420P16LE,
AV_PIX_FMT_YUV420P16BE,
AV_PIX_FMT_YUV422P16LE,
AV_PIX_FMT_YUV422P16BE,
AV_PIX_FMT_YUV444P16LE,
AV_PIX_FMT_YUV444P16BE,
AV_PIX_FMT_DXVA2_VLD,
AV_PIX_FMT_RGB444LE,
AV_PIX_FMT_RGB444BE,
AV_PIX_FMT_BGR444LE,
AV_PIX_FMT_BGR444BE,
AV_PIX_FMT_YA8,
AV_PIX_FMT_Y400A = AV_PIX_FMT_YA8,
AV_PIX_FMT_GRAY8A= AV_PIX_FMT_YA8,
AV_PIX_FMT_BGR48BE,
AV_PIX_FMT_BGR48LE,
AV_PIX_FMT_YUV420P9BE,
AV_PIX_FMT_YUV420P9LE,
AV_PIX_FMT_YUV420P10BE,
AV_PIX_FMT_YUV420P10LE,
AV_PIX_FMT_YUV422P10BE,
AV_PIX_FMT_YUV422P10LE,
AV_PIX_FMT_YUV444P9BE,
AV_PIX_FMT_YUV444P9LE,
AV_PIX_FMT_YUV444P10BE,
AV_PIX_FMT_YUV444P10LE,
AV_PIX_FMT_YUV422P9BE,
AV_PIX_FMT_YUV422P9LE,
AV_PIX_FMT_GBRP,
AV_PIX_FMT_GBR24P = AV_PIX_FMT_GBRP,
AV_PIX_FMT_GBRP9BE,
AV_PIX_FMT_GBRP9LE,
AV_PIX_FMT_GBRP10BE,
AV_PIX_FMT_GBRP10LE,
AV_PIX_FMT_GBRP16BE,
AV_PIX_FMT_GBRP16LE,
AV_PIX_FMT_YUVA422P,
AV_PIX_FMT_YUVA444P,
AV_PIX_FMT_YUVA420P9BE,
AV_PIX_FMT_YUVA420P9LE,
AV_PIX_FMT_YUVA422P9BE,
AV_PIX_FMT_YUVA422P9LE,
AV_PIX_FMT_YUVA444P9BE,
AV_PIX_FMT_YUVA444P9LE,
AV_PIX_FMT_YUVA420P10BE,
AV_PIX_FMT_YUVA420P10LE,
AV_PIX_FMT_YUVA422P10BE,
AV_PIX_FMT_YUVA422P10LE,
AV_PIX_FMT_YUVA444P10BE,
AV_PIX_FMT_YUVA444P10LE,
AV_PIX_FMT_YUVA420P16BE,
AV_PIX_FMT_YUVA420P16LE,
AV_PIX_FMT_YUVA422P16BE,
AV_PIX_FMT_YUVA422P16LE,
AV_PIX_FMT_YUVA444P16BE,
AV_PIX_FMT_YUVA444P16LE,
AV_PIX_FMT_VDPAU,
AV_PIX_FMT_XYZ12LE,
AV_PIX_FMT_XYZ12BE,
AV_PIX_FMT_NV16,
AV_PIX_FMT_NV20LE,
AV_PIX_FMT_NV20BE,
AV_PIX_FMT_RGBA64BE,
AV_PIX_FMT_RGBA64LE,
AV_PIX_FMT_BGRA64BE,
AV_PIX_FMT_BGRA64LE,
AV_PIX_FMT_YVYU422,
AV_PIX_FMT_YA16BE,
AV_PIX_FMT_YA16LE,
AV_PIX_FMT_GBRAP,
AV_PIX_FMT_GBRAP16BE,
AV_PIX_FMT_GBRAP16LE,
AV_PIX_FMT_QSV,
AV_PIX_FMT_MMAL,
AV_PIX_FMT_D3D11VA_VLD,
AV_PIX_FMT_CUDA,
AV_PIX_FMT_0RGB,
AV_PIX_FMT_RGB0,
AV_PIX_FMT_0BGR,
AV_PIX_FMT_BGR0,
AV_PIX_FMT_YUV420P12BE,
AV_PIX_FMT_YUV420P12LE,
AV_PIX_FMT_YUV420P14BE,
AV_PIX_FMT_YUV420P14LE,
AV_PIX_FMT_YUV422P12BE,
AV_PIX_FMT_YUV422P12LE,
AV_PIX_FMT_YUV422P14BE,
AV_PIX_FMT_YUV422P14LE,
AV_PIX_FMT_YUV444P12BE,
AV_PIX_FMT_YUV444P12LE,
AV_PIX_FMT_YUV444P14BE,
AV_PIX_FMT_YUV444P14LE,
AV_PIX_FMT_GBRP12BE,
AV_PIX_FMT_GBRP12LE,
AV_PIX_FMT_GBRP14BE,
AV_PIX_FMT_GBRP14LE,
AV_PIX_FMT_YUVJ411P,
AV_PIX_FMT_BAYER_BGGR8,
AV_PIX_FMT_BAYER_RGGB8,
AV_PIX_FMT_BAYER_GBRG8,
AV_PIX_FMT_BAYER_GRBG8,
AV_PIX_FMT_BAYER_BGGR16LE,
AV_PIX_FMT_BAYER_BGGR16BE,
AV_PIX_FMT_BAYER_RGGB16LE,
AV_PIX_FMT_BAYER_RGGB16BE,
AV_PIX_FMT_BAYER_GBRG16LE,
AV_PIX_FMT_BAYER_GBRG16BE,
AV_PIX_FMT_BAYER_GRBG16LE,
AV_PIX_FMT_BAYER_GRBG16BE,
AV_PIX_FMT_XVMC,
AV_PIX_FMT_YUV440P10LE,
AV_PIX_FMT_YUV440P10BE,
AV_PIX_FMT_YUV440P12LE,
AV_PIX_FMT_YUV440P12BE,
AV_PIX_FMT_AYUV64LE,
AV_PIX_FMT_AYUV64BE,
AV_PIX_FMT_VIDEOTOOLBOX,
AV_PIX_FMT_P010LE,
AV_PIX_FMT_P010BE,
AV_PIX_FMT_GBRAP12BE,
AV_PIX_FMT_GBRAP12LE,
AV_PIX_FMT_GBRAP10BE,
AV_PIX_FMT_GBRAP10LE,
AV_PIX_FMT_MEDIACODEC,
AV_PIX_FMT_GRAY12BE,
AV_PIX_FMT_GRAY12LE,
AV_PIX_FMT_GRAY10BE,
AV_PIX_FMT_GRAY10LE,
AV_PIX_FMT_P016LE,
AV_PIX_FMT_P016BE,
AV_PIX_FMT_D3D11,
AV_PIX_FMT_GRAY9BE,
AV_PIX_FMT_GRAY9LE,
AV_PIX_FMT_GBRPF32BE,
AV_PIX_FMT_GBRPF32LE,
AV_PIX_FMT_GBRAPF32BE,
AV_PIX_FMT_GBRAPF32LE,
AV_PIX_FMT_DRM_PRIME,
AV_PIX_FMT_OPENCL,
AV_PIX_FMT_GRAY14BE,
AV_PIX_FMT_GRAY14LE,
AV_PIX_FMT_GRAYF32BE,
AV_PIX_FMT_GRAYF32LE,
AV_PIX_FMT_NB
};
enum AVColorPrimaries {
AVCOL_PRI_RESERVED0 = 0,
AVCOL_PRI_BT709 = 1,
AVCOL_PRI_UNSPECIFIED = 2,
AVCOL_PRI_RESERVED = 3,
AVCOL_PRI_BT470M = 4,
AVCOL_PRI_BT470BG = 5,
AVCOL_PRI_SMPTE170M = 6,
AVCOL_PRI_SMPTE240M = 7,
AVCOL_PRI_FILM = 8,
AVCOL_PRI_BT2020 = 9,
AVCOL_PRI_SMPTE428 = 10,
AVCOL_PRI_SMPTEST428_1 = AVCOL_PRI_SMPTE428,
AVCOL_PRI_SMPTE431 = 11,
AVCOL_PRI_SMPTE432 = 12,
AVCOL_PRI_JEDEC_P22 = 22,
AVCOL_PRI_NB
};
enum AVColorTransferCharacteristic {
AVCOL_TRC_RESERVED0 = 0,
AVCOL_TRC_BT709 = 1,
AVCOL_TRC_UNSPECIFIED = 2,
AVCOL_TRC_RESERVED = 3,
AVCOL_TRC_GAMMA22 = 4,
AVCOL_TRC_GAMMA28 = 5,
AVCOL_TRC_SMPTE170M = 6,
AVCOL_TRC_SMPTE240M = 7,
AVCOL_TRC_LINEAR = 8,
AVCOL_TRC_LOG = 9,
AVCOL_TRC_LOG_SQRT = 10,
AVCOL_TRC_IEC61966_2_4 = 11,
AVCOL_TRC_BT1361_ECG = 12,
AVCOL_TRC_IEC61966_2_1 = 13,
AVCOL_TRC_BT2020_10 = 14,
AVCOL_TRC_BT2020_12 = 15,
AVCOL_TRC_SMPTE2084 = 16,
AVCOL_TRC_SMPTEST2084 = AVCOL_TRC_SMPTE2084,
AVCOL_TRC_SMPTE428 = 17,
AVCOL_TRC_SMPTEST428_1 = AVCOL_TRC_SMPTE428,
AVCOL_TRC_ARIB_STD_B67 = 18,
AVCOL_TRC_NB
};
enum AVColorSpace {
AVCOL_SPC_RGB = 0,
AVCOL_SPC_BT709 = 1,
AVCOL_SPC_UNSPECIFIED = 2,
AVCOL_SPC_RESERVED = 3,
AVCOL_SPC_FCC = 4,
AVCOL_SPC_BT470BG = 5,
AVCOL_SPC_SMPTE170M = 6,
AVCOL_SPC_SMPTE240M = 7,
AVCOL_SPC_YCGCO = 8,
AVCOL_SPC_YCOCG = AVCOL_SPC_YCGCO,
AVCOL_SPC_BT2020_NCL = 9,
AVCOL_SPC_BT2020_CL = 10,
AVCOL_SPC_SMPTE2085 = 11,
AVCOL_SPC_CHROMA_DERIVED_NCL = 12,
AVCOL_SPC_CHROMA_DERIVED_CL = 13,
AVCOL_SPC_ICTCP = 14,
AVCOL_SPC_NB
};
enum AVColorRange {
AVCOL_RANGE_UNSPECIFIED = 0,
AVCOL_RANGE_MPEG = 1,
AVCOL_RANGE_JPEG = 2,
AVCOL_RANGE_NB
};
enum AVChromaLocation {
AVCHROMA_LOC_UNSPECIFIED = 0,
AVCHROMA_LOC_LEFT = 1,
AVCHROMA_LOC_CENTER = 2,
AVCHROMA_LOC_TOPLEFT = 3,
AVCHROMA_LOC_TOP = 4,
AVCHROMA_LOC_BOTTOMLEFT = 5,
AVCHROMA_LOC_BOTTOM = 6,
AVCHROMA_LOC_NB
};
static inline void *av_x_if_null(const void *p, const void *x)
{
return (void *)(intptr_t)(p ? p : x);
}
unsigned av_int_list_length_for_size(unsigned elsize,
const void *list, uint64_t term) __attribute__((pure));
FILE *av_fopen_utf8(const char *path, const char *mode);
AVRational av_get_time_base_q(void);
char *av_fourcc_make_string(char *buf, uint32_t fourcc);
enum AVSampleFormat {
AV_SAMPLE_FMT_NONE = -1,
AV_SAMPLE_FMT_U8,
AV_SAMPLE_FMT_S16,
AV_SAMPLE_FMT_S32,
AV_SAMPLE_FMT_FLT,
AV_SAMPLE_FMT_DBL,
AV_SAMPLE_FMT_U8P,
AV_SAMPLE_FMT_S16P,
AV_SAMPLE_FMT_S32P,
AV_SAMPLE_FMT_FLTP,
AV_SAMPLE_FMT_DBLP,
AV_SAMPLE_FMT_S64,
AV_SAMPLE_FMT_S64P,
AV_SAMPLE_FMT_NB
};
const char *av_get_sample_fmt_name(enum AVSampleFormat sample_fmt);
enum AVSampleFormat av_get_sample_fmt(const char *name);
enum AVSampleFormat av_get_alt_sample_fmt(enum AVSampleFormat sample_fmt, int planar);
enum AVSampleFormat av_get_packed_sample_fmt(enum AVSampleFormat sample_fmt);
enum AVSampleFormat av_get_planar_sample_fmt(enum AVSampleFormat sample_fmt);
char *av_get_sample_fmt_string(char *buf, int buf_size, enum AVSampleFormat sample_fmt);
int av_get_bytes_per_sample(enum AVSampleFormat sample_fmt);
int av_sample_fmt_is_planar(enum AVSampleFormat sample_fmt);
int av_samples_get_buffer_size(int *linesize, int nb_channels, int nb_samples,
enum AVSampleFormat sample_fmt, int align);
int av_samples_fill_arrays(uint8_t **audio_data, int *linesize,
const uint8_t *buf,
int nb_channels, int nb_samples,
enum AVSampleFormat sample_fmt, int align);
int av_samples_alloc(uint8_t **audio_data, int *linesize, int nb_channels,
int nb_samples, enum AVSampleFormat sample_fmt, int align);
int av_samples_alloc_array_and_samples(uint8_t ***audio_data, int *linesize, int nb_channels,
int nb_samples, enum AVSampleFormat sample_fmt, int align);
int av_samples_copy(uint8_t **dst, uint8_t * const *src, int dst_offset,
int src_offset, int nb_samples, int nb_channels,
enum AVSampleFormat sample_fmt);
int av_samples_set_silence(uint8_t **audio_data, int offset, int nb_samples,
int nb_channels, enum AVSampleFormat sample_fmt);
typedef struct AVBuffer AVBuffer;
typedef struct AVBufferRef {
AVBuffer *buffer;
uint8_t *data;
int size;
} AVBufferRef;
AVBufferRef *av_buffer_alloc(int size);
AVBufferRef *av_buffer_allocz(int size);
AVBufferRef *av_buffer_create(uint8_t *data, int size,
void (*free)(void *opaque, uint8_t *data),
void *opaque, int flags);
void av_buffer_default_free(void *opaque, uint8_t *data);
AVBufferRef *av_buffer_ref(AVBufferRef *buf);
void av_buffer_unref(AVBufferRef **buf);
int av_buffer_is_writable(const AVBufferRef *buf);
void *av_buffer_get_opaque(const AVBufferRef *buf);
int av_buffer_get_ref_count(const AVBufferRef *buf);
int av_buffer_make_writable(AVBufferRef **buf);
int av_buffer_realloc(AVBufferRef **buf, int size);
typedef struct AVBufferPool AVBufferPool;
AVBufferPool *av_buffer_pool_init(int size, AVBufferRef* (*alloc)(int size));
AVBufferPool *av_buffer_pool_init2(int size, void *opaque,
AVBufferRef* (*alloc)(void *opaque, int size),
void (*pool_free)(void *opaque));
void av_buffer_pool_uninit(AVBufferPool **pool);
AVBufferRef *av_buffer_pool_get(AVBufferPool *pool);
int av_get_cpu_flags(void);
void av_force_cpu_flags(int flags);
__attribute__((deprecated)) void av_set_cpu_flags_mask(int mask);
__attribute__((deprecated))
int av_parse_cpu_flags(const char *s);
int av_parse_cpu_caps(unsigned *flags, const char *s);
int av_cpu_count(void);
size_t av_cpu_max_align(void);
enum AVMatrixEncoding {
AV_MATRIX_ENCODING_NONE,
AV_MATRIX_ENCODING_DOLBY,
AV_MATRIX_ENCODING_DPLII,
AV_MATRIX_ENCODING_DPLIIX,
AV_MATRIX_ENCODING_DPLIIZ,
AV_MATRIX_ENCODING_DOLBYEX,
AV_MATRIX_ENCODING_DOLBYHEADPHONE,
AV_MATRIX_ENCODING_NB
};
uint64_t av_get_channel_layout(const char *name);
int av_get_extended_channel_layout(const char *name, uint64_t* channel_layout, int* nb_channels);
void av_get_channel_layout_string(char *buf, int buf_size, int nb_channels, uint64_t channel_layout);
struct AVBPrint;
void av_bprint_channel_layout(struct AVBPrint *bp, int nb_channels, uint64_t channel_layout);
int av_get_channel_layout_nb_channels(uint64_t channel_layout);
int64_t av_get_default_channel_layout(int nb_channels);
int av_get_channel_layout_channel_index(uint64_t channel_layout,
uint64_t channel);
uint64_t av_channel_layout_extract_channel(uint64_t channel_layout, int index);
const char *av_get_channel_name(uint64_t channel);
const char *av_get_channel_description(uint64_t channel);
int av_get_standard_channel_layout(unsigned index, uint64_t *layout,
const char **name);
typedef struct AVDictionaryEntry {
char *key;
char *value;
} AVDictionaryEntry;
typedef struct AVDictionary AVDictionary;
AVDictionaryEntry *av_dict_get(const AVDictionary *m, const char *key,
const AVDictionaryEntry *prev, int flags);
int av_dict_count(const AVDictionary *m);
int av_dict_set(AVDictionary **pm, const char *key, const char *value, int flags);
int av_dict_set_int(AVDictionary **pm, const char *key, int64_t value, int flags);
int av_dict_parse_string(AVDictionary **pm, const char *str,
const char *key_val_sep, const char *pairs_sep,
int flags);
int av_dict_copy(AVDictionary **dst, const AVDictionary *src, int flags);
void av_dict_free(AVDictionary **m);
int av_dict_get_string(const AVDictionary *m, char **buffer,
const char key_val_sep, const char pairs_sep);
enum AVFrameSideDataType {
AV_FRAME_DATA_PANSCAN,
AV_FRAME_DATA_A53_CC,
AV_FRAME_DATA_STEREO3D,
AV_FRAME_DATA_MATRIXENCODING,
AV_FRAME_DATA_DOWNMIX_INFO,
AV_FRAME_DATA_REPLAYGAIN,
AV_FRAME_DATA_DISPLAYMATRIX,
AV_FRAME_DATA_AFD,
AV_FRAME_DATA_MOTION_VECTORS,
AV_FRAME_DATA_SKIP_SAMPLES,
AV_FRAME_DATA_AUDIO_SERVICE_TYPE,
AV_FRAME_DATA_MASTERING_DISPLAY_METADATA,
AV_FRAME_DATA_GOP_TIMECODE,
AV_FRAME_DATA_SPHERICAL,
AV_FRAME_DATA_CONTENT_LIGHT_LEVEL,
AV_FRAME_DATA_ICC_PROFILE,
AV_FRAME_DATA_QP_TABLE_PROPERTIES,
AV_FRAME_DATA_QP_TABLE_DATA,
AV_FRAME_DATA_S12M_TIMECODE,
};
enum AVActiveFormatDescription {
AV_AFD_SAME = 8,
AV_AFD_4_3 = 9,
AV_AFD_16_9 = 10,
AV_AFD_14_9 = 11,
AV_AFD_4_3_SP_14_9 = 13,
AV_AFD_16_9_SP_14_9 = 14,
AV_AFD_SP_4_3 = 15,
};
typedef struct AVFrameSideData {
enum AVFrameSideDataType type;
uint8_t *data;
int size;
AVDictionary *metadata;
AVBufferRef *buf;
} AVFrameSideData;
typedef struct AVFrame {
uint8_t *data[8];
int linesize[8];
uint8_t **extended_data;
int width, height;
int nb_samples;
int format;
int key_frame;
enum AVPictureType pict_type;
AVRational sample_aspect_ratio;
int64_t pts;
__attribute__((deprecated))
int64_t pkt_pts;
int64_t pkt_dts;
int coded_picture_number;
int display_picture_number;
int quality;
void *opaque;
__attribute__((deprecated))
uint64_t error[8];
int repeat_pict;
int interlaced_frame;
int top_field_first;
int palette_has_changed;
int64_t reordered_opaque;
int sample_rate;
uint64_t channel_layout;
AVBufferRef *buf[8];
AVBufferRef **extended_buf;
int nb_extended_buf;
AVFrameSideData **side_data;
int nb_side_data;
int flags;
enum AVColorRange color_range;
enum AVColorPrimaries color_primaries;
enum AVColorTransferCharacteristic color_trc;
enum AVColorSpace colorspace;
enum AVChromaLocation chroma_location;
int64_t best_effort_timestamp;
int64_t pkt_pos;
int64_t pkt_duration;
AVDictionary *metadata;
int decode_error_flags;
int channels;
int pkt_size;
__attribute__((deprecated))
int8_t *qscale_table;
__attribute__((deprecated))
int qstride;
__attribute__((deprecated))
int qscale_type;
__attribute__((deprecated))
AVBufferRef *qp_table_buf;
AVBufferRef *hw_frames_ctx;
AVBufferRef *opaque_ref;
size_t crop_top;
size_t crop_bottom;
size_t crop_left;
size_t crop_right;
AVBufferRef *private_ref;
} AVFrame;
__attribute__((deprecated))
int64_t av_frame_get_best_effort_timestamp(const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_best_effort_timestamp(AVFrame *frame, int64_t val);
__attribute__((deprecated))
int64_t av_frame_get_pkt_duration (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_pkt_duration (AVFrame *frame, int64_t val);
__attribute__((deprecated))
int64_t av_frame_get_pkt_pos (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_pkt_pos (AVFrame *frame, int64_t val);
__attribute__((deprecated))
int64_t av_frame_get_channel_layout (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_channel_layout (AVFrame *frame, int64_t val);
__attribute__((deprecated))
int av_frame_get_channels (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_channels (AVFrame *frame, int val);
__attribute__((deprecated))
int av_frame_get_sample_rate (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_sample_rate (AVFrame *frame, int val);
__attribute__((deprecated))
AVDictionary *av_frame_get_metadata (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_metadata (AVFrame *frame, AVDictionary *val);
__attribute__((deprecated))
int av_frame_get_decode_error_flags (const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_decode_error_flags (AVFrame *frame, int val);
__attribute__((deprecated))
int av_frame_get_pkt_size(const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_pkt_size(AVFrame *frame, int val);
__attribute__((deprecated))
int8_t *av_frame_get_qp_table(AVFrame *f, int *stride, int *type);
__attribute__((deprecated))
int av_frame_set_qp_table(AVFrame *f, AVBufferRef *buf, int stride, int type);
__attribute__((deprecated))
enum AVColorSpace av_frame_get_colorspace(const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_colorspace(AVFrame *frame, enum AVColorSpace val);
__attribute__((deprecated))
enum AVColorRange av_frame_get_color_range(const AVFrame *frame);
__attribute__((deprecated))
void av_frame_set_color_range(AVFrame *frame, enum AVColorRange val);
const char *av_get_colorspace_name(enum AVColorSpace val);
AVFrame *av_frame_alloc(void);
void av_frame_free(AVFrame **frame);
int av_frame_ref(AVFrame *dst, const AVFrame *src);
AVFrame *av_frame_clone(const AVFrame *src);
void av_frame_unref(AVFrame *frame);
void av_frame_move_ref(AVFrame *dst, AVFrame *src);
int av_frame_get_buffer(AVFrame *frame, int align);
int av_frame_is_writable(AVFrame *frame);
int av_frame_make_writable(AVFrame *frame);
int av_frame_copy(AVFrame *dst, const AVFrame *src);
int av_frame_copy_props(AVFrame *dst, const AVFrame *src);
AVBufferRef *av_frame_get_plane_buffer(AVFrame *frame, int plane);
AVFrameSideData *av_frame_new_side_data(AVFrame *frame,
enum AVFrameSideDataType type,
int size);
AVFrameSideData *av_frame_new_side_data_from_buf(AVFrame *frame,
enum AVFrameSideDataType type,
AVBufferRef *buf);
AVFrameSideData *av_frame_get_side_data(const AVFrame *frame,
enum AVFrameSideDataType type);
void av_frame_remove_side_data(AVFrame *frame, enum AVFrameSideDataType type);
enum {
AV_FRAME_CROP_UNALIGNED = 1 << 0,
};
int av_frame_apply_cropping(AVFrame *frame, int flags);
const char *av_frame_side_data_name(enum AVFrameSideDataType type);
enum AVHWDeviceType {
AV_HWDEVICE_TYPE_NONE,
AV_HWDEVICE_TYPE_VDPAU,
AV_HWDEVICE_TYPE_CUDA,
AV_HWDEVICE_TYPE_VAAPI,
AV_HWDEVICE_TYPE_DXVA2,
AV_HWDEVICE_TYPE_QSV,
AV_HWDEVICE_TYPE_VIDEOTOOLBOX,
AV_HWDEVICE_TYPE_D3D11VA,
AV_HWDEVICE_TYPE_DRM,
AV_HWDEVICE_TYPE_OPENCL,
AV_HWDEVICE_TYPE_MEDIACODEC,
};
typedef struct AVHWDeviceInternal AVHWDeviceInternal;
typedef struct AVHWDeviceContext {
const AVClass *av_class;
AVHWDeviceInternal *internal;
enum AVHWDeviceType type;
void *hwctx;
void (*free)(struct AVHWDeviceContext *ctx);
void *user_opaque;
} AVHWDeviceContext;
typedef struct AVHWFramesInternal AVHWFramesInternal;
typedef struct AVHWFramesContext {
const AVClass *av_class;
AVHWFramesInternal *internal;
AVBufferRef *device_ref;
AVHWDeviceContext *device_ctx;
void *hwctx;
void (*free)(struct AVHWFramesContext *ctx);
void *user_opaque;
AVBufferPool *pool;
int initial_pool_size;
enum AVPixelFormat format;
enum AVPixelFormat sw_format;
int width, height;
} AVHWFramesContext;
enum AVHWDeviceType av_hwdevice_find_type_by_name(const char *name);
const char *av_hwdevice_get_type_name(enum AVHWDeviceType type);
enum AVHWDeviceType av_hwdevice_iterate_types(enum AVHWDeviceType prev);
AVBufferRef *av_hwdevice_ctx_alloc(enum AVHWDeviceType type);
int av_hwdevice_ctx_init(AVBufferRef *ref);
int av_hwdevice_ctx_create(AVBufferRef **device_ctx, enum AVHWDeviceType type,
const char *device, AVDictionary *opts, int flags);
int av_hwdevice_ctx_create_derived(AVBufferRef **dst_ctx,
enum AVHWDeviceType type,
AVBufferRef *src_ctx, int flags);
AVBufferRef *av_hwframe_ctx_alloc(AVBufferRef *device_ctx);
int av_hwframe_ctx_init(AVBufferRef *ref);
int av_hwframe_get_buffer(AVBufferRef *hwframe_ctx, AVFrame *frame, int flags);
int av_hwframe_transfer_data(AVFrame *dst, const AVFrame *src, int flags);
enum AVHWFrameTransferDirection {
AV_HWFRAME_TRANSFER_DIRECTION_FROM,
AV_HWFRAME_TRANSFER_DIRECTION_TO,
};
int av_hwframe_transfer_get_formats(AVBufferRef *hwframe_ctx,
enum AVHWFrameTransferDirection dir,
enum AVPixelFormat **formats, int flags);
typedef struct AVHWFramesConstraints {
enum AVPixelFormat *valid_hw_formats;
enum AVPixelFormat *valid_sw_formats;
int min_width;
int min_height;
int max_width;
int max_height;
} AVHWFramesConstraints;
void *av_hwdevice_hwconfig_alloc(AVBufferRef *device_ctx);
AVHWFramesConstraints *av_hwdevice_get_hwframe_constraints(AVBufferRef *ref,
const void *hwconfig);
void av_hwframe_constraints_free(AVHWFramesConstraints **constraints);
enum {
AV_HWFRAME_MAP_READ = 1 << 0,
AV_HWFRAME_MAP_WRITE = 1 << 1,
AV_HWFRAME_MAP_OVERWRITE = 1 << 2,
AV_HWFRAME_MAP_DIRECT = 1 << 3,
};
int av_hwframe_map(AVFrame *dst, const AVFrame *src, int flags);
int av_hwframe_ctx_create_derived(AVBufferRef **derived_frame_ctx,
enum AVPixelFormat format,
AVBufferRef *derived_device_ctx,
AVBufferRef *source_frame_ctx,
int flags);
enum AVCodecID {
AV_CODEC_ID_NONE,
AV_CODEC_ID_MPEG1VIDEO,
AV_CODEC_ID_MPEG2VIDEO,
AV_CODEC_ID_H261,
AV_CODEC_ID_H263,
AV_CODEC_ID_RV10,
AV_CODEC_ID_RV20,
AV_CODEC_ID_MJPEG,
AV_CODEC_ID_MJPEGB,
AV_CODEC_ID_LJPEG,
AV_CODEC_ID_SP5X,
AV_CODEC_ID_JPEGLS,
AV_CODEC_ID_MPEG4,
AV_CODEC_ID_RAWVIDEO,
AV_CODEC_ID_MSMPEG4V1,
AV_CODEC_ID_MSMPEG4V2,
AV_CODEC_ID_MSMPEG4V3,
AV_CODEC_ID_WMV1,
AV_CODEC_ID_WMV2,
AV_CODEC_ID_H263P,
AV_CODEC_ID_H263I,
AV_CODEC_ID_FLV1,
AV_CODEC_ID_SVQ1,
AV_CODEC_ID_SVQ3,
AV_CODEC_ID_DVVIDEO,
AV_CODEC_ID_HUFFYUV,
AV_CODEC_ID_CYUV,
AV_CODEC_ID_H264,
AV_CODEC_ID_INDEO3,
AV_CODEC_ID_VP3,
AV_CODEC_ID_THEORA,
AV_CODEC_ID_ASV1,
AV_CODEC_ID_ASV2,
AV_CODEC_ID_FFV1,
AV_CODEC_ID_4XM,
AV_CODEC_ID_VCR1,
AV_CODEC_ID_CLJR,
AV_CODEC_ID_MDEC,
AV_CODEC_ID_ROQ,
AV_CODEC_ID_INTERPLAY_VIDEO,
AV_CODEC_ID_XAN_WC3,
AV_CODEC_ID_XAN_WC4,
AV_CODEC_ID_RPZA,
AV_CODEC_ID_CINEPAK,
AV_CODEC_ID_WS_VQA,
AV_CODEC_ID_MSRLE,
AV_CODEC_ID_MSVIDEO1,
AV_CODEC_ID_IDCIN,
AV_CODEC_ID_8BPS,
AV_CODEC_ID_SMC,
AV_CODEC_ID_FLIC,
AV_CODEC_ID_TRUEMOTION1,
AV_CODEC_ID_VMDVIDEO,
AV_CODEC_ID_MSZH,
AV_CODEC_ID_ZLIB,
AV_CODEC_ID_QTRLE,
AV_CODEC_ID_TSCC,
AV_CODEC_ID_ULTI,
AV_CODEC_ID_QDRAW,
AV_CODEC_ID_VIXL,
AV_CODEC_ID_QPEG,
AV_CODEC_ID_PNG,
AV_CODEC_ID_PPM,
AV_CODEC_ID_PBM,
AV_CODEC_ID_PGM,
AV_CODEC_ID_PGMYUV,
AV_CODEC_ID_PAM,
AV_CODEC_ID_FFVHUFF,
AV_CODEC_ID_RV30,
AV_CODEC_ID_RV40,
AV_CODEC_ID_VC1,
AV_CODEC_ID_WMV3,
AV_CODEC_ID_LOCO,
AV_CODEC_ID_WNV1,
AV_CODEC_ID_AASC,
AV_CODEC_ID_INDEO2,
AV_CODEC_ID_FRAPS,
AV_CODEC_ID_TRUEMOTION2,
AV_CODEC_ID_BMP,
AV_CODEC_ID_CSCD,
AV_CODEC_ID_MMVIDEO,
AV_CODEC_ID_ZMBV,
AV_CODEC_ID_AVS,
AV_CODEC_ID_SMACKVIDEO,
AV_CODEC_ID_NUV,
AV_CODEC_ID_KMVC,
AV_CODEC_ID_FLASHSV,
AV_CODEC_ID_CAVS,
AV_CODEC_ID_JPEG2000,
AV_CODEC_ID_VMNC,
AV_CODEC_ID_VP5,
AV_CODEC_ID_VP6,
AV_CODEC_ID_VP6F,
AV_CODEC_ID_TARGA,
AV_CODEC_ID_DSICINVIDEO,
AV_CODEC_ID_TIERTEXSEQVIDEO,
AV_CODEC_ID_TIFF,
AV_CODEC_ID_GIF,
AV_CODEC_ID_DXA,
AV_CODEC_ID_DNXHD,
AV_CODEC_ID_THP,
AV_CODEC_ID_SGI,
AV_CODEC_ID_C93,
AV_CODEC_ID_BETHSOFTVID,
AV_CODEC_ID_PTX,
AV_CODEC_ID_TXD,
AV_CODEC_ID_VP6A,
AV_CODEC_ID_AMV,
AV_CODEC_ID_VB,
AV_CODEC_ID_PCX,
AV_CODEC_ID_SUNRAST,
AV_CODEC_ID_INDEO4,
AV_CODEC_ID_INDEO5,
AV_CODEC_ID_MIMIC,
AV_CODEC_ID_RL2,
AV_CODEC_ID_ESCAPE124,
AV_CODEC_ID_DIRAC,
AV_CODEC_ID_BFI,
AV_CODEC_ID_CMV,
AV_CODEC_ID_MOTIONPIXELS,
AV_CODEC_ID_TGV,
AV_CODEC_ID_TGQ,
AV_CODEC_ID_TQI,
AV_CODEC_ID_AURA,
AV_CODEC_ID_AURA2,
AV_CODEC_ID_V210X,
AV_CODEC_ID_TMV,
AV_CODEC_ID_V210,
AV_CODEC_ID_DPX,
AV_CODEC_ID_MAD,
AV_CODEC_ID_FRWU,
AV_CODEC_ID_FLASHSV2,
AV_CODEC_ID_CDGRAPHICS,
AV_CODEC_ID_R210,
AV_CODEC_ID_ANM,
AV_CODEC_ID_BINKVIDEO,
AV_CODEC_ID_IFF_ILBM,
AV_CODEC_ID_KGV1,
AV_CODEC_ID_YOP,
AV_CODEC_ID_VP8,
AV_CODEC_ID_PICTOR,
AV_CODEC_ID_ANSI,
AV_CODEC_ID_A64_MULTI,
AV_CODEC_ID_A64_MULTI5,
AV_CODEC_ID_R10K,
AV_CODEC_ID_MXPEG,
AV_CODEC_ID_LAGARITH,
AV_CODEC_ID_PRORES,
AV_CODEC_ID_JV,
AV_CODEC_ID_DFA,
AV_CODEC_ID_WMV3IMAGE,
AV_CODEC_ID_VC1IMAGE,
AV_CODEC_ID_UTVIDEO,
AV_CODEC_ID_BMV_VIDEO,
AV_CODEC_ID_VBLE,
AV_CODEC_ID_DXTORY,
AV_CODEC_ID_V410,
AV_CODEC_ID_XWD,
AV_CODEC_ID_CDXL,
AV_CODEC_ID_XBM,
AV_CODEC_ID_ZEROCODEC,
AV_CODEC_ID_MSS1,
AV_CODEC_ID_MSA1,
AV_CODEC_ID_TSCC2,
AV_CODEC_ID_MTS2,
AV_CODEC_ID_CLLC,
AV_CODEC_ID_MSS2,
AV_CODEC_ID_VP9,
AV_CODEC_ID_AIC,
AV_CODEC_ID_ESCAPE130,
AV_CODEC_ID_G2M,
AV_CODEC_ID_WEBP,
AV_CODEC_ID_HNM4_VIDEO,
AV_CODEC_ID_HEVC,
AV_CODEC_ID_FIC,
AV_CODEC_ID_ALIAS_PIX,
AV_CODEC_ID_BRENDER_PIX,
AV_CODEC_ID_PAF_VIDEO,
AV_CODEC_ID_EXR,
AV_CODEC_ID_VP7,
AV_CODEC_ID_SANM,
AV_CODEC_ID_SGIRLE,
AV_CODEC_ID_MVC1,
AV_CODEC_ID_MVC2,
AV_CODEC_ID_HQX,
AV_CODEC_ID_TDSC,
AV_CODEC_ID_HQ_HQA,
AV_CODEC_ID_HAP,
AV_CODEC_ID_DDS,
AV_CODEC_ID_DXV,
AV_CODEC_ID_SCREENPRESSO,
AV_CODEC_ID_RSCC,
AV_CODEC_ID_AVS2,
AV_CODEC_ID_Y41P = 0x8000,
AV_CODEC_ID_AVRP,
AV_CODEC_ID_012V,
AV_CODEC_ID_AVUI,
AV_CODEC_ID_AYUV,
AV_CODEC_ID_TARGA_Y216,
AV_CODEC_ID_V308,
AV_CODEC_ID_V408,
AV_CODEC_ID_YUV4,
AV_CODEC_ID_AVRN,
AV_CODEC_ID_CPIA,
AV_CODEC_ID_XFACE,
AV_CODEC_ID_SNOW,
AV_CODEC_ID_SMVJPEG,
AV_CODEC_ID_APNG,
AV_CODEC_ID_DAALA,
AV_CODEC_ID_CFHD,
AV_CODEC_ID_TRUEMOTION2RT,
AV_CODEC_ID_M101,
AV_CODEC_ID_MAGICYUV,
AV_CODEC_ID_SHEERVIDEO,
AV_CODEC_ID_YLC,
AV_CODEC_ID_PSD,
AV_CODEC_ID_PIXLET,
AV_CODEC_ID_SPEEDHQ,
AV_CODEC_ID_FMVC,
AV_CODEC_ID_SCPR,
AV_CODEC_ID_CLEARVIDEO,
AV_CODEC_ID_XPM,
AV_CODEC_ID_AV1,
AV_CODEC_ID_BITPACKED,
AV_CODEC_ID_MSCC,
AV_CODEC_ID_SRGC,
AV_CODEC_ID_SVG,
AV_CODEC_ID_GDV,
AV_CODEC_ID_FITS,
AV_CODEC_ID_IMM4,
AV_CODEC_ID_PROSUMER,
AV_CODEC_ID_MWSC,
AV_CODEC_ID_WCMV,
AV_CODEC_ID_RASC,
AV_CODEC_ID_FIRST_AUDIO = 0x10000,
AV_CODEC_ID_PCM_S16LE = 0x10000,
AV_CODEC_ID_PCM_S16BE,
AV_CODEC_ID_PCM_U16LE,
AV_CODEC_ID_PCM_U16BE,
AV_CODEC_ID_PCM_S8,
AV_CODEC_ID_PCM_U8,
AV_CODEC_ID_PCM_MULAW,
AV_CODEC_ID_PCM_ALAW,
AV_CODEC_ID_PCM_S32LE,
AV_CODEC_ID_PCM_S32BE,
AV_CODEC_ID_PCM_U32LE,
AV_CODEC_ID_PCM_U32BE,
AV_CODEC_ID_PCM_S24LE,
AV_CODEC_ID_PCM_S24BE,
AV_CODEC_ID_PCM_U24LE,
AV_CODEC_ID_PCM_U24BE,
AV_CODEC_ID_PCM_S24DAUD,
AV_CODEC_ID_PCM_ZORK,
AV_CODEC_ID_PCM_S16LE_PLANAR,
AV_CODEC_ID_PCM_DVD,
AV_CODEC_ID_PCM_F32BE,
AV_CODEC_ID_PCM_F32LE,
AV_CODEC_ID_PCM_F64BE,
AV_CODEC_ID_PCM_F64LE,
AV_CODEC_ID_PCM_BLURAY,
AV_CODEC_ID_PCM_LXF,
AV_CODEC_ID_S302M,
AV_CODEC_ID_PCM_S8_PLANAR,
AV_CODEC_ID_PCM_S24LE_PLANAR,
AV_CODEC_ID_PCM_S32LE_PLANAR,
AV_CODEC_ID_PCM_S16BE_PLANAR,
AV_CODEC_ID_PCM_S64LE = 0x10800,
AV_CODEC_ID_PCM_S64BE,
AV_CODEC_ID_PCM_F16LE,
AV_CODEC_ID_PCM_F24LE,
AV_CODEC_ID_PCM_VIDC,
AV_CODEC_ID_ADPCM_IMA_QT = 0x11000,
AV_CODEC_ID_ADPCM_IMA_WAV,
AV_CODEC_ID_ADPCM_IMA_DK3,
AV_CODEC_ID_ADPCM_IMA_DK4,
AV_CODEC_ID_ADPCM_IMA_WS,
AV_CODEC_ID_ADPCM_IMA_SMJPEG,
AV_CODEC_ID_ADPCM_MS,
AV_CODEC_ID_ADPCM_4XM,
AV_CODEC_ID_ADPCM_XA,
AV_CODEC_ID_ADPCM_ADX,
AV_CODEC_ID_ADPCM_EA,
AV_CODEC_ID_ADPCM_G726,
AV_CODEC_ID_ADPCM_CT,
AV_CODEC_ID_ADPCM_SWF,
AV_CODEC_ID_ADPCM_YAMAHA,
AV_CODEC_ID_ADPCM_SBPRO_4,
AV_CODEC_ID_ADPCM_SBPRO_3,
AV_CODEC_ID_ADPCM_SBPRO_2,
AV_CODEC_ID_ADPCM_THP,
AV_CODEC_ID_ADPCM_IMA_AMV,
AV_CODEC_ID_ADPCM_EA_R1,
AV_CODEC_ID_ADPCM_EA_R3,
AV_CODEC_ID_ADPCM_EA_R2,
AV_CODEC_ID_ADPCM_IMA_EA_SEAD,
AV_CODEC_ID_ADPCM_IMA_EA_EACS,
AV_CODEC_ID_ADPCM_EA_XAS,
AV_CODEC_ID_ADPCM_EA_MAXIS_XA,
AV_CODEC_ID_ADPCM_IMA_ISS,
AV_CODEC_ID_ADPCM_G722,
AV_CODEC_ID_ADPCM_IMA_APC,
AV_CODEC_ID_ADPCM_VIMA,
AV_CODEC_ID_ADPCM_AFC = 0x11800,
AV_CODEC_ID_ADPCM_IMA_OKI,
AV_CODEC_ID_ADPCM_DTK,
AV_CODEC_ID_ADPCM_IMA_RAD,
AV_CODEC_ID_ADPCM_G726LE,
AV_CODEC_ID_ADPCM_THP_LE,
AV_CODEC_ID_ADPCM_PSX,
AV_CODEC_ID_ADPCM_AICA,
AV_CODEC_ID_ADPCM_IMA_DAT4,
AV_CODEC_ID_ADPCM_MTAF,
AV_CODEC_ID_AMR_NB = 0x12000,
AV_CODEC_ID_AMR_WB,
AV_CODEC_ID_RA_144 = 0x13000,
AV_CODEC_ID_RA_288,
AV_CODEC_ID_ROQ_DPCM = 0x14000,
AV_CODEC_ID_INTERPLAY_DPCM,
AV_CODEC_ID_XAN_DPCM,
AV_CODEC_ID_SOL_DPCM,
AV_CODEC_ID_SDX2_DPCM = 0x14800,
AV_CODEC_ID_GREMLIN_DPCM,
AV_CODEC_ID_MP2 = 0x15000,
AV_CODEC_ID_MP3,
AV_CODEC_ID_AAC,
AV_CODEC_ID_AC3,
AV_CODEC_ID_DTS,
AV_CODEC_ID_VORBIS,
AV_CODEC_ID_DVAUDIO,
AV_CODEC_ID_WMAV1,
AV_CODEC_ID_WMAV2,
AV_CODEC_ID_MACE3,
AV_CODEC_ID_MACE6,
AV_CODEC_ID_VMDAUDIO,
AV_CODEC_ID_FLAC,
AV_CODEC_ID_MP3ADU,
AV_CODEC_ID_MP3ON4,
AV_CODEC_ID_SHORTEN,
AV_CODEC_ID_ALAC,
AV_CODEC_ID_WESTWOOD_SND1,
AV_CODEC_ID_GSM,
AV_CODEC_ID_QDM2,
AV_CODEC_ID_COOK,
AV_CODEC_ID_TRUESPEECH,
AV_CODEC_ID_TTA,
AV_CODEC_ID_SMACKAUDIO,
AV_CODEC_ID_QCELP,
AV_CODEC_ID_WAVPACK,
AV_CODEC_ID_DSICINAUDIO,
AV_CODEC_ID_IMC,
AV_CODEC_ID_MUSEPACK7,
AV_CODEC_ID_MLP,
AV_CODEC_ID_GSM_MS,
AV_CODEC_ID_ATRAC3,
AV_CODEC_ID_APE,
AV_CODEC_ID_NELLYMOSER,
AV_CODEC_ID_MUSEPACK8,
AV_CODEC_ID_SPEEX,
AV_CODEC_ID_WMAVOICE,
AV_CODEC_ID_WMAPRO,
AV_CODEC_ID_WMALOSSLESS,
AV_CODEC_ID_ATRAC3P,
AV_CODEC_ID_EAC3,
AV_CODEC_ID_SIPR,
AV_CODEC_ID_MP1,
AV_CODEC_ID_TWINVQ,
AV_CODEC_ID_TRUEHD,
AV_CODEC_ID_MP4ALS,
AV_CODEC_ID_ATRAC1,
AV_CODEC_ID_BINKAUDIO_RDFT,
AV_CODEC_ID_BINKAUDIO_DCT,
AV_CODEC_ID_AAC_LATM,
AV_CODEC_ID_QDMC,
AV_CODEC_ID_CELT,
AV_CODEC_ID_G723_1,
AV_CODEC_ID_G729,
AV_CODEC_ID_8SVX_EXP,
AV_CODEC_ID_8SVX_FIB,
AV_CODEC_ID_BMV_AUDIO,
AV_CODEC_ID_RALF,
AV_CODEC_ID_IAC,
AV_CODEC_ID_ILBC,
AV_CODEC_ID_OPUS,
AV_CODEC_ID_COMFORT_NOISE,
AV_CODEC_ID_TAK,
AV_CODEC_ID_METASOUND,
AV_CODEC_ID_PAF_AUDIO,
AV_CODEC_ID_ON2AVC,
AV_CODEC_ID_DSS_SP,
AV_CODEC_ID_CODEC2,
AV_CODEC_ID_FFWAVESYNTH = 0x15800,
AV_CODEC_ID_SONIC,
AV_CODEC_ID_SONIC_LS,
AV_CODEC_ID_EVRC,
AV_CODEC_ID_SMV,
AV_CODEC_ID_DSD_LSBF,
AV_CODEC_ID_DSD_MSBF,
AV_CODEC_ID_DSD_LSBF_PLANAR,
AV_CODEC_ID_DSD_MSBF_PLANAR,
AV_CODEC_ID_4GV,
AV_CODEC_ID_INTERPLAY_ACM,
AV_CODEC_ID_XMA1,
AV_CODEC_ID_XMA2,
AV_CODEC_ID_DST,
AV_CODEC_ID_ATRAC3AL,
AV_CODEC_ID_ATRAC3PAL,
AV_CODEC_ID_DOLBY_E,
AV_CODEC_ID_APTX,
AV_CODEC_ID_APTX_HD,
AV_CODEC_ID_SBC,
AV_CODEC_ID_ATRAC9,
AV_CODEC_ID_FIRST_SUBTITLE = 0x17000,
AV_CODEC_ID_DVD_SUBTITLE = 0x17000,
AV_CODEC_ID_DVB_SUBTITLE,
AV_CODEC_ID_TEXT,
AV_CODEC_ID_XSUB,
AV_CODEC_ID_SSA,
AV_CODEC_ID_MOV_TEXT,
AV_CODEC_ID_HDMV_PGS_SUBTITLE,
AV_CODEC_ID_DVB_TELETEXT,
AV_CODEC_ID_SRT,
AV_CODEC_ID_MICRODVD = 0x17800,
AV_CODEC_ID_EIA_608,
AV_CODEC_ID_JACOSUB,
AV_CODEC_ID_SAMI,
AV_CODEC_ID_REALTEXT,
AV_CODEC_ID_STL,
AV_CODEC_ID_SUBVIEWER1,
AV_CODEC_ID_SUBVIEWER,
AV_CODEC_ID_SUBRIP,
AV_CODEC_ID_WEBVTT,
AV_CODEC_ID_MPL2,
AV_CODEC_ID_VPLAYER,
AV_CODEC_ID_PJS,
AV_CODEC_ID_ASS,
AV_CODEC_ID_HDMV_TEXT_SUBTITLE,
AV_CODEC_ID_TTML,
AV_CODEC_ID_FIRST_UNKNOWN = 0x18000,
AV_CODEC_ID_TTF = 0x18000,
AV_CODEC_ID_SCTE_35,
AV_CODEC_ID_BINTEXT = 0x18800,
AV_CODEC_ID_XBIN,
AV_CODEC_ID_IDF,
AV_CODEC_ID_OTF,
AV_CODEC_ID_SMPTE_KLV,
AV_CODEC_ID_DVD_NAV,
AV_CODEC_ID_TIMED_ID3,
AV_CODEC_ID_BIN_DATA,
AV_CODEC_ID_PROBE = 0x19000,
AV_CODEC_ID_MPEG2TS = 0x20000,
AV_CODEC_ID_MPEG4SYSTEMS = 0x20001,
AV_CODEC_ID_FFMETADATA = 0x21000,
AV_CODEC_ID_WRAPPED_AVFRAME = 0x21001,
};
typedef struct AVCodecDescriptor {
enum AVCodecID id;
enum AVMediaType type;
const char *name;
const char *long_name;
int props;
const char *const *mime_types;
const struct AVProfile *profiles;
} AVCodecDescriptor;
enum AVDiscard{
AVDISCARD_NONE =-16,
AVDISCARD_DEFAULT = 0,
AVDISCARD_NONREF = 8,
AVDISCARD_BIDIR = 16,
AVDISCARD_NONINTRA= 24,
AVDISCARD_NONKEY = 32,
AVDISCARD_ALL = 48,
};
enum AVAudioServiceType {
AV_AUDIO_SERVICE_TYPE_MAIN = 0,
AV_AUDIO_SERVICE_TYPE_EFFECTS = 1,
AV_AUDIO_SERVICE_TYPE_VISUALLY_IMPAIRED = 2,
AV_AUDIO_SERVICE_TYPE_HEARING_IMPAIRED = 3,
AV_AUDIO_SERVICE_TYPE_DIALOGUE = 4,
AV_AUDIO_SERVICE_TYPE_COMMENTARY = 5,
AV_AUDIO_SERVICE_TYPE_EMERGENCY = 6,
AV_AUDIO_SERVICE_TYPE_VOICE_OVER = 7,
AV_AUDIO_SERVICE_TYPE_KARAOKE = 8,
AV_AUDIO_SERVICE_TYPE_NB ,
};
typedef struct RcOverride{
int start_frame;
int end_frame;
int qscale;
float quality_factor;
} RcOverride;
typedef struct AVPanScan {
int id;
int width;
int height;
int16_t position[3][2];
} AVPanScan;
typedef struct AVCPBProperties {
int max_bitrate;
int min_bitrate;
int avg_bitrate;
int buffer_size;
uint64_t vbv_delay;
} AVCPBProperties;
enum AVPacketSideDataType {
AV_PKT_DATA_PALETTE,
AV_PKT_DATA_NEW_EXTRADATA,
AV_PKT_DATA_PARAM_CHANGE,
AV_PKT_DATA_H263_MB_INFO,
AV_PKT_DATA_REPLAYGAIN,
AV_PKT_DATA_DISPLAYMATRIX,
AV_PKT_DATA_STEREO3D,
AV_PKT_DATA_AUDIO_SERVICE_TYPE,
AV_PKT_DATA_QUALITY_STATS,
AV_PKT_DATA_FALLBACK_TRACK,
AV_PKT_DATA_CPB_PROPERTIES,
AV_PKT_DATA_SKIP_SAMPLES,
AV_PKT_DATA_JP_DUALMONO,
AV_PKT_DATA_STRINGS_METADATA,
AV_PKT_DATA_SUBTITLE_POSITION,
AV_PKT_DATA_MATROSKA_BLOCKADDITIONAL,
AV_PKT_DATA_WEBVTT_IDENTIFIER,
AV_PKT_DATA_WEBVTT_SETTINGS,
AV_PKT_DATA_METADATA_UPDATE,
AV_PKT_DATA_MPEGTS_STREAM_ID,
AV_PKT_DATA_MASTERING_DISPLAY_METADATA,
AV_PKT_DATA_SPHERICAL,
AV_PKT_DATA_CONTENT_LIGHT_LEVEL,
AV_PKT_DATA_A53_CC,
AV_PKT_DATA_ENCRYPTION_INIT_INFO,
AV_PKT_DATA_ENCRYPTION_INFO,
AV_PKT_DATA_AFD,
AV_PKT_DATA_NB
};
typedef struct AVPacketSideData {
uint8_t *data;
int size;
enum AVPacketSideDataType type;
} AVPacketSideData;
typedef struct AVPacket {
AVBufferRef *buf;
int64_t pts;
int64_t dts;
uint8_t *data;
int size;
int stream_index;
int flags;
AVPacketSideData *side_data;
int side_data_elems;
int64_t duration;
int64_t pos;
__attribute__((deprecated))
int64_t convergence_duration;
} AVPacket;
enum AVSideDataParamChangeFlags {
AV_SIDE_DATA_PARAM_CHANGE_CHANNEL_COUNT = 0x0001,
AV_SIDE_DATA_PARAM_CHANGE_CHANNEL_LAYOUT = 0x0002,
AV_SIDE_DATA_PARAM_CHANGE_SAMPLE_RATE = 0x0004,
AV_SIDE_DATA_PARAM_CHANGE_DIMENSIONS = 0x0008,
};
struct AVCodecInternal;
enum AVFieldOrder {
AV_FIELD_UNKNOWN,
AV_FIELD_PROGRESSIVE,
AV_FIELD_TT,
AV_FIELD_BB,
AV_FIELD_TB,
AV_FIELD_BT,
};
typedef struct AVCodecContext {
const AVClass *av_class;
int log_level_offset;
enum AVMediaType codec_type;
const struct AVCodec *codec;
enum AVCodecID codec_id;
unsigned int codec_tag;
void *priv_data;
struct AVCodecInternal *internal;
void *opaque;
int64_t bit_rate;
int bit_rate_tolerance;
int global_quality;
int compression_level;
int flags;
int flags2;
uint8_t *extradata;
int extradata_size;
AVRational time_base;
int ticks_per_frame;
int delay;
int width, height;
int coded_width, coded_height;
int gop_size;
enum AVPixelFormat pix_fmt;
void (*draw_horiz_band)(struct AVCodecContext *s,
const AVFrame *src, int offset[8],
int y, int type, int height);
enum AVPixelFormat (*get_format)(struct AVCodecContext *s, const enum AVPixelFormat * fmt);
int max_b_frames;
float b_quant_factor;
__attribute__((deprecated))
int b_frame_strategy;
float b_quant_offset;
int has_b_frames;
__attribute__((deprecated))
int mpeg_quant;
float i_quant_factor;
float i_quant_offset;
float lumi_masking;
float temporal_cplx_masking;
float spatial_cplx_masking;
float p_masking;
float dark_masking;
int slice_count;
__attribute__((deprecated))
int prediction_method;
int *slice_offset;
AVRational sample_aspect_ratio;
int me_cmp;
int me_sub_cmp;
int mb_cmp;
int ildct_cmp;
int dia_size;
int last_predictor_count;
__attribute__((deprecated))
int pre_me;
int me_pre_cmp;
int pre_dia_size;
int me_subpel_quality;
int me_range;
int slice_flags;
int mb_decision;
uint16_t *intra_matrix;
uint16_t *inter_matrix;
__attribute__((deprecated))
int scenechange_threshold;
__attribute__((deprecated))
int noise_reduction;
int intra_dc_precision;
int skip_top;
int skip_bottom;
int mb_lmin;
int mb_lmax;
__attribute__((deprecated))
int me_penalty_compensation;
int bidir_refine;
__attribute__((deprecated))
int brd_scale;
int keyint_min;
int refs;
__attribute__((deprecated))
int chromaoffset;
int mv0_threshold;
__attribute__((deprecated))
int b_sensitivity;
enum AVColorPrimaries color_primaries;
enum AVColorTransferCharacteristic color_trc;
enum AVColorSpace colorspace;
enum AVColorRange color_range;
enum AVChromaLocation chroma_sample_location;
int slices;
enum AVFieldOrder field_order;
int sample_rate;
int channels;
enum AVSampleFormat sample_fmt;
int frame_size;
int frame_number;
int block_align;
int cutoff;
uint64_t channel_layout;
uint64_t request_channel_layout;
enum AVAudioServiceType audio_service_type;
enum AVSampleFormat request_sample_fmt;
int (*get_buffer2)(struct AVCodecContext *s, AVFrame *frame, int flags);
__attribute__((deprecated))
int refcounted_frames;
float qcompress;
float qblur;
int qmin;
int qmax;
int max_qdiff;
int rc_buffer_size;
int rc_override_count;
RcOverride *rc_override;
int64_t rc_max_rate;
int64_t rc_min_rate;
float rc_max_available_vbv_use;
float rc_min_vbv_overflow_use;
int rc_initial_buffer_occupancy;
__attribute__((deprecated))
int coder_type;
__attribute__((deprecated))
int context_model;
__attribute__((deprecated))
int frame_skip_threshold;
__attribute__((deprecated))
int frame_skip_factor;
__attribute__((deprecated))
int frame_skip_exp;
__attribute__((deprecated))
int frame_skip_cmp;
int trellis;
__attribute__((deprecated))
int min_prediction_order;
__attribute__((deprecated))
int max_prediction_order;
__attribute__((deprecated))
int64_t timecode_frame_start;
__attribute__((deprecated))
void (*rtp_callback)(struct AVCodecContext *avctx, void *data, int size, int mb_nb);
__attribute__((deprecated))
int rtp_payload_size;
__attribute__((deprecated))
int mv_bits;
__attribute__((deprecated))
int header_bits;
__attribute__((deprecated))
int i_tex_bits;
__attribute__((deprecated))
int p_tex_bits;
__attribute__((deprecated))
int i_count;
__attribute__((deprecated))
int p_count;
__attribute__((deprecated))
int skip_count;
__attribute__((deprecated))
int misc_bits;
__attribute__((deprecated))
int frame_bits;
char *stats_out;
char *stats_in;
int workaround_bugs;
int strict_std_compliance;
int error_concealment;
int debug;
int err_recognition;
int64_t reordered_opaque;
const struct AVHWAccel *hwaccel;
void *hwaccel_context;
uint64_t error[8];
int dct_algo;
int idct_algo;
int bits_per_coded_sample;
int bits_per_raw_sample;
int lowres;
__attribute__((deprecated)) AVFrame *coded_frame;
int thread_count;
int thread_type;
int active_thread_type;
int thread_safe_callbacks;
int (*execute)(struct AVCodecContext *c, int (*func)(struct AVCodecContext *c2, void *arg), void *arg2, int *ret, int count, int size);
int (*execute2)(struct AVCodecContext *c, int (*func)(struct AVCodecContext *c2, void *arg, int jobnr, int threadnr), void *arg2, int *ret, int count);
int nsse_weight;
int profile;
int level;
enum AVDiscard skip_loop_filter;
enum AVDiscard skip_idct;
enum AVDiscard skip_frame;
uint8_t *subtitle_header;
int subtitle_header_size;
__attribute__((deprecated))
uint64_t vbv_delay;
__attribute__((deprecated))
int side_data_only_packets;
int initial_padding;
AVRational framerate;
enum AVPixelFormat sw_pix_fmt;
AVRational pkt_timebase;
const AVCodecDescriptor *codec_descriptor;
int64_t pts_correction_num_faulty_pts;
int64_t pts_correction_num_faulty_dts;
int64_t pts_correction_last_pts;
int64_t pts_correction_last_dts;
char *sub_charenc;
int sub_charenc_mode;
int skip_alpha;
int seek_preroll;
int debug_mv;
uint16_t *chroma_intra_matrix;
uint8_t *dump_separator;
char *codec_whitelist;
unsigned properties;
AVPacketSideData *coded_side_data;
int nb_coded_side_data;
AVBufferRef *hw_frames_ctx;
int sub_text_format;
int trailing_padding;
int64_t max_pixels;
AVBufferRef *hw_device_ctx;
int hwaccel_flags;
int apply_cropping;
int extra_hw_frames;
} AVCodecContext;
__attribute__((deprecated))
AVRational av_codec_get_pkt_timebase (const AVCodecContext *avctx);
__attribute__((deprecated))
void av_codec_set_pkt_timebase (AVCodecContext *avctx, AVRational val);
__attribute__((deprecated))
const AVCodecDescriptor *av_codec_get_codec_descriptor(const AVCodecContext *avctx);
__attribute__((deprecated))
void av_codec_set_codec_descriptor(AVCodecContext *avctx, const AVCodecDescriptor *desc);
__attribute__((deprecated))
unsigned av_codec_get_codec_properties(const AVCodecContext *avctx);
__attribute__((deprecated))
int av_codec_get_lowres(const AVCodecContext *avctx);
__attribute__((deprecated))
void av_codec_set_lowres(AVCodecContext *avctx, int val);
__attribute__((deprecated))
int av_codec_get_seek_preroll(const AVCodecContext *avctx);
__attribute__((deprecated))
void av_codec_set_seek_preroll(AVCodecContext *avctx, int val);
__attribute__((deprecated))
uint16_t *av_codec_get_chroma_intra_matrix(const AVCodecContext *avctx);
__attribute__((deprecated))
void av_codec_set_chroma_intra_matrix(AVCodecContext *avctx, uint16_t *val);
typedef struct AVProfile {
int profile;
const char *name;
} AVProfile;
enum {
AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX = 0x01,
AV_CODEC_HW_CONFIG_METHOD_HW_FRAMES_CTX = 0x02,
AV_CODEC_HW_CONFIG_METHOD_INTERNAL = 0x04,
AV_CODEC_HW_CONFIG_METHOD_AD_HOC = 0x08,
};
typedef struct AVCodecHWConfig {
enum AVPixelFormat pix_fmt;
int methods;
enum AVHWDeviceType device_type;
} AVCodecHWConfig;
typedef struct AVCodecDefault AVCodecDefault;
struct AVSubtitle;
typedef struct AVCodec {
const char *name;
const char *long_name;
enum AVMediaType type;
enum AVCodecID id;
int capabilities;
const AVRational *supported_framerates;
const enum AVPixelFormat *pix_fmts;
const int *supported_samplerates;
const enum AVSampleFormat *sample_fmts;
const uint64_t *channel_layouts;
uint8_t max_lowres;
const AVClass *priv_class;
const AVProfile *profiles;
const char *wrapper_name;
int priv_data_size;
struct AVCodec *next;
int (*init_thread_copy)(AVCodecContext *);
int (*update_thread_context)(AVCodecContext *dst, const AVCodecContext *src);
const AVCodecDefault *defaults;
void (*init_static_data)(struct AVCodec *codec);
int (*init)(AVCodecContext *);
int (*encode_sub)(AVCodecContext *, uint8_t *buf, int buf_size,
const struct AVSubtitle *sub);
int (*encode2)(AVCodecContext *avctx, AVPacket *avpkt, const AVFrame *frame,
int *got_packet_ptr);
int (*decode)(AVCodecContext *, void *outdata, int *outdata_size, AVPacket *avpkt);
int (*close)(AVCodecContext *);
int (*send_frame)(AVCodecContext *avctx, const AVFrame *frame);
int (*receive_packet)(AVCodecContext *avctx, AVPacket *avpkt);
int (*receive_frame)(AVCodecContext *avctx, AVFrame *frame);
void (*flush)(AVCodecContext *);
int caps_internal;
const char *bsfs;
const struct AVCodecHWConfigInternal **hw_configs;
} AVCodec;
__attribute__((deprecated))
int av_codec_get_max_lowres(const AVCodec *codec);
struct MpegEncContext;
const AVCodecHWConfig *avcodec_get_hw_config(const AVCodec *codec, int index);
typedef struct AVHWAccel {
const char *name;
enum AVMediaType type;
enum AVCodecID id;
enum AVPixelFormat pix_fmt;
int capabilities;
int (*alloc_frame)(AVCodecContext *avctx, AVFrame *frame);
int (*start_frame)(AVCodecContext *avctx, const uint8_t *buf, uint32_t buf_size);
int (*decode_params)(AVCodecContext *avctx, int type, const uint8_t *buf, uint32_t buf_size);
int (*decode_slice)(AVCodecContext *avctx, const uint8_t *buf, uint32_t buf_size);
int (*end_frame)(AVCodecContext *avctx);
int frame_priv_data_size;
void (*decode_mb)(struct MpegEncContext *s);
int (*init)(AVCodecContext *avctx);
int (*uninit)(AVCodecContext *avctx);
int priv_data_size;
int caps_internal;
int (*frame_params)(AVCodecContext *avctx, AVBufferRef *hw_frames_ctx);
} AVHWAccel;
typedef struct AVPicture {
__attribute__((deprecated))
uint8_t *data[8];
__attribute__((deprecated))
int linesize[8];
} AVPicture;
enum AVSubtitleType {
SUBTITLE_NONE,
SUBTITLE_BITMAP,
SUBTITLE_TEXT,
SUBTITLE_ASS,
};
typedef struct AVSubtitleRect {
int x;
int y;
int w;
int h;
int nb_colors;
__attribute__((deprecated))
AVPicture pict;
uint8_t *data[4];
int linesize[4];
enum AVSubtitleType type;
char *text;
char *ass;
int flags;
} AVSubtitleRect;
typedef struct AVSubtitle {
uint16_t format;
uint32_t start_display_time;
uint32_t end_display_time;
unsigned num_rects;
AVSubtitleRect **rects;
int64_t pts;
} AVSubtitle;
typedef struct AVCodecParameters {
enum AVMediaType codec_type;
enum AVCodecID codec_id;
uint32_t codec_tag;
uint8_t *extradata;
int extradata_size;
int format;
int64_t bit_rate;
int bits_per_coded_sample;
int bits_per_raw_sample;
int profile;
int level;
int width;
int height;
AVRational sample_aspect_ratio;
enum AVFieldOrder field_order;
enum AVColorRange color_range;
enum AVColorPrimaries color_primaries;
enum AVColorTransferCharacteristic color_trc;
enum AVColorSpace color_space;
enum AVChromaLocation chroma_location;
int video_delay;
uint64_t channel_layout;
int channels;
int sample_rate;
int block_align;
int frame_size;
int initial_padding;
int trailing_padding;
int seek_preroll;
} AVCodecParameters;
const AVCodec *av_codec_iterate(void **opaque);
__attribute__((deprecated))
AVCodec *av_codec_next(const AVCodec *c);
unsigned avcodec_version(void);
const char *avcodec_configuration(void);
const char *avcodec_license(void);
__attribute__((deprecated))
void avcodec_register(AVCodec *codec);
__attribute__((deprecated))
void avcodec_register_all(void);
AVCodecContext *avcodec_alloc_context3(const AVCodec *codec);
void avcodec_free_context(AVCodecContext **avctx);
int avcodec_get_context_defaults3(AVCodecContext *s, const AVCodec *codec);
const AVClass *avcodec_get_class(void);
const AVClass *avcodec_get_frame_class(void);
const AVClass *avcodec_get_subtitle_rect_class(void);
__attribute__((deprecated))
int avcodec_copy_context(AVCodecContext *dest, const AVCodecContext *src);
AVCodecParameters *avcodec_parameters_alloc(void);
void avcodec_parameters_free(AVCodecParameters **par);
int avcodec_parameters_copy(AVCodecParameters *dst, const AVCodecParameters *src);
int avcodec_parameters_from_context(AVCodecParameters *par,
const AVCodecContext *codec);
int avcodec_parameters_to_context(AVCodecContext *codec,
const AVCodecParameters *par);
int avcodec_open2(AVCodecContext *avctx, const AVCodec *codec, AVDictionary **options);
int avcodec_close(AVCodecContext *avctx);
void avsubtitle_free(AVSubtitle *sub);
AVPacket *av_packet_alloc(void);
AVPacket *av_packet_clone(const AVPacket *src);
void av_packet_free(AVPacket **pkt);
void av_init_packet(AVPacket *pkt);
int av_new_packet(AVPacket *pkt, int size);
void av_shrink_packet(AVPacket *pkt, int size);
int av_grow_packet(AVPacket *pkt, int grow_by);
int av_packet_from_data(AVPacket *pkt, uint8_t *data, int size);
__attribute__((deprecated))
int av_dup_packet(AVPacket *pkt);
__attribute__((deprecated))
int av_copy_packet(AVPacket *dst, const AVPacket *src);
__attribute__((deprecated))
int av_copy_packet_side_data(AVPacket *dst, const AVPacket *src);
__attribute__((deprecated))
void av_free_packet(AVPacket *pkt);
uint8_t* av_packet_new_side_data(AVPacket *pkt, enum AVPacketSideDataType type,
int size);
int av_packet_add_side_data(AVPacket *pkt, enum AVPacketSideDataType type,
uint8_t *data, size_t size);
int av_packet_shrink_side_data(AVPacket *pkt, enum AVPacketSideDataType type,
int size);
uint8_t* av_packet_get_side_data(const AVPacket *pkt, enum AVPacketSideDataType type,
int *size);
__attribute__((deprecated))
int av_packet_merge_side_data(AVPacket *pkt);
__attribute__((deprecated))
int av_packet_split_side_data(AVPacket *pkt);
const char *av_packet_side_data_name(enum AVPacketSideDataType type);
uint8_t *av_packet_pack_dictionary(AVDictionary *dict, int *size);
int av_packet_unpack_dictionary(const uint8_t *data, int size, AVDictionary **dict);
void av_packet_free_side_data(AVPacket *pkt);
int av_packet_ref(AVPacket *dst, const AVPacket *src);
void av_packet_unref(AVPacket *pkt);
void av_packet_move_ref(AVPacket *dst, AVPacket *src);
int av_packet_copy_props(AVPacket *dst, const AVPacket *src);
int av_packet_make_refcounted(AVPacket *pkt);
int av_packet_make_writable(AVPacket *pkt);
void av_packet_rescale_ts(AVPacket *pkt, AVRational tb_src, AVRational tb_dst);
AVCodec *avcodec_find_decoder(enum AVCodecID id);
AVCodec *avcodec_find_decoder_by_name(const char *name);
int avcodec_default_get_buffer2(AVCodecContext *s, AVFrame *frame, int flags);
void avcodec_align_dimensions(AVCodecContext *s, int *width, int *height);
void avcodec_align_dimensions2(AVCodecContext *s, int *width, int *height,
int linesize_align[8]);
int avcodec_enum_to_chroma_pos(int *xpos, int *ypos, enum AVChromaLocation pos);
enum AVChromaLocation avcodec_chroma_pos_to_enum(int xpos, int ypos);
__attribute__((deprecated))
int avcodec_decode_audio4(AVCodecContext *avctx, AVFrame *frame,
int *got_frame_ptr, const AVPacket *avpkt);
__attribute__((deprecated))
int avcodec_decode_video2(AVCodecContext *avctx, AVFrame *picture,
int *got_picture_ptr,
const AVPacket *avpkt);
int avcodec_decode_subtitle2(AVCodecContext *avctx, AVSubtitle *sub,
int *got_sub_ptr,
AVPacket *avpkt);
int avcodec_send_packet(AVCodecContext *avctx, const AVPacket *avpkt);
int avcodec_receive_frame(AVCodecContext *avctx, AVFrame *frame);
int avcodec_send_frame(AVCodecContext *avctx, const AVFrame *frame);
int avcodec_receive_packet(AVCodecContext *avctx, AVPacket *avpkt);
int avcodec_get_hw_frames_parameters(AVCodecContext *avctx,
AVBufferRef *device_ref,
enum AVPixelFormat hw_pix_fmt,
AVBufferRef **out_frames_ref);
enum AVPictureStructure {
AV_PICTURE_STRUCTURE_UNKNOWN,
AV_PICTURE_STRUCTURE_TOP_FIELD,
AV_PICTURE_STRUCTURE_BOTTOM_FIELD,
AV_PICTURE_STRUCTURE_FRAME,
};
typedef struct AVCodecParserContext {
void *priv_data;
struct AVCodecParser *parser;
int64_t frame_offset;
int64_t cur_offset;
int64_t next_frame_offset;
int pict_type;
int repeat_pict;
int64_t pts;
int64_t dts;
int64_t last_pts;
int64_t last_dts;
int fetch_timestamp;
int cur_frame_start_index;
int64_t cur_frame_offset[4];
int64_t cur_frame_pts[4];
int64_t cur_frame_dts[4];
int flags;
int64_t offset;
int64_t cur_frame_end[4];
int key_frame;
__attribute__((deprecated))
int64_t convergence_duration;
int dts_sync_point;
int dts_ref_dts_delta;
int pts_dts_delta;
int64_t cur_frame_pos[4];
int64_t pos;
int64_t last_pos;
int duration;
enum AVFieldOrder field_order;
enum AVPictureStructure picture_structure;
int output_picture_number;
int width;
int height;
int coded_width;
int coded_height;
int format;
} AVCodecParserContext;
typedef struct AVCodecParser {
int codec_ids[5];
int priv_data_size;
int (*parser_init)(AVCodecParserContext *s);
int (*parser_parse)(AVCodecParserContext *s,
AVCodecContext *avctx,
const uint8_t **poutbuf, int *poutbuf_size,
const uint8_t *buf, int buf_size);
void (*parser_close)(AVCodecParserContext *s);
int (*split)(AVCodecContext *avctx, const uint8_t *buf, int buf_size);
struct AVCodecParser *next;
} AVCodecParser;
const AVCodecParser *av_parser_iterate(void **opaque);
__attribute__((deprecated))
AVCodecParser *av_parser_next(const AVCodecParser *c);
__attribute__((deprecated))
void av_register_codec_parser(AVCodecParser *parser);
AVCodecParserContext *av_parser_init(int codec_id);
int av_parser_parse2(AVCodecParserContext *s,
AVCodecContext *avctx,
uint8_t **poutbuf, int *poutbuf_size,
const uint8_t *buf, int buf_size,
int64_t pts, int64_t dts,
int64_t pos);
int av_parser_change(AVCodecParserContext *s,
AVCodecContext *avctx,
uint8_t **poutbuf, int *poutbuf_size,
const uint8_t *buf, int buf_size, int keyframe);
void av_parser_close(AVCodecParserContext *s);
AVCodec *avcodec_find_encoder(enum AVCodecID id);
AVCodec *avcodec_find_encoder_by_name(const char *name);
__attribute__((deprecated))
int avcodec_encode_audio2(AVCodecContext *avctx, AVPacket *avpkt,
const AVFrame *frame, int *got_packet_ptr);
__attribute__((deprecated))
int avcodec_encode_video2(AVCodecContext *avctx, AVPacket *avpkt,
const AVFrame *frame, int *got_packet_ptr);
int avcodec_encode_subtitle(AVCodecContext *avctx, uint8_t *buf, int buf_size,
const AVSubtitle *sub);
__attribute__((deprecated))
int avpicture_alloc(AVPicture *picture, enum AVPixelFormat pix_fmt, int width, int height);
__attribute__((deprecated))
void avpicture_free(AVPicture *picture);
__attribute__((deprecated))
int avpicture_fill(AVPicture *picture, const uint8_t *ptr,
enum AVPixelFormat pix_fmt, int width, int height);
__attribute__((deprecated))
int avpicture_layout(const AVPicture *src, enum AVPixelFormat pix_fmt,
int width, int height,
unsigned char *dest, int dest_size);
__attribute__((deprecated))
int avpicture_get_size(enum AVPixelFormat pix_fmt, int width, int height);
__attribute__((deprecated))
void av_picture_copy(AVPicture *dst, const AVPicture *src,
enum AVPixelFormat pix_fmt, int width, int height);
__attribute__((deprecated))
int av_picture_crop(AVPicture *dst, const AVPicture *src,
enum AVPixelFormat pix_fmt, int top_band, int left_band);
__attribute__((deprecated))
int av_picture_pad(AVPicture *dst, const AVPicture *src, int height, int width, enum AVPixelFormat pix_fmt,
int padtop, int padbottom, int padleft, int padright, int *color);
__attribute__((deprecated))
void avcodec_get_chroma_sub_sample(enum AVPixelFormat pix_fmt, int *h_shift, int *v_shift);
unsigned int avcodec_pix_fmt_to_codec_tag(enum AVPixelFormat pix_fmt);
int avcodec_get_pix_fmt_loss(enum AVPixelFormat dst_pix_fmt, enum AVPixelFormat src_pix_fmt,
int has_alpha);
enum AVPixelFormat avcodec_find_best_pix_fmt_of_list(const enum AVPixelFormat *pix_fmt_list,
enum AVPixelFormat src_pix_fmt,
int has_alpha, int *loss_ptr);
enum AVPixelFormat avcodec_find_best_pix_fmt_of_2(enum AVPixelFormat dst_pix_fmt1, enum AVPixelFormat dst_pix_fmt2,
enum AVPixelFormat src_pix_fmt, int has_alpha, int *loss_ptr);
__attribute__((deprecated))
enum AVPixelFormat avcodec_find_best_pix_fmt2(enum AVPixelFormat dst_pix_fmt1, enum AVPixelFormat dst_pix_fmt2,
enum AVPixelFormat src_pix_fmt, int has_alpha, int *loss_ptr);
enum AVPixelFormat avcodec_default_get_format(struct AVCodecContext *s, const enum AVPixelFormat * fmt);
__attribute__((deprecated))
size_t av_get_codec_tag_string(char *buf, size_t buf_size, unsigned int codec_tag);
void avcodec_string(char *buf, int buf_size, AVCodecContext *enc, int encode);
const char *av_get_profile_name(const AVCodec *codec, int profile);
const char *avcodec_profile_name(enum AVCodecID codec_id, int profile);
int avcodec_default_execute(AVCodecContext *c, int (*func)(AVCodecContext *c2, void *arg2),void *arg, int *ret, int count, int size);
int avcodec_default_execute2(AVCodecContext *c, int (*func)(AVCodecContext *c2, void *arg2, int, int),void *arg, int *ret, int count);
int avcodec_fill_audio_frame(AVFrame *frame, int nb_channels,
enum AVSampleFormat sample_fmt, const uint8_t *buf,
int buf_size, int align);
void avcodec_flush_buffers(AVCodecContext *avctx);
int av_get_bits_per_sample(enum AVCodecID codec_id);
enum AVCodecID av_get_pcm_codec(enum AVSampleFormat fmt, int be);
int av_get_exact_bits_per_sample(enum AVCodecID codec_id);
int av_get_audio_frame_duration(AVCodecContext *avctx, int frame_bytes);
int av_get_audio_frame_duration2(AVCodecParameters *par, int frame_bytes);
typedef struct AVBitStreamFilterContext {
void *priv_data;
const struct AVBitStreamFilter *filter;
AVCodecParserContext *parser;
struct AVBitStreamFilterContext *next;
char *args;
} AVBitStreamFilterContext;
typedef struct AVBSFInternal AVBSFInternal;
typedef struct AVBSFContext {
const AVClass *av_class;
const struct AVBitStreamFilter *filter;
AVBSFInternal *internal;
void *priv_data;
AVCodecParameters *par_in;
AVCodecParameters *par_out;
AVRational time_base_in;
AVRational time_base_out;
} AVBSFContext;
typedef struct AVBitStreamFilter {
const char *name;
const enum AVCodecID *codec_ids;
const AVClass *priv_class;
int priv_data_size;
int (*init)(AVBSFContext *ctx);
int (*filter)(AVBSFContext *ctx, AVPacket *pkt);
void (*close)(AVBSFContext *ctx);
void (*flush)(AVBSFContext *ctx);
} AVBitStreamFilter;
__attribute__((deprecated))
void av_register_bitstream_filter(AVBitStreamFilter *bsf);
__attribute__((deprecated))
AVBitStreamFilterContext *av_bitstream_filter_init(const char *name);
__attribute__((deprecated))
int av_bitstream_filter_filter(AVBitStreamFilterContext *bsfc,
AVCodecContext *avctx, const char *args,
uint8_t **poutbuf, int *poutbuf_size,
const uint8_t *buf, int buf_size, int keyframe);
__attribute__((deprecated))
void av_bitstream_filter_close(AVBitStreamFilterContext *bsf);
__attribute__((deprecated))
const AVBitStreamFilter *av_bitstream_filter_next(const AVBitStreamFilter *f);
const AVBitStreamFilter *av_bsf_get_by_name(const char *name);
const AVBitStreamFilter *av_bsf_iterate(void **opaque);
__attribute__((deprecated))
const AVBitStreamFilter *av_bsf_next(void **opaque);
int av_bsf_alloc(const AVBitStreamFilter *filter, AVBSFContext **ctx);
int av_bsf_init(AVBSFContext *ctx);
int av_bsf_send_packet(AVBSFContext *ctx, AVPacket *pkt);
int av_bsf_receive_packet(AVBSFContext *ctx, AVPacket *pkt);
void av_bsf_flush(AVBSFContext *ctx);
void av_bsf_free(AVBSFContext **ctx);
const AVClass *av_bsf_get_class(void);
typedef struct AVBSFList AVBSFList;
AVBSFList *av_bsf_list_alloc(void);
void av_bsf_list_free(AVBSFList **lst);
int av_bsf_list_append(AVBSFList *lst, AVBSFContext *bsf);
int av_bsf_list_append2(AVBSFList *lst, const char * bsf_name, AVDictionary **options);
int av_bsf_list_finalize(AVBSFList **lst, AVBSFContext **bsf);
int av_bsf_list_parse_str(const char *str, AVBSFContext **bsf);
int av_bsf_get_null_filter(AVBSFContext **bsf);
void av_fast_padded_malloc(void *ptr, unsigned int *size, size_t min_size);
void av_fast_padded_mallocz(void *ptr, unsigned int *size, size_t min_size);
unsigned int av_xiphlacing(unsigned char *s, unsigned int v);
__attribute__((deprecated))
void av_register_hwaccel(AVHWAccel *hwaccel);
__attribute__((deprecated))
AVHWAccel *av_hwaccel_next(const AVHWAccel *hwaccel);
enum AVLockOp {
AV_LOCK_CREATE,
AV_LOCK_OBTAIN,
AV_LOCK_RELEASE,
AV_LOCK_DESTROY,
};
__attribute__((deprecated))
int av_lockmgr_register(int (*cb)(void **mutex, enum AVLockOp op));
enum AVMediaType avcodec_get_type(enum AVCodecID codec_id);
const char *avcodec_get_name(enum AVCodecID id);
int avcodec_is_open(AVCodecContext *s);
int av_codec_is_encoder(const AVCodec *codec);
int av_codec_is_decoder(const AVCodec *codec);
const AVCodecDescriptor *avcodec_descriptor_get(enum AVCodecID id);
const AVCodecDescriptor *avcodec_descriptor_next(const AVCodecDescriptor *prev);
const AVCodecDescriptor *avcodec_descriptor_get_by_name(const char *name);
AVCPBProperties *av_cpb_properties_alloc(size_t *size);
struct tm
{
int tm_sec;
int tm_min;
int tm_hour;
int tm_mday;
int tm_mon;
int tm_year;
int tm_wday;
int tm_yday;
int tm_isdst;
long tm_gmtoff;
const char *tm_zone;
};
clock_t __attribute__((__cdecl__)) clock (void);
double __attribute__((__cdecl__)) difftime (time_t _time2, time_t _time1);
time_t __attribute__((__cdecl__)) mktime (struct tm *_timeptr);
time_t __attribute__((__cdecl__)) time (time_t *_timer);
char *__attribute__((__cdecl__)) asctime (const struct tm *_tblock);
char *__attribute__((__cdecl__)) ctime (const time_t *_time);
struct tm *__attribute__((__cdecl__)) gmtime (const time_t *_timer);
struct tm *__attribute__((__cdecl__)) localtime (const time_t *_timer);
size_t __attribute__((__cdecl__)) strftime (char *restrict _s, size_t _maxsize, const char *restrict _fmt, const struct tm *restrict _t)
;
extern size_t strftime_l (char *restrict _s, size_t _maxsize,
const char *restrict _fmt,
const struct tm *restrict _t, locale_t _l);
char *__attribute__((__cdecl__)) asctime_r (const struct tm *restrict, char *restrict)
;
char *__attribute__((__cdecl__)) ctime_r (const time_t *, char *);
struct tm *__attribute__((__cdecl__)) gmtime_r (const time_t *restrict, struct tm *restrict)
;
struct tm *__attribute__((__cdecl__)) localtime_r (const time_t *restrict, struct tm *restrict)
;
void __attribute__((__cdecl__)) tzset (void);
void __attribute__((__cdecl__)) _tzset_r (struct _reent *);
typedef struct __tzrule_struct
{
char ch;
int m;
int n;
int d;
int s;
time_t change;
long offset;
} __tzrule_type;
typedef struct __tzinfo_struct
{
int __tznorth;
int __tzyear;
__tzrule_type __tzrule[2];
} __tzinfo_type;
__tzinfo_type *__attribute__((__cdecl__)) __gettzinfo (void);
extern __attribute__((dllimport)) long _timezone;
extern __attribute__((dllimport)) int _daylight;
extern __attribute__((dllimport)) char *_tzname[2];
int __attribute__((__cdecl__)) clock_setres (clockid_t, struct timespec *);
time_t __attribute__((__cdecl__)) timelocal (struct tm *);
time_t __attribute__((__cdecl__)) timegm (struct tm *);
extern int stime (const time_t *);
extern int daylight __asm__ ( "_daylight");
extern long timezone __asm__ ( "_timezone");
struct _uc_fpxreg {
__uint16_t significand[4];
__uint16_t exponent;
__uint16_t padding[3];
};
struct _uc_xmmreg {
__uint32_t element[4];
};
struct _fpstate
{
__uint16_t cwd;
__uint16_t swd;
__uint16_t ftw;
__uint16_t fop;
__uint64_t rip;
__uint64_t rdp;
__uint32_t mxcsr;
__uint32_t mxcr_mask;
struct _uc_fpxreg st[8];
struct _uc_xmmreg xmm[16];
__uint32_t padding[24];
};
struct __attribute__ ((__aligned__ (16))) __mcontext
{
__uint64_t p1home;
__uint64_t p2home;
__uint64_t p3home;
__uint64_t p4home;
__uint64_t p5home;
__uint64_t p6home;
__uint32_t ctxflags;
__uint32_t mxcsr;
__uint16_t cs;
__uint16_t ds;
__uint16_t es;
__uint16_t fs;
__uint16_t gs;
__uint16_t ss;
__uint32_t eflags;
__uint64_t dr0;
__uint64_t dr1;
__uint64_t dr2;
__uint64_t dr3;
__uint64_t dr6;
__uint64_t dr7;
__uint64_t rax;
__uint64_t rcx;
__uint64_t rdx;
__uint64_t rbx;
__uint64_t rsp;
__uint64_t rbp;
__uint64_t rsi;
__uint64_t rdi;
__uint64_t r8;
__uint64_t r9;
__uint64_t r10;
__uint64_t r11;
__uint64_t r12;
__uint64_t r13;
__uint64_t r14;
__uint64_t r15;
__uint64_t rip;
struct _fpstate fpregs;
__uint64_t vregs[52];
__uint64_t vcx;
__uint64_t dbc;
__uint64_t btr;
__uint64_t bfr;
__uint64_t etr;
__uint64_t efr;
__uint64_t oldmask;
__uint64_t cr2;
};
typedef union sigval
{
int sival_int;
void *sival_ptr;
} sigval_t;
typedef struct sigevent
{
sigval_t sigev_value;
int sigev_signo;
int sigev_notify;
void (*sigev_notify_function) (sigval_t);
pthread_attr_t *sigev_notify_attributes;
} sigevent_t;
struct _sigcommune
{
__uint32_t _si_code;
void *_si_read_handle;
void *_si_write_handle;
void *_si_process_handle;
__extension__ union
{
int _si_fd;
int64_t _si_pipe_unique_id;
char *_si_str;
};
};
typedef struct
{
int si_signo;
int si_code;
pid_t si_pid;
uid_t si_uid;
int si_errno;
__extension__ union
{
__uint32_t __pad[32];
struct _sigcommune _si_commune;
__extension__ struct
{
__extension__ union
{
sigval_t si_sigval;
sigval_t si_value;
};
__extension__ struct
{
timer_t si_tid;
unsigned int si_overrun;
};
};
__extension__ struct
{
int si_status;
clock_t si_utime;
clock_t si_stime;
};
void *si_addr;
};
} siginfo_t;
enum
{
SI_USER = 0,
SI_ASYNCIO = 2,
SI_MESGQ,
SI_TIMER,
SI_QUEUE,
SI_KERNEL,
ILL_ILLOPC,
ILL_ILLOPN,
ILL_ILLADR,
ILL_ILLTRP,
ILL_PRVOPC,
ILL_PRVREG,
ILL_COPROC,
ILL_BADSTK,
FPE_INTDIV,
FPE_INTOVF,
FPE_FLTDIV,
FPE_FLTOVF,
FPE_FLTUND,
FPE_FLTRES,
FPE_FLTINV,
FPE_FLTSUB,
SEGV_MAPERR,
SEGV_ACCERR,
BUS_ADRALN,
BUS_ADRERR,
BUS_OBJERR,
CLD_EXITED,
CLD_KILLED,
CLD_DUMPED,
CLD_TRAPPED,
CLD_STOPPED,
CLD_CONTINUED
};
enum
{
SIGEV_SIGNAL = 0,
SIGEV_NONE,
SIGEV_THREAD
};
typedef void (*_sig_func_ptr)(int);
struct sigaction
{
__extension__ union
{
_sig_func_ptr sa_handler;
void (*sa_sigaction) ( int, siginfo_t *, void * );
};
sigset_t sa_mask;
int sa_flags;
};
void psiginfo (const siginfo_t *, const char *);
int sigwait (const sigset_t *, int *);
int sigwaitinfo (const sigset_t *, siginfo_t *);
int sigqueue(pid_t, int, const union sigval);
int siginterrupt (int, int);
extern const char __attribute__((dllimport)) *sys_sigabbrev[];
extern const char __attribute__((dllimport)) *sys_siglist[];
typedef struct sigaltstack {
void *ss_sp;
int ss_flags;
size_t ss_size;
} stack_t;
int __attribute__((__cdecl__)) sigprocmask (int how, const sigset_t *set, sigset_t *oset);
int __attribute__((__cdecl__)) pthread_sigmask (int how, const sigset_t *set, sigset_t *oset);
int __attribute__((__cdecl__)) kill (pid_t, int);
int __attribute__((__cdecl__)) killpg (pid_t, int);
int __attribute__((__cdecl__)) sigaction (int, const struct sigaction *, struct sigaction *);
int __attribute__((__cdecl__)) sigaddset (sigset_t *, const int);
int __attribute__((__cdecl__)) sigdelset (sigset_t *, const int);
int __attribute__((__cdecl__)) sigismember (const sigset_t *, int);
int __attribute__((__cdecl__)) sigfillset (sigset_t *);
int __attribute__((__cdecl__)) sigemptyset (sigset_t *);
int __attribute__((__cdecl__)) sigpending (sigset_t *);
int __attribute__((__cdecl__)) sigsuspend (const sigset_t *);
int __attribute__((__cdecl__)) sigwait (const sigset_t *set, int *sig);
int __attribute__((__cdecl__)) sigpause (int);
int __attribute__((__cdecl__)) sigaltstack (const stack_t *restrict, stack_t *restrict);
int __attribute__((__cdecl__)) pthread_kill (pthread_t thread, int sig);
int __attribute__((__cdecl__)) sigwaitinfo (const sigset_t *set, siginfo_t *info);
int __attribute__((__cdecl__)) sigtimedwait (const sigset_t *set, siginfo_t *info, const struct timespec *timeout)
;
int __attribute__((__cdecl__)) sigqueue (pid_t pid, int signo, const union sigval value);
typedef struct __mcontext mcontext_t;
typedef __attribute__ ((__aligned__ (16))) struct __ucontext {
mcontext_t uc_mcontext;
struct __ucontext *uc_link;
sigset_t uc_sigmask;
stack_t uc_stack;
unsigned long int uc_flags;
} ucontext_t;
typedef int sig_atomic_t;
typedef _sig_func_ptr sig_t;
struct _reent;
_sig_func_ptr __attribute__((__cdecl__)) _signal_r (struct _reent *, int, _sig_func_ptr);
int __attribute__((__cdecl__)) _raise_r (struct _reent *, int);
_sig_func_ptr __attribute__((__cdecl__)) signal (int, _sig_func_ptr);
int __attribute__((__cdecl__)) raise (int);
void __attribute__((__cdecl__)) psignal (int, const char *);
int __attribute__((__cdecl__)) clock_settime (clockid_t clock_id, const struct timespec *tp);
int __attribute__((__cdecl__)) clock_gettime (clockid_t clock_id, struct timespec *tp);
int __attribute__((__cdecl__)) clock_getres (clockid_t clock_id, struct timespec *res);
int __attribute__((__cdecl__)) timer_create (clockid_t clock_id, struct sigevent *restrict evp, timer_t *restrict timerid)
;
int __attribute__((__cdecl__)) timer_delete (timer_t timerid);
int __attribute__((__cdecl__)) timer_settime (timer_t timerid, int flags, const struct itimerspec *restrict value, struct itimerspec *restrict ovalue)
;
int __attribute__((__cdecl__)) timer_gettime (timer_t timerid, struct itimerspec *value);
int __attribute__((__cdecl__)) timer_getoverrun (timer_t timerid);
int __attribute__((__cdecl__)) nanosleep (const struct timespec *rqtp, struct timespec *rmtp);
int __attribute__((__cdecl__)) clock_nanosleep (clockid_t clock_id, int flags, const struct timespec *rqtp, struct timespec *rmtp)
;
int __attribute__((__cdecl__)) clock_getcpuclockid (pid_t pid, clockid_t *clock_id);
int __attribute__((__cdecl__)) clock_setenable_attr (clockid_t clock_id, int attr);
int __attribute__((__cdecl__)) clock_getenable_attr (clockid_t clock_id, int *attr);
typedef struct AVIOInterruptCB {
int (*callback)(void*);
void *opaque;
} AVIOInterruptCB;
enum AVIODirEntryType {
AVIO_ENTRY_UNKNOWN,
AVIO_ENTRY_BLOCK_DEVICE,
AVIO_ENTRY_CHARACTER_DEVICE,
AVIO_ENTRY_DIRECTORY,
AVIO_ENTRY_NAMED_PIPE,
AVIO_ENTRY_SYMBOLIC_LINK,
AVIO_ENTRY_SOCKET,
AVIO_ENTRY_FILE,
AVIO_ENTRY_SERVER,
AVIO_ENTRY_SHARE,
AVIO_ENTRY_WORKGROUP,
};
typedef struct AVIODirEntry {
char *name;
int type;
int utf8;
int64_t size;
int64_t modification_timestamp;
int64_t access_timestamp;
int64_t status_change_timestamp;
int64_t user_id;
int64_t group_id;
int64_t filemode;
} AVIODirEntry;
typedef struct AVIODirContext {
struct URLContext *url_context;
} AVIODirContext;
enum AVIODataMarkerType {
AVIO_DATA_MARKER_HEADER,
AVIO_DATA_MARKER_SYNC_POINT,
AVIO_DATA_MARKER_BOUNDARY_POINT,
AVIO_DATA_MARKER_UNKNOWN,
AVIO_DATA_MARKER_TRAILER,
AVIO_DATA_MARKER_FLUSH_POINT,
};
typedef struct AVIOContext {
const AVClass *av_class;
unsigned char *buffer;
int buffer_size;
unsigned char *buf_ptr;
unsigned char *buf_end;
void *opaque;
int (*read_packet)(void *opaque, uint8_t *buf, int buf_size);
int (*write_packet)(void *opaque, uint8_t *buf, int buf_size);
int64_t (*seek)(void *opaque, int64_t offset, int whence);
int64_t pos;
int eof_reached;
int write_flag;
int max_packet_size;
unsigned long checksum;
unsigned char *checksum_ptr;
unsigned long (*update_checksum)(unsigned long checksum, const uint8_t *buf, unsigned int size);
int error;
int (*read_pause)(void *opaque, int pause);
int64_t (*read_seek)(void *opaque, int stream_index,
int64_t timestamp, int flags);
int seekable;
int64_t maxsize;
int direct;
int64_t bytes_read;
int seek_count;
int writeout_count;
int orig_buffer_size;
int short_seek_threshold;
const char *protocol_whitelist;
const char *protocol_blacklist;
int (*write_data_type)(void *opaque, uint8_t *buf, int buf_size,
enum AVIODataMarkerType type, int64_t time);
int ignore_boundary_point;
enum AVIODataMarkerType current_type;
int64_t last_time;
int (*short_seek_get)(void *opaque);
int64_t written;
unsigned char *buf_ptr_max;
int min_packet_size;
} AVIOContext;
const char *avio_find_protocol_name(const char *url);
int avio_check(const char *url, int flags);
int avpriv_io_move(const char *url_src, const char *url_dst);
int avpriv_io_delete(const char *url);
int avio_open_dir(AVIODirContext **s, const char *url, AVDictionary **options);
int avio_read_dir(AVIODirContext *s, AVIODirEntry **next);
int avio_close_dir(AVIODirContext **s);
void avio_free_directory_entry(AVIODirEntry **entry);
AVIOContext *avio_alloc_context(
unsigned char *buffer,
int buffer_size,
int write_flag,
void *opaque,
int (*read_packet)(void *opaque, uint8_t *buf, int buf_size),
int (*write_packet)(void *opaque, uint8_t *buf, int buf_size),
int64_t (*seek)(void *opaque, int64_t offset, int whence));
void avio_context_free(AVIOContext **s);
void avio_w8(AVIOContext *s, int b);
void avio_write(AVIOContext *s, const unsigned char *buf, int size);
void avio_wl64(AVIOContext *s, uint64_t val);
void avio_wb64(AVIOContext *s, uint64_t val);
void avio_wl32(AVIOContext *s, unsigned int val);
void avio_wb32(AVIOContext *s, unsigned int val);
void avio_wl24(AVIOContext *s, unsigned int val);
void avio_wb24(AVIOContext *s, unsigned int val);
void avio_wl16(AVIOContext *s, unsigned int val);
void avio_wb16(AVIOContext *s, unsigned int val);
int avio_put_str(AVIOContext *s, const char *str);
int avio_put_str16le(AVIOContext *s, const char *str);
int avio_put_str16be(AVIOContext *s, const char *str);
void avio_write_marker(AVIOContext *s, int64_t time, enum AVIODataMarkerType type);
int64_t avio_seek(AVIOContext *s, int64_t offset, int whence);
int64_t avio_skip(AVIOContext *s, int64_t offset);
static __attribute__((always_inline)) inline int64_t avio_tell(AVIOContext *s)
{
return avio_seek(s, 0,
1
);
}
int64_t avio_size(AVIOContext *s);
int avio_feof(AVIOContext *s);
int avio_printf(AVIOContext *s, const char *fmt, ...) __attribute__((__format__(__printf__, 2, 3)));
void avio_flush(AVIOContext *s);
int avio_read(AVIOContext *s, unsigned char *buf, int size);
int avio_read_partial(AVIOContext *s, unsigned char *buf, int size);
int avio_r8 (AVIOContext *s);
unsigned int avio_rl16(AVIOContext *s);
unsigned int avio_rl24(AVIOContext *s);
unsigned int avio_rl32(AVIOContext *s);
uint64_t avio_rl64(AVIOContext *s);
unsigned int avio_rb16(AVIOContext *s);
unsigned int avio_rb24(AVIOContext *s);
unsigned int avio_rb32(AVIOContext *s);
uint64_t avio_rb64(AVIOContext *s);
int avio_get_str(AVIOContext *pb, int maxlen, char *buf, int buflen);
int avio_get_str16le(AVIOContext *pb, int maxlen, char *buf, int buflen);
int avio_get_str16be(AVIOContext *pb, int maxlen, char *buf, int buflen);
int avio_open(AVIOContext **s, const char *url, int flags);
int avio_open2(AVIOContext **s, const char *url, int flags,
const AVIOInterruptCB *int_cb, AVDictionary **options);
int avio_close(AVIOContext *s);
int avio_closep(AVIOContext **s);
int avio_open_dyn_buf(AVIOContext **s);
int avio_get_dyn_buf(AVIOContext *s, uint8_t **pbuffer);
int avio_close_dyn_buf(AVIOContext *s, uint8_t **pbuffer);
const char *avio_enum_protocols(void **opaque, int output);
int avio_pause(AVIOContext *h, int pause);
int64_t avio_seek_time(AVIOContext *h, int stream_index,
int64_t timestamp, int flags);
struct AVBPrint;
int avio_read_to_bprint(AVIOContext *h, struct AVBPrint *pb, size_t max_size);
int avio_accept(AVIOContext *s, AVIOContext **c);
int avio_handshake(AVIOContext *c);
struct AVFormatContext;
struct AVDeviceInfoList;
struct AVDeviceCapabilitiesQuery;
int av_get_packet(AVIOContext *s, AVPacket *pkt, int size);
int av_append_packet(AVIOContext *s, AVPacket *pkt, int size);
struct AVCodecTag;
typedef struct AVProbeData {
const char *filename;
unsigned char *buf;
int buf_size;
const char *mime_type;
} AVProbeData;
typedef struct AVOutputFormat {
const char *name;
const char *long_name;
const char *mime_type;
const char *extensions;
enum AVCodecID audio_codec;
enum AVCodecID video_codec;
enum AVCodecID subtitle_codec;
int flags;
const struct AVCodecTag * const *codec_tag;
const AVClass *priv_class;
struct AVOutputFormat *next;
int priv_data_size;
int (*write_header)(struct AVFormatContext *);
int (*write_packet)(struct AVFormatContext *, AVPacket *pkt);
int (*write_trailer)(struct AVFormatContext *);
int (*interleave_packet)(struct AVFormatContext *, AVPacket *out,
AVPacket *in, int flush);
int (*query_codec)(enum AVCodecID id, int std_compliance);
void (*get_output_timestamp)(struct AVFormatContext *s, int stream,
int64_t *dts, int64_t *wall);
int (*control_message)(struct AVFormatContext *s, int type,
void *data, size_t data_size);
int (*write_uncoded_frame)(struct AVFormatContext *, int stream_index,
AVFrame **frame, unsigned flags);
int (*get_device_list)(struct AVFormatContext *s, struct AVDeviceInfoList *device_list);
int (*create_device_capabilities)(struct AVFormatContext *s, struct AVDeviceCapabilitiesQuery *caps);
int (*free_device_capabilities)(struct AVFormatContext *s, struct AVDeviceCapabilitiesQuery *caps);
enum AVCodecID data_codec;
int (*init)(struct AVFormatContext *);
void (*deinit)(struct AVFormatContext *);
int (*check_bitstream)(struct AVFormatContext *, const AVPacket *pkt);
} AVOutputFormat;
typedef struct AVInputFormat {
const char *name;
const char *long_name;
int flags;
const char *extensions;
const struct AVCodecTag * const *codec_tag;
const AVClass *priv_class;
const char *mime_type;
struct AVInputFormat *next;
int raw_codec_id;
int priv_data_size;
int (*read_probe)(AVProbeData *);
int (*read_header)(struct AVFormatContext *);
int (*read_packet)(struct AVFormatContext *, AVPacket *pkt);
int (*read_close)(struct AVFormatContext *);
int (*read_seek)(struct AVFormatContext *,
int stream_index, int64_t timestamp, int flags);
int64_t (*read_timestamp)(struct AVFormatContext *s, int stream_index,
int64_t *pos, int64_t pos_limit);
int (*read_play)(struct AVFormatContext *);
int (*read_pause)(struct AVFormatContext *);
int (*read_seek2)(struct AVFormatContext *s, int stream_index, int64_t min_ts, int64_t ts, int64_t max_ts, int flags);
int (*get_device_list)(struct AVFormatContext *s, struct AVDeviceInfoList *device_list);
int (*create_device_capabilities)(struct AVFormatContext *s, struct AVDeviceCapabilitiesQuery *caps);
int (*free_device_capabilities)(struct AVFormatContext *s, struct AVDeviceCapabilitiesQuery *caps);
} AVInputFormat;
enum AVStreamParseType {
AVSTREAM_PARSE_NONE,
AVSTREAM_PARSE_FULL,
AVSTREAM_PARSE_HEADERS,
AVSTREAM_PARSE_TIMESTAMPS,
AVSTREAM_PARSE_FULL_ONCE,
AVSTREAM_PARSE_FULL_RAW,
};
typedef struct AVIndexEntry {
int64_t pos;
int64_t timestamp;
int flags:2;
int size:30;
int min_distance;
} AVIndexEntry;
typedef struct AVStreamInternal AVStreamInternal;
typedef struct AVStream {
int index;
int id;
__attribute__((deprecated))
AVCodecContext *codec;
void *priv_data;
AVRational time_base;
int64_t start_time;
int64_t duration;
int64_t nb_frames;
int disposition;
enum AVDiscard discard;
AVRational sample_aspect_ratio;
AVDictionary *metadata;
AVRational avg_frame_rate;
AVPacket attached_pic;
AVPacketSideData *side_data;
int nb_side_data;
int event_flags;
AVRational r_frame_rate;
__attribute__((deprecated))
char *recommended_encoder_configuration;
AVCodecParameters *codecpar;
struct {
int64_t last_dts;
int64_t duration_gcd;
int duration_count;
int64_t rfps_duration_sum;
double (*duration_error)[2][(30*12+30+3+6)];
int64_t codec_info_duration;
int64_t codec_info_duration_fields;
int frame_delay_evidence;
int found_decoder;
int64_t last_duration;
int64_t fps_first_dts;
int fps_first_dts_idx;
int64_t fps_last_dts;
int fps_last_dts_idx;
} *info;
int pts_wrap_bits;
int64_t first_dts;
int64_t cur_dts;
int64_t last_IP_pts;
int last_IP_duration;
int probe_packets;
int codec_info_nb_frames;
enum AVStreamParseType need_parsing;
struct AVCodecParserContext *parser;
struct AVPacketList *last_in_packet_buffer;
AVProbeData probe_data;
int64_t pts_buffer[16 +1];
AVIndexEntry *index_entries;
int nb_index_entries;
unsigned int index_entries_allocated_size;
int stream_identifier;
int program_num;
int pmt_version;
int pmt_stream_idx;
int64_t interleaver_chunk_size;
int64_t interleaver_chunk_duration;
int request_probe;
int skip_to_keyframe;
int skip_samples;
int64_t start_skip_samples;
int64_t first_discard_sample;
int64_t last_discard_sample;
int nb_decoded_frames;
int64_t mux_ts_offset;
int64_t pts_wrap_reference;
int pts_wrap_behavior;
int update_initial_durations_done;
int64_t pts_reorder_error[16 +1];
uint8_t pts_reorder_error_count[16 +1];
int64_t last_dts_for_order_check;
uint8_t dts_ordered;
uint8_t dts_misordered;
int inject_global_side_data;
AVRational display_aspect_ratio;
AVStreamInternal *internal;
} AVStream;
__attribute__((deprecated))
AVRational av_stream_get_r_frame_rate(const AVStream *s);
__attribute__((deprecated))
void av_stream_set_r_frame_rate(AVStream *s, AVRational r);
__attribute__((deprecated))
char* av_stream_get_recommended_encoder_configuration(const AVStream *s);
__attribute__((deprecated))
void av_stream_set_recommended_encoder_configuration(AVStream *s, char *configuration);
struct AVCodecParserContext *av_stream_get_parser(const AVStream *s);
int64_t av_stream_get_end_pts(const AVStream *st);
typedef struct AVProgram {
int id;
int flags;
enum AVDiscard discard;
unsigned int *stream_index;
unsigned int nb_stream_indexes;
AVDictionary *metadata;
int program_num;
int pmt_pid;
int pcr_pid;
int pmt_version;
int64_t start_time;
int64_t end_time;
int64_t pts_wrap_reference;
int pts_wrap_behavior;
} AVProgram;
typedef struct AVChapter {
int id;
AVRational time_base;
int64_t start, end;
AVDictionary *metadata;
} AVChapter;
typedef int (*av_format_control_message)(struct AVFormatContext *s, int type,
void *data, size_t data_size);
typedef int (*AVOpenCallback)(struct AVFormatContext *s, AVIOContext **pb, const char *url, int flags,
const AVIOInterruptCB *int_cb, AVDictionary **options);
enum AVDurationEstimationMethod {
AVFMT_DURATION_FROM_PTS,
AVFMT_DURATION_FROM_STREAM,
AVFMT_DURATION_FROM_BITRATE
};
typedef struct AVFormatInternal AVFormatInternal;
typedef struct AVFormatContext {
const AVClass *av_class;
struct AVInputFormat *iformat;
struct AVOutputFormat *oformat;
void *priv_data;
AVIOContext *pb;
int ctx_flags;
unsigned int nb_streams;
AVStream **streams;
__attribute__((deprecated))
char filename[1024];
char *url;
int64_t start_time;
int64_t duration;
int64_t bit_rate;
unsigned int packet_size;
int max_delay;
int flags;
int64_t probesize;
int64_t max_analyze_duration;
const uint8_t *key;
int keylen;
unsigned int nb_programs;
AVProgram **programs;
enum AVCodecID video_codec_id;
enum AVCodecID audio_codec_id;
enum AVCodecID subtitle_codec_id;
unsigned int max_index_size;
unsigned int max_picture_buffer;
unsigned int nb_chapters;
AVChapter **chapters;
AVDictionary *metadata;
int64_t start_time_realtime;
int fps_probe_size;
int error_recognition;
AVIOInterruptCB interrupt_callback;
int debug;
int64_t max_interleave_delta;
int strict_std_compliance;
int event_flags;
int max_ts_probe;
int avoid_negative_ts;
int ts_id;
int audio_preload;
int max_chunk_duration;
int max_chunk_size;
int use_wallclock_as_timestamps;
int avio_flags;
enum AVDurationEstimationMethod duration_estimation_method;
int64_t skip_initial_bytes;
unsigned int correct_ts_overflow;
int seek2any;
int flush_packets;
int probe_score;
int format_probesize;
char *codec_whitelist;
char *format_whitelist;
AVFormatInternal *internal;
int io_repositioned;
AVCodec *video_codec;
AVCodec *audio_codec;
AVCodec *subtitle_codec;
AVCodec *data_codec;
int metadata_header_padding;
void *opaque;
av_format_control_message control_message_cb;
int64_t output_ts_offset;
uint8_t *dump_separator;
enum AVCodecID data_codec_id;
__attribute__((deprecated))
int (*open_cb)(struct AVFormatContext *s, AVIOContext **p, const char *url, int flags, const AVIOInterruptCB *int_cb, AVDictionary **options);
char *protocol_whitelist;
int (*io_open)(struct AVFormatContext *s, AVIOContext **pb, const char *url,
int flags, AVDictionary **options);
void (*io_close)(struct AVFormatContext *s, AVIOContext *pb);
char *protocol_blacklist;
int max_streams;
int skip_estimate_duration_from_pts;
} AVFormatContext;
__attribute__((deprecated))
int av_format_get_probe_score(const AVFormatContext *s);
__attribute__((deprecated))
AVCodec * av_format_get_video_codec(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_video_codec(AVFormatContext *s, AVCodec *c);
__attribute__((deprecated))
AVCodec * av_format_get_audio_codec(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_audio_codec(AVFormatContext *s, AVCodec *c);
__attribute__((deprecated))
AVCodec * av_format_get_subtitle_codec(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_subtitle_codec(AVFormatContext *s, AVCodec *c);
__attribute__((deprecated))
AVCodec * av_format_get_data_codec(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_data_codec(AVFormatContext *s, AVCodec *c);
__attribute__((deprecated))
int av_format_get_metadata_header_padding(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_metadata_header_padding(AVFormatContext *s, int c);
__attribute__((deprecated))
void * av_format_get_opaque(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_opaque(AVFormatContext *s, void *opaque);
__attribute__((deprecated))
av_format_control_message av_format_get_control_message_cb(const AVFormatContext *s);
__attribute__((deprecated))
void av_format_set_control_message_cb(AVFormatContext *s, av_format_control_message callback);
__attribute__((deprecated)) AVOpenCallback av_format_get_open_cb(const AVFormatContext *s);
__attribute__((deprecated)) void av_format_set_open_cb(AVFormatContext *s, AVOpenCallback callback);
void av_format_inject_global_side_data(AVFormatContext *s);
enum AVDurationEstimationMethod av_fmt_ctx_get_duration_estimation_method(const AVFormatContext* ctx);
typedef struct AVPacketList {
AVPacket pkt;
struct AVPacketList *next;
} AVPacketList;
unsigned avformat_version(void);
const char *avformat_configuration(void);
const char *avformat_license(void);
__attribute__((deprecated))
void av_register_all(void);
__attribute__((deprecated))
void av_register_input_format(AVInputFormat *format);
__attribute__((deprecated))
void av_register_output_format(AVOutputFormat *format);
int avformat_network_init(void);
int avformat_network_deinit(void);
__attribute__((deprecated))
AVInputFormat *av_iformat_next(const AVInputFormat *f);
__attribute__((deprecated))
AVOutputFormat *av_oformat_next(const AVOutputFormat *f);
const AVOutputFormat *av_muxer_iterate(void **opaque);
const AVInputFormat *av_demuxer_iterate(void **opaque);
AVFormatContext *avformat_alloc_context(void);
void avformat_free_context(AVFormatContext *s);
const AVClass *avformat_get_class(void);
AVStream *avformat_new_stream(AVFormatContext *s, const AVCodec *c);
int av_stream_add_side_data(AVStream *st, enum AVPacketSideDataType type,
uint8_t *data, size_t size);
uint8_t *av_stream_new_side_data(AVStream *stream,
enum AVPacketSideDataType type, int size);
uint8_t *av_stream_get_side_data(const AVStream *stream,
enum AVPacketSideDataType type, int *size);
AVProgram *av_new_program(AVFormatContext *s, int id);
int avformat_alloc_output_context2(AVFormatContext **ctx, AVOutputFormat *oformat,
const char *format_name, const char *filename);
AVInputFormat *av_find_input_format(const char *short_name);
AVInputFormat *av_probe_input_format(AVProbeData *pd, int is_opened);
AVInputFormat *av_probe_input_format2(AVProbeData *pd, int is_opened, int *score_max);
AVInputFormat *av_probe_input_format3(AVProbeData *pd, int is_opened, int *score_ret);
int av_probe_input_buffer2(AVIOContext *pb, AVInputFormat **fmt,
const char *url, void *logctx,
unsigned int offset, unsigned int max_probe_size);
int av_probe_input_buffer(AVIOContext *pb, AVInputFormat **fmt,
const char *url, void *logctx,
unsigned int offset, unsigned int max_probe_size);
int avformat_open_input(AVFormatContext **ps, const char *url, AVInputFormat *fmt, AVDictionary **options);
__attribute__((deprecated))
int av_demuxer_open(AVFormatContext *ic);
int avformat_find_stream_info(AVFormatContext *ic, AVDictionary **options);
AVProgram *av_find_program_from_stream(AVFormatContext *ic, AVProgram *last, int s);
void av_program_add_stream_index(AVFormatContext *ac, int progid, unsigned int idx);
int av_find_best_stream(AVFormatContext *ic,
enum AVMediaType type,
int wanted_stream_nb,
int related_stream,
AVCodec **decoder_ret,
int flags);
int av_read_frame(AVFormatContext *s, AVPacket *pkt);
int av_seek_frame(AVFormatContext *s, int stream_index, int64_t timestamp,
int flags);
int avformat_seek_file(AVFormatContext *s, int stream_index, int64_t min_ts, int64_t ts, int64_t max_ts, int flags);
int avformat_flush(AVFormatContext *s);
int av_read_play(AVFormatContext *s);
int av_read_pause(AVFormatContext *s);
void avformat_close_input(AVFormatContext **s);
__attribute__((warn_unused_result))
int avformat_write_header(AVFormatContext *s, AVDictionary **options);
__attribute__((warn_unused_result))
int avformat_init_output(AVFormatContext *s, AVDictionary **options);
int av_write_frame(AVFormatContext *s, AVPacket *pkt);
int av_interleaved_write_frame(AVFormatContext *s, AVPacket *pkt);
int av_write_uncoded_frame(AVFormatContext *s, int stream_index,
AVFrame *frame);
int av_interleaved_write_uncoded_frame(AVFormatContext *s, int stream_index,
AVFrame *frame);
int av_write_uncoded_frame_query(AVFormatContext *s, int stream_index);
int av_write_trailer(AVFormatContext *s);
AVOutputFormat *av_guess_format(const char *short_name,
const char *filename,
const char *mime_type);
enum AVCodecID av_guess_codec(AVOutputFormat *fmt, const char *short_name,
const char *filename, const char *mime_type,
enum AVMediaType type);
int av_get_output_timestamp(struct AVFormatContext *s, int stream,
int64_t *dts, int64_t *wall);
void av_hex_dump(FILE *f, const uint8_t *buf, int size);
void av_hex_dump_log(void *avcl, int level, const uint8_t *buf, int size);
void av_pkt_dump2(FILE *f, const AVPacket *pkt, int dump_payload, const AVStream *st);
void av_pkt_dump_log2(void *avcl, int level, const AVPacket *pkt, int dump_payload,
const AVStream *st);
enum AVCodecID av_codec_get_id(const struct AVCodecTag * const *tags, unsigned int tag);
unsigned int av_codec_get_tag(const struct AVCodecTag * const *tags, enum AVCodecID id);
int av_codec_get_tag2(const struct AVCodecTag * const *tags, enum AVCodecID id,
unsigned int *tag);
int av_find_default_stream_index(AVFormatContext *s);
int av_index_search_timestamp(AVStream *st, int64_t timestamp, int flags);
int av_add_index_entry(AVStream *st, int64_t pos, int64_t timestamp,
int size, int distance, int flags);
void av_url_split(char *proto, int proto_size,
char *authorization, int authorization_size,
char *hostname, int hostname_size,
int *port_ptr,
char *path, int path_size,
const char *url);
void av_dump_format(AVFormatContext *ic,
int index,
const char *url,
int is_output);
int av_get_frame_filename2(char *buf, int buf_size,
const char *path, int number, int flags);
int av_get_frame_filename(char *buf, int buf_size,
const char *path, int number);
int av_filename_number_test(const char *filename);
int av_sdp_create(AVFormatContext *ac[], int n_files, char *buf, int size);
int av_match_ext(const char *filename, const char *extensions);
int avformat_query_codec(const AVOutputFormat *ofmt, enum AVCodecID codec_id,
int std_compliance);
const struct AVCodecTag *avformat_get_riff_video_tags(void);
const struct AVCodecTag *avformat_get_riff_audio_tags(void);
const struct AVCodecTag *avformat_get_mov_video_tags(void);
const struct AVCodecTag *avformat_get_mov_audio_tags(void);
AVRational av_guess_sample_aspect_ratio(AVFormatContext *format, AVStream *stream, AVFrame *frame);
AVRational av_guess_frame_rate(AVFormatContext *ctx, AVStream *stream, AVFrame *frame);
int avformat_match_stream_specifier(AVFormatContext *s, AVStream *st,
const char *spec);
int avformat_queue_attached_pictures(AVFormatContext *s);
__attribute__((deprecated))
int av_apply_bitstream_filters(AVCodecContext *codec, AVPacket *pkt,
AVBitStreamFilterContext *bsfc);
enum AVTimebaseSource {
AVFMT_TBCF_AUTO = -1,
AVFMT_TBCF_DECODER,
AVFMT_TBCF_DEMUXER,
AVFMT_TBCF_R_FRAMERATE,
};
int avformat_transfer_internal_stream_timing_info(const AVOutputFormat *ofmt,
AVStream *ost, const AVStream *ist,
enum AVTimebaseSource copy_tb);
AVRational av_stream_get_codec_timebase(const AVStream *st);
typedef struct AVComponentDescriptor {
int plane;
int step;
int offset;
int shift;
int depth;
__attribute__((deprecated)) int step_minus1;
__attribute__((deprecated)) int depth_minus1;
__attribute__((deprecated)) int offset_plus1;
} AVComponentDescriptor;
typedef struct AVPixFmtDescriptor {
const char *name;
uint8_t nb_components;
uint8_t log2_chroma_w;
uint8_t log2_chroma_h;
uint64_t flags;
AVComponentDescriptor comp[4];
const char *alias;
} AVPixFmtDescriptor;
int av_get_bits_per_pixel(const AVPixFmtDescriptor *pixdesc);
int av_get_padded_bits_per_pixel(const AVPixFmtDescriptor *pixdesc);
const AVPixFmtDescriptor *av_pix_fmt_desc_get(enum AVPixelFormat pix_fmt);
const AVPixFmtDescriptor *av_pix_fmt_desc_next(const AVPixFmtDescriptor *prev);
enum AVPixelFormat av_pix_fmt_desc_get_id(const AVPixFmtDescriptor *desc);
int av_pix_fmt_get_chroma_sub_sample(enum AVPixelFormat pix_fmt,
int *h_shift, int *v_shift);
int av_pix_fmt_count_planes(enum AVPixelFormat pix_fmt);
const char *av_color_range_name(enum AVColorRange range);
int av_color_range_from_name(const char *name);
const char *av_color_primaries_name(enum AVColorPrimaries primaries);
int av_color_primaries_from_name(const char *name);
const char *av_color_transfer_name(enum AVColorTransferCharacteristic transfer);
int av_color_transfer_from_name(const char *name);
const char *av_color_space_name(enum AVColorSpace space);
int av_color_space_from_name(const char *name);
const char *av_chroma_location_name(enum AVChromaLocation location);
int av_chroma_location_from_name(const char *name);
enum AVPixelFormat av_get_pix_fmt(const char *name);
const char *av_get_pix_fmt_name(enum AVPixelFormat pix_fmt);
char *av_get_pix_fmt_string(char *buf, int buf_size,
enum AVPixelFormat pix_fmt);
void av_read_image_line2(void *dst, const uint8_t *data[4],
const int linesize[4], const AVPixFmtDescriptor *desc,
int x, int y, int c, int w, int read_pal_component,
int dst_element_size);
void av_read_image_line(uint16_t *dst, const uint8_t *data[4],
const int linesize[4], const AVPixFmtDescriptor *desc,
int x, int y, int c, int w, int read_pal_component);
void av_write_image_line2(const void *src, uint8_t *data[4],
const int linesize[4], const AVPixFmtDescriptor *desc,
int x, int y, int c, int w, int src_element_size);
void av_write_image_line(const uint16_t *src, uint8_t *data[4],
const int linesize[4], const AVPixFmtDescriptor *desc,
int x, int y, int c, int w);
enum AVPixelFormat av_pix_fmt_swap_endianness(enum AVPixelFormat pix_fmt);
int av_get_pix_fmt_loss(enum AVPixelFormat dst_pix_fmt,
enum AVPixelFormat src_pix_fmt,
int has_alpha);
enum AVPixelFormat av_find_best_pix_fmt_of_2(enum AVPixelFormat dst_pix_fmt1, enum AVPixelFormat dst_pix_fmt2,
enum AVPixelFormat src_pix_fmt, int has_alpha, int *loss_ptr);
void av_image_fill_max_pixsteps(int max_pixsteps[4], int max_pixstep_comps[4],
const AVPixFmtDescriptor *pixdesc);
int av_image_get_linesize(enum AVPixelFormat pix_fmt, int width, int plane);
int av_image_fill_linesizes(int linesizes[4], enum AVPixelFormat pix_fmt, int width);
int av_image_fill_pointers(uint8_t *data[4], enum AVPixelFormat pix_fmt, int height,
uint8_t *ptr, const int linesizes[4]);
int av_image_alloc(uint8_t *pointers[4], int linesizes[4],
int w, int h, enum AVPixelFormat pix_fmt, int align);
void av_image_copy_plane(uint8_t *dst, int dst_linesize,
const uint8_t *src, int src_linesize,
int bytewidth, int height);
void av_image_copy(uint8_t *dst_data[4], int dst_linesizes[4],
const uint8_t *src_data[4], const int src_linesizes[4],
enum AVPixelFormat pix_fmt, int width, int height);
void av_image_copy_uc_from(uint8_t *dst_data[4], const ptrdiff_t dst_linesizes[4],
const uint8_t *src_data[4], const ptrdiff_t src_linesizes[4],
enum AVPixelFormat pix_fmt, int width, int height);
int av_image_fill_arrays(uint8_t *dst_data[4], int dst_linesize[4],
const uint8_t *src,
enum AVPixelFormat pix_fmt, int width, int height, int align);
int av_image_get_buffer_size(enum AVPixelFormat pix_fmt, int width, int height, int align);
int av_image_copy_to_buffer(uint8_t *dst, int dst_size,
const uint8_t * const src_data[4], const int src_linesize[4],
enum AVPixelFormat pix_fmt, int width, int height, int align);
int av_image_check_size(unsigned int w, unsigned int h, int log_offset, void *log_ctx);
int av_image_check_size2(unsigned int w, unsigned int h, int64_t max_pixels, enum AVPixelFormat pix_fmt, int log_offset, void *log_ctx);
int av_image_check_sar(unsigned int w, unsigned int h, AVRational sar);
int av_image_fill_black(uint8_t *dst_data[4], const ptrdiff_t dst_linesize[4],
enum AVPixelFormat pix_fmt, enum AVColorRange range,
int width, int height);
unsigned swscale_version(void);
const char *swscale_configuration(void);
const char *swscale_license(void);
const int *sws_getCoefficients(int colorspace);
typedef struct SwsVector {
double *coeff;
int length;
} SwsVector;
typedef struct SwsFilter {
SwsVector *lumH;
SwsVector *lumV;
SwsVector *chrH;
SwsVector *chrV;
} SwsFilter;
struct SwsContext;
int sws_isSupportedInput(enum AVPixelFormat pix_fmt);
int sws_isSupportedOutput(enum AVPixelFormat pix_fmt);
int sws_isSupportedEndiannessConversion(enum AVPixelFormat pix_fmt);
struct SwsContext *sws_alloc_context(void);
__attribute__((warn_unused_result))
int sws_init_context(struct SwsContext *sws_context, SwsFilter *srcFilter, SwsFilter *dstFilter);
void sws_freeContext(struct SwsContext *swsContext);
struct SwsContext *sws_getContext(int srcW, int srcH, enum AVPixelFormat srcFormat,
int dstW, int dstH, enum AVPixelFormat dstFormat,
int flags, SwsFilter *srcFilter,
SwsFilter *dstFilter, const double *param);
int sws_scale(struct SwsContext *c, const uint8_t *const srcSlice[],
const int srcStride[], int srcSliceY, int srcSliceH,
uint8_t *const dst[], const int dstStride[]);
int sws_setColorspaceDetails(struct SwsContext *c, const int inv_table[4],
int srcRange, const int table[4], int dstRange,
int brightness, int contrast, int saturation);
int sws_getColorspaceDetails(struct SwsContext *c, int **inv_table,
int *srcRange, int **table, int *dstRange,
int *brightness, int *contrast, int *saturation);
SwsVector *sws_allocVec(int length);
SwsVector *sws_getGaussianVec(double variance, double quality);
void sws_scaleVec(SwsVector *a, double scalar);
void sws_normalizeVec(SwsVector *a, double height);
__attribute__((deprecated)) SwsVector *sws_getConstVec(double c, int length);
__attribute__((deprecated)) SwsVector *sws_getIdentityVec(void);
__attribute__((deprecated)) void sws_convVec(SwsVector *a, SwsVector *b);
__attribute__((deprecated)) void sws_addVec(SwsVector *a, SwsVector *b);
__attribute__((deprecated)) void sws_subVec(SwsVector *a, SwsVector *b);
__attribute__((deprecated)) void sws_shiftVec(SwsVector *a, int shift);
__attribute__((deprecated)) SwsVector *sws_cloneVec(SwsVector *a);
__attribute__((deprecated)) void sws_printVec2(SwsVector *a, AVClass *log_ctx, int log_level);
void sws_freeVec(SwsVector *a);
SwsFilter *sws_getDefaultFilter(float lumaGBlur, float chromaGBlur,
float lumaSharpen, float chromaSharpen,
float chromaHShift, float chromaVShift,
int verbose);
void sws_freeFilter(SwsFilter *filter);
struct SwsContext *sws_getCachedContext(struct SwsContext *context,
int srcW, int srcH, enum AVPixelFormat srcFormat,
int dstW, int dstH, enum AVPixelFormat dstFormat,
int flags, SwsFilter *srcFilter,
SwsFilter *dstFilter, const double *param);
void sws_convertPalette8ToPacked32(const uint8_t *src, uint8_t *dst, int num_pixels, const uint8_t *palette);
void sws_convertPalette8ToPacked24(const uint8_t *src, uint8_t *dst, int num_pixels, const uint8_t *palette);
const AVClass *sws_get_class(void);
typedef uint8_t BYTE;
typedef uint16_t WORD;
typedef uint32_t DWORD;
typedef uint64_t QWORD;
typedef int BOOL;
typedef DWORD HMUSIC;
typedef DWORD HSAMPLE;
typedef DWORD HCHANNEL;
typedef DWORD HSTREAM;
typedef DWORD HRECORD;
typedef DWORD HSYNC;
typedef DWORD HDSP;
typedef DWORD HFX;
typedef DWORD HPLUGIN;
typedef struct {
const char *name;
const char *driver;
DWORD flags;
} BASS_DEVICEINFO;
typedef struct {
DWORD flags;
DWORD hwsize;
DWORD hwfree;
DWORD freesam;
DWORD free3d;
DWORD minrate;
DWORD maxrate;
BOOL eax;
DWORD minbuf;
DWORD dsver;
DWORD latency;
DWORD initflags;
DWORD speakers;
DWORD freq;
} BASS_INFO;
typedef struct {
DWORD flags;
DWORD formats;
DWORD inputs;
BOOL singlein;
DWORD freq;
} BASS_RECORDINFO;
typedef struct {
DWORD freq;
float volume;
float pan;
DWORD flags;
DWORD length;
DWORD max;
DWORD origres;
DWORD chans;
DWORD mingap;
DWORD mode3d;
float mindist;
float maxdist;
DWORD iangle;
DWORD oangle;
float outvol;
DWORD vam;
DWORD priority;
} BASS_SAMPLE;
typedef struct {
DWORD freq;
DWORD chans;
DWORD flags;
DWORD ctype;
DWORD origres;
HPLUGIN plugin;
HSAMPLE sample;
const char *filename;
} BASS_CHANNELINFO;
typedef struct {
DWORD ctype;
const char *name;
const char *exts;
} BASS_PLUGINFORM;
typedef struct {
DWORD version;
DWORD formatc;
const BASS_PLUGINFORM *formats;
} BASS_PLUGININFO;
typedef struct BASS_3DVECTOR {
float x;
float y;
float z;
} BASS_3DVECTOR;
enum
{
EAX_ENVIRONMENT_GENERIC,
EAX_ENVIRONMENT_PADDEDCELL,
EAX_ENVIRONMENT_ROOM,
EAX_ENVIRONMENT_BATHROOM,
EAX_ENVIRONMENT_LIVINGROOM,
EAX_ENVIRONMENT_STONEROOM,
EAX_ENVIRONMENT_AUDITORIUM,
EAX_ENVIRONMENT_CONCERTHALL,
EAX_ENVIRONMENT_CAVE,
EAX_ENVIRONMENT_ARENA,
EAX_ENVIRONMENT_HANGAR,
EAX_ENVIRONMENT_CARPETEDHALLWAY,
EAX_ENVIRONMENT_HALLWAY,
EAX_ENVIRONMENT_STONECORRIDOR,
EAX_ENVIRONMENT_ALLEY,
EAX_ENVIRONMENT_FOREST,
EAX_ENVIRONMENT_CITY,
EAX_ENVIRONMENT_MOUNTAINS,
EAX_ENVIRONMENT_QUARRY,
EAX_ENVIRONMENT_PLAIN,
EAX_ENVIRONMENT_PARKINGLOT,
EAX_ENVIRONMENT_SEWERPIPE,
EAX_ENVIRONMENT_UNDERWATER,
EAX_ENVIRONMENT_DRUGGED,
EAX_ENVIRONMENT_DIZZY,
EAX_ENVIRONMENT_PSYCHOTIC,
EAX_ENVIRONMENT_COUNT
};
typedef DWORD ( STREAMPROC)(HSTREAM handle, void *buffer, DWORD length, void *user);
typedef void ( FILECLOSEPROC)(void *user);
typedef QWORD ( FILELENPROC)(void *user);
typedef DWORD ( FILEREADPROC)(void *buffer, DWORD length, void *user);
typedef BOOL ( FILESEEKPROC)(QWORD offset, void *user);
typedef struct {
FILECLOSEPROC *close;
FILELENPROC *length;
FILEREADPROC *read;
FILESEEKPROC *seek;
} BASS_FILEPROCS;
typedef void ( DOWNLOADPROC)(const void *buffer, DWORD length, void *user);
typedef void ( SYNCPROC)(HSYNC handle, DWORD channel, DWORD data, void *user);
typedef void ( DSPPROC)(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);
typedef BOOL ( RECORDPROC)(HRECORD handle, const void *buffer, DWORD length, void *user);
typedef struct {
char id[3];
char title[30];
char artist[30];
char album[30];
char year[4];
char comment[30];
BYTE genre;
} TAG_ID3;
typedef struct {
const char *key;
const void *data;
DWORD length;
} TAG_APE_BINARY;
typedef struct {
char Description[256];
char Originator[32];
char OriginatorReference[32];
char OriginationDate[10];
char OriginationTime[8];
QWORD TimeReference;
WORD Version;
BYTE UMID[64];
BYTE Reserved[190];
char CodingHistory[];
} TAG_BEXT;
typedef struct
{
DWORD dwUsage;
DWORD dwValue;
} TAG_CART_TIMER;
typedef struct
{
char Version[4];
char Title[64];
char Artist[64];
char CutID[64];
char ClientID[64];
char Category[64];
char Classification[64];
char OutCue[64];
char StartDate[10];
char StartTime[8];
char EndDate[10];
char EndTime[8];
char ProducerAppID[64];
char ProducerAppVersion[64];
char UserDef[64];
DWORD dwLevelReference;
TAG_CART_TIMER PostTimer[8];
char Reserved[276];
char URL[1024];
char TagText[];
} TAG_CART;
typedef struct
{
DWORD dwName;
DWORD dwPosition;
DWORD fccChunk;
DWORD dwChunkStart;
DWORD dwBlockStart;
DWORD dwSampleOffset;
} TAG_CUE_POINT;
typedef struct
{
DWORD dwCuePoints;
TAG_CUE_POINT CuePoints[];
} TAG_CUE;
typedef struct
{
DWORD dwIdentifier;
DWORD dwType;
DWORD dwStart;
DWORD dwEnd;
DWORD dwFraction;
DWORD dwPlayCount;
} TAG_SMPL_LOOP;
typedef struct
{
DWORD dwManufacturer;
DWORD dwProduct;
DWORD dwSamplePeriod;
DWORD dwMIDIUnityNote;
DWORD dwMIDIPitchFraction;
DWORD dwSMPTEFormat;
DWORD dwSMPTEOffset;
DWORD cSampleLoops;
DWORD cbSamplerData;
TAG_SMPL_LOOP SampleLoops[];
} TAG_SMPL;
typedef struct {
DWORD ftype;
DWORD atype;
const char *name;
} TAG_CA_CODEC;
typedef struct tWAVEFORMATEX
{
WORD wFormatTag;
WORD nChannels;
DWORD nSamplesPerSec;
DWORD nAvgBytesPerSec;
WORD nBlockAlign;
WORD wBitsPerSample;
WORD cbSize;
} WAVEFORMATEX, *PWAVEFORMATEX, *LPWAVEFORMATEX;
typedef const WAVEFORMATEX *LPCWAVEFORMATEX;
typedef struct {
float fWetDryMix;
float fDepth;
float fFeedback;
float fFrequency;
DWORD lWaveform;
float fDelay;
DWORD lPhase;
} BASS_DX8_CHORUS;
typedef struct {
float fGain;
float fAttack;
float fRelease;
float fThreshold;
float fRatio;
float fPredelay;
} BASS_DX8_COMPRESSOR;
typedef struct {
float fGain;
float fEdge;
float fPostEQCenterFrequency;
float fPostEQBandwidth;
float fPreLowpassCutoff;
} BASS_DX8_DISTORTION;
typedef struct {
float fWetDryMix;
float fFeedback;
float fLeftDelay;
float fRightDelay;
BOOL lPanDelay;
} BASS_DX8_ECHO;
typedef struct {
float fWetDryMix;
float fDepth;
float fFeedback;
float fFrequency;
DWORD lWaveform;
float fDelay;
DWORD lPhase;
} BASS_DX8_FLANGER;
typedef struct {
DWORD dwRateHz;
DWORD dwWaveShape;
} BASS_DX8_GARGLE;
typedef struct {
int lRoom;
int lRoomHF;
float flRoomRolloffFactor;
float flDecayTime;
float flDecayHFRatio;
int lReflections;
float flReflectionsDelay;
int lReverb;
float flReverbDelay;
float flDiffusion;
float flDensity;
float flHFReference;
} BASS_DX8_I3DL2REVERB;
typedef struct {
float fCenter;
float fBandwidth;
float fGain;
} BASS_DX8_PARAMEQ;
typedef struct {
float fInGain;
float fReverbMix;
float fReverbTime;
float fHighFreqRTRatio;
} BASS_DX8_REVERB;
typedef struct {
float fTarget;
float fCurrent;
float fTime;
DWORD lCurve;
} BASS_FX_VOLUME_PARAM;
typedef void ( IOSNOTIFYPROC)(DWORD status);
BOOL BASS_SetConfig(DWORD option, DWORD value);
DWORD BASS_GetConfig(DWORD option);
BOOL BASS_SetConfigPtr(DWORD option, const void *value);
void * BASS_GetConfigPtr(DWORD option);
DWORD BASS_GetVersion();
int BASS_ErrorGetCode();
BOOL BASS_GetDeviceInfo(DWORD device, BASS_DEVICEINFO *info);
BOOL BASS_Init(int device, DWORD freq, DWORD flags, void *win, void *dsguid);
BOOL BASS_SetDevice(DWORD device);
DWORD BASS_GetDevice();
BOOL BASS_Free();
BOOL BASS_GetInfo(BASS_INFO *info);
BOOL BASS_Update(DWORD length);
float BASS_GetCPU();
BOOL BASS_Start();
BOOL BASS_Stop();
BOOL BASS_Pause();
BOOL BASS_SetVolume(float volume);
float BASS_GetVolume();
HPLUGIN BASS_PluginLoad(const char *file, DWORD flags);
BOOL BASS_PluginFree(HPLUGIN handle);
const BASS_PLUGININFO * BASS_PluginGetInfo(HPLUGIN handle);
BOOL BASS_Set3DFactors(float distf, float rollf, float doppf);
BOOL BASS_Get3DFactors(float *distf, float *rollf, float *doppf);
BOOL BASS_Set3DPosition(const BASS_3DVECTOR *pos, const BASS_3DVECTOR *vel, const BASS_3DVECTOR *front, const BASS_3DVECTOR *top);
BOOL BASS_Get3DPosition(BASS_3DVECTOR *pos, BASS_3DVECTOR *vel, BASS_3DVECTOR *front, BASS_3DVECTOR *top);
void BASS_Apply3D();
HMUSIC BASS_MusicLoad(BOOL mem, const void *file, QWORD offset, DWORD length, DWORD flags, DWORD freq);
BOOL BASS_MusicFree(HMUSIC handle);
HSAMPLE BASS_SampleLoad(BOOL mem, const void *file, QWORD offset, DWORD length, DWORD max, DWORD flags);
HSAMPLE BASS_SampleCreate(DWORD length, DWORD freq, DWORD chans, DWORD max, DWORD flags);
BOOL BASS_SampleFree(HSAMPLE handle);
BOOL BASS_SampleSetData(HSAMPLE handle, const void *buffer);
BOOL BASS_SampleGetData(HSAMPLE handle, void *buffer);
BOOL BASS_SampleGetInfo(HSAMPLE handle, BASS_SAMPLE *info);
BOOL BASS_SampleSetInfo(HSAMPLE handle, const BASS_SAMPLE *info);
HCHANNEL BASS_SampleGetChannel(HSAMPLE handle, BOOL onlynew);
DWORD BASS_SampleGetChannels(HSAMPLE handle, HCHANNEL *channels);
BOOL BASS_SampleStop(HSAMPLE handle);
HSTREAM BASS_StreamCreate(DWORD freq, DWORD chans, DWORD flags, STREAMPROC *proc, void *user);
HSTREAM BASS_StreamCreateFile(BOOL mem, const void *file, QWORD offset, QWORD length, DWORD flags);
HSTREAM BASS_StreamCreateURL(const char *url, DWORD offset, DWORD flags, DOWNLOADPROC *proc, void *user);
HSTREAM BASS_StreamCreateFileUser(DWORD system, DWORD flags, const BASS_FILEPROCS *proc, void *user);
BOOL BASS_StreamFree(HSTREAM handle);
QWORD BASS_StreamGetFilePosition(HSTREAM handle, DWORD mode);
DWORD BASS_StreamPutData(HSTREAM handle, const void *buffer, DWORD length);
DWORD BASS_StreamPutFileData(HSTREAM handle, const void *buffer, DWORD length);
BOOL BASS_RecordGetDeviceInfo(DWORD device, BASS_DEVICEINFO *info);
BOOL BASS_RecordInit(int device);
BOOL BASS_RecordSetDevice(DWORD device);
DWORD BASS_RecordGetDevice();
BOOL BASS_RecordFree();
BOOL BASS_RecordGetInfo(BASS_RECORDINFO *info);
const char * BASS_RecordGetInputName(int input);
BOOL BASS_RecordSetInput(int input, DWORD flags, float volume);
DWORD BASS_RecordGetInput(int input, float *volume);
HRECORD BASS_RecordStart(DWORD freq, DWORD chans, DWORD flags, RECORDPROC *proc, void *user);
double BASS_ChannelBytes2Seconds(DWORD handle, QWORD pos);
QWORD BASS_ChannelSeconds2Bytes(DWORD handle, double pos);
DWORD BASS_ChannelGetDevice(DWORD handle);
BOOL BASS_ChannelSetDevice(DWORD handle, DWORD device);
DWORD BASS_ChannelIsActive(DWORD handle);
BOOL BASS_ChannelGetInfo(DWORD handle, BASS_CHANNELINFO *info);
const char * BASS_ChannelGetTags(DWORD handle, DWORD tags);
DWORD BASS_ChannelFlags(DWORD handle, DWORD flags, DWORD mask);
BOOL BASS_ChannelUpdate(DWORD handle, DWORD length);
BOOL BASS_ChannelLock(DWORD handle, BOOL lock);
BOOL BASS_ChannelPlay(DWORD handle, BOOL restart);
BOOL BASS_ChannelStop(DWORD handle);
BOOL BASS_ChannelPause(DWORD handle);
BOOL BASS_ChannelSetAttribute(DWORD handle, DWORD attrib, float value);
BOOL BASS_ChannelGetAttribute(DWORD handle, DWORD attrib, float *value);
BOOL BASS_ChannelSlideAttribute(DWORD handle, DWORD attrib, float value, DWORD time);
BOOL BASS_ChannelIsSliding(DWORD handle, DWORD attrib);
BOOL BASS_ChannelSetAttributeEx(DWORD handle, DWORD attrib, void *value, DWORD size);
DWORD BASS_ChannelGetAttributeEx(DWORD handle, DWORD attrib, void *value, DWORD size);
BOOL BASS_ChannelSet3DAttributes(DWORD handle, int mode, float min, float max, int iangle, int oangle, float outvol);
BOOL BASS_ChannelGet3DAttributes(DWORD handle, DWORD *mode, float *min, float *max, DWORD *iangle, DWORD *oangle, float *outvol);
BOOL BASS_ChannelSet3DPosition(DWORD handle, const BASS_3DVECTOR *pos, const BASS_3DVECTOR *orient, const BASS_3DVECTOR *vel);
BOOL BASS_ChannelGet3DPosition(DWORD handle, BASS_3DVECTOR *pos, BASS_3DVECTOR *orient, BASS_3DVECTOR *vel);
QWORD BASS_ChannelGetLength(DWORD handle, DWORD mode);
BOOL BASS_ChannelSetPosition(DWORD handle, QWORD pos, DWORD mode);
QWORD BASS_ChannelGetPosition(DWORD handle, DWORD mode);
DWORD BASS_ChannelGetLevel(DWORD handle);
BOOL BASS_ChannelGetLevelEx(DWORD handle, float *levels, float length, DWORD flags);
DWORD BASS_ChannelGetData(DWORD handle, void *buffer, DWORD length);
HSYNC BASS_ChannelSetSync(DWORD handle, DWORD type, QWORD param, SYNCPROC *proc, void *user);
BOOL BASS_ChannelRemoveSync(DWORD handle, HSYNC sync);
HDSP BASS_ChannelSetDSP(DWORD handle, DSPPROC *proc, void *user, int priority);
BOOL BASS_ChannelRemoveDSP(DWORD handle, HDSP dsp);
BOOL BASS_ChannelSetLink(DWORD handle, DWORD chan);
BOOL BASS_ChannelRemoveLink(DWORD handle, DWORD chan);
HFX BASS_ChannelSetFX(DWORD handle, DWORD type, int priority);
BOOL BASS_ChannelRemoveFX(DWORD handle, HFX fx);
BOOL BASS_FXSetParameters(HFX handle, const void *params);
BOOL BASS_FXGetParameters(HFX handle, void *params);
BOOL BASS_FXReset(HFX handle);
BOOL BASS_FXSetPriority(HFX handle, int priority);
DWORD BASS_FX_GetVersion();
enum {
BASS_FX_BFX_ROTATE = 0x10000,
BASS_FX_BFX_ECHO,
BASS_FX_BFX_FLANGER,
BASS_FX_BFX_VOLUME,
BASS_FX_BFX_PEAKEQ,
BASS_FX_BFX_REVERB,
BASS_FX_BFX_LPF,
BASS_FX_BFX_MIX,
BASS_FX_BFX_DAMP,
BASS_FX_BFX_AUTOWAH,
BASS_FX_BFX_ECHO2,
BASS_FX_BFX_PHASER,
BASS_FX_BFX_ECHO3,
BASS_FX_BFX_CHORUS,
BASS_FX_BFX_APF,
BASS_FX_BFX_COMPRESSOR,
BASS_FX_BFX_DISTORTION,
BASS_FX_BFX_COMPRESSOR2,
BASS_FX_BFX_VOLUME_ENV,
BASS_FX_BFX_BQF,
BASS_FX_BFX_ECHO4,
BASS_FX_BFX_PITCHSHIFT,
BASS_FX_BFX_FREEVERB
};
typedef struct {
float fRate;
int lChannel;
} BASS_BFX_ROTATE;
typedef struct {
float fLevel;
int lDelay;
} BASS_BFX_ECHO;
typedef struct {
float fWetDry;
float fSpeed;
int lChannel;
} BASS_BFX_FLANGER;
typedef struct {
int lChannel;
float fVolume;
} BASS_BFX_VOLUME;
typedef struct {
int lBand;
float fBandwidth;
float fQ;
float fCenter;
float fGain;
int lChannel;
} BASS_BFX_PEAKEQ;
typedef struct {
float fLevel;
int lDelay;
} BASS_BFX_REVERB;
typedef struct {
float fResonance;
float fCutOffFreq;
int lChannel;
} BASS_BFX_LPF;
typedef struct {
const int *lChannel;
} BASS_BFX_MIX;
typedef struct {
float fTarget;
float fQuiet;
float fRate;
float fGain;
float fDelay;
int lChannel;
} BASS_BFX_DAMP;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fRate;
float fRange;
float fFreq;
int lChannel;
} BASS_BFX_AUTOWAH;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fDelay;
int lChannel;
} BASS_BFX_ECHO2;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fRate;
float fRange;
float fFreq;
int lChannel;
} BASS_BFX_PHASER;
typedef struct {
float fDryMix;
float fWetMix;
float fDelay;
int lChannel;
} BASS_BFX_ECHO3;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fMinSweep;
float fMaxSweep;
float fRate;
int lChannel;
} BASS_BFX_CHORUS;
typedef struct {
float fGain;
float fDelay;
int lChannel;
} BASS_BFX_APF;
typedef struct {
float fThreshold;
float fAttacktime;
float fReleasetime;
int lChannel;
} BASS_BFX_COMPRESSOR;
typedef struct {
float fDrive;
float fDryMix;
float fWetMix;
float fFeedback;
float fVolume;
int lChannel;
} BASS_BFX_DISTORTION;
typedef struct {
float fGain;
float fThreshold;
float fRatio;
float fAttack;
float fRelease;
int lChannel;
} BASS_BFX_COMPRESSOR2;
typedef struct {
int lChannel;
int lNodeCount;
const struct BASS_BFX_ENV_NODE *pNodes;
BOOL bFollow;
} BASS_BFX_VOLUME_ENV;
typedef struct BASS_BFX_ENV_NODE {
double pos;
float val;
} BASS_BFX_ENV_NODE;
enum {
BASS_BFX_BQF_LOWPASS,
BASS_BFX_BQF_HIGHPASS,
BASS_BFX_BQF_BANDPASS,
BASS_BFX_BQF_BANDPASS_Q,
BASS_BFX_BQF_NOTCH,
BASS_BFX_BQF_ALLPASS,
BASS_BFX_BQF_PEAKINGEQ,
BASS_BFX_BQF_LOWSHELF,
BASS_BFX_BQF_HIGHSHELF
};
typedef struct {
int lFilter;
float fCenter;
float fGain;
float fBandwidth;
float fQ;
float fS;
int lChannel;
} BASS_BFX_BQF;
typedef struct {
float fDryMix;
float fWetMix;
float fFeedback;
float fDelay;
BOOL bStereo;
int lChannel;
} BASS_BFX_ECHO4;
typedef struct {
float fPitchShift;
float fSemitones;
long lFFTsize;
long lOsamp;
int lChannel;
} BASS_BFX_PITCHSHIFT;
typedef struct {
float fDryMix;
float fWetMix;
float fRoomSize;
float fDamp;
float fWidth;
DWORD lMode;
int lChannel;
} BASS_BFX_FREEVERB;
enum {
BASS_ATTRIB_TEMPO = 0x10000,
BASS_ATTRIB_TEMPO_PITCH,
BASS_ATTRIB_TEMPO_FREQ
};
enum {
BASS_ATTRIB_TEMPO_OPTION_USE_AA_FILTER = 0x10010,
BASS_ATTRIB_TEMPO_OPTION_AA_FILTER_LENGTH,
BASS_ATTRIB_TEMPO_OPTION_USE_QUICKALGO,
BASS_ATTRIB_TEMPO_OPTION_SEQUENCE_MS,
BASS_ATTRIB_TEMPO_OPTION_SEEKWINDOW_MS,
BASS_ATTRIB_TEMPO_OPTION_OVERLAP_MS,
BASS_ATTRIB_TEMPO_OPTION_PREVENT_CLICK
};
HSTREAM BASS_FX_TempoCreate(DWORD chan, DWORD flags);
DWORD BASS_FX_TempoGetSource(HSTREAM chan);
float BASS_FX_TempoGetRateRatio(HSTREAM chan);
HSTREAM BASS_FX_ReverseCreate(DWORD chan, float dec_block, DWORD flags);
DWORD BASS_FX_ReverseGetSource(HSTREAM chan);
enum {
BASS_FX_BPM_TRAN_X2,
BASS_FX_BPM_TRAN_2FREQ,
BASS_FX_BPM_TRAN_FREQ2,
BASS_FX_BPM_TRAN_2PERCENT,
BASS_FX_BPM_TRAN_PERCENT2
};
typedef void ( BPMPROC)(DWORD chan, float bpm, void *user);
typedef void ( BPMPROGRESSPROC)(DWORD chan, float percent, void *user);
typedef BPMPROGRESSPROC BPMPROCESSPROC;
float BASS_FX_BPM_DecodeGet(DWORD chan, double startSec, double endSec, DWORD minMaxBPM, DWORD flags, BPMPROGRESSPROC *proc, void *user);
BOOL BASS_FX_BPM_CallbackSet(DWORD handle, BPMPROC *proc, double period, DWORD minMaxBPM, DWORD flags, void *user);
BOOL BASS_FX_BPM_CallbackReset(DWORD handle);
float BASS_FX_BPM_Translate(DWORD handle, float val2tran, DWORD trans);
BOOL BASS_FX_BPM_Free(DWORD handle);
typedef void ( BPMBEATPROC)(DWORD chan, double beatpos, void *user);
BOOL BASS_FX_BPM_BeatCallbackSet(DWORD handle, BPMBEATPROC *proc, void *user);
BOOL BASS_FX_BPM_BeatCallbackReset(DWORD handle);
BOOL BASS_FX_BPM_BeatDecodeGet(DWORD chan, double startSec, double endSec, DWORD flags, BPMBEATPROC *proc, void *user);
BOOL BASS_FX_BPM_BeatSetParameters(DWORD handle, float bandwidth, float centerfreq, float beat_rtime);
BOOL BASS_FX_BPM_BeatGetParameters(DWORD handle, float *bandwidth, float *centerfreq, float *beat_rtime);
BOOL BASS_FX_BPM_BeatFree(DWORD handle);
]])
