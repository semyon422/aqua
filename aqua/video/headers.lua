return [[
typedef unsigned char __u_char;
typedef unsigned short int __u_short;
typedef unsigned int __u_int;
typedef unsigned long int __u_long;
typedef signed char __int8_t;
typedef unsigned char __uint8_t;
typedef signed short int __int16_t;
typedef unsigned short int __uint16_t;
typedef signed int __int32_t;
typedef unsigned int __uint32_t;
typedef signed long int __int64_t;
typedef unsigned long int __uint64_t;
typedef __int8_t __int_least8_t;
typedef __uint8_t __uint_least8_t;
typedef __int16_t __int_least16_t;
typedef __uint16_t __uint_least16_t;
typedef __int32_t __int_least32_t;
typedef __uint32_t __uint_least32_t;
typedef __int64_t __int_least64_t;
typedef __uint64_t __uint_least64_t;
typedef long int __quad_t;
typedef unsigned long int __u_quad_t;
typedef long int __intmax_t;
typedef unsigned long int __uintmax_t;
typedef unsigned long int __dev_t;
typedef unsigned int __uid_t;
typedef unsigned int __gid_t;
typedef unsigned long int __ino_t;
typedef unsigned long int __ino64_t;
typedef unsigned int __mode_t;
typedef unsigned long int __nlink_t;
typedef long int __off_t;
typedef long int __off64_t;
typedef int __pid_t;
typedef struct { int __val[2]; } __fsid_t;
typedef long int __clock_t;
typedef unsigned long int __rlim_t;
typedef unsigned long int __rlim64_t;
typedef unsigned int __id_t;
typedef long int __time_t;
typedef unsigned int __useconds_t;
typedef long int __suseconds_t;
typedef long int __suseconds64_t;
typedef int __daddr_t;
typedef int __key_t;
typedef int __clockid_t;
typedef void * __timer_t;
typedef long int __blksize_t;
typedef long int __blkcnt_t;
typedef long int __blkcnt64_t;
typedef unsigned long int __fsblkcnt_t;
typedef unsigned long int __fsblkcnt64_t;
typedef unsigned long int __fsfilcnt_t;
typedef unsigned long int __fsfilcnt64_t;
typedef long int __fsword_t;
typedef long int __ssize_t;
typedef long int __syscall_slong_t;
typedef unsigned long int __syscall_ulong_t;
typedef __off64_t __loff_t;
typedef char *__caddr_t;
typedef long int __intptr_t;
typedef unsigned int __socklen_t;
typedef int __sig_atomic_t;
typedef float float_t;
typedef double double_t;
extern int __fpclassify (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __signbit (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __isinf (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __finite (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __isnan (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __iseqsig (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern int __issignaling (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern double acos (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __acos (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double asin (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __asin (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double atan (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __atan (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double atan2 (double __y, double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __atan2 (double __y, double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double cos (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __cos (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double sin (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __sin (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double tan (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __tan (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double cosh (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __cosh (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double sinh (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __sinh (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double tanh (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __tanh (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double acosh (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __acosh (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double asinh (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __asinh (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double atanh (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __atanh (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double exp (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __exp (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double frexp (double __x, int *__exponent) __attribute__ ((__nothrow__ , __leaf__)); extern double __frexp (double __x, int *__exponent) __attribute__ ((__nothrow__ , __leaf__));
extern double ldexp (double __x, int __exponent) __attribute__ ((__nothrow__ , __leaf__)); extern double __ldexp (double __x, int __exponent) __attribute__ ((__nothrow__ , __leaf__));
extern double log (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __log (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double log10 (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __log10 (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double modf (double __x, double *__iptr) __attribute__ ((__nothrow__ , __leaf__)); extern double __modf (double __x, double *__iptr) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern double expm1 (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __expm1 (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double log1p (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __log1p (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double logb (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __logb (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double exp2 (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __exp2 (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double log2 (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __log2 (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double pow (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __pow (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double sqrt (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __sqrt (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double hypot (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __hypot (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double cbrt (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __cbrt (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double ceil (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __ceil (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double fabs (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __fabs (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double floor (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __floor (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double fmod (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __fmod (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern int isinf (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int finite (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern double drem (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __drem (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double significand (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __significand (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double copysign (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __copysign (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double nan (const char *__tagb) __attribute__ ((__nothrow__ , __leaf__)); extern double __nan (const char *__tagb) __attribute__ ((__nothrow__ , __leaf__));
extern int isnan (double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern double j0 (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __j0 (double) __attribute__ ((__nothrow__ , __leaf__));
extern double j1 (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __j1 (double) __attribute__ ((__nothrow__ , __leaf__));
extern double jn (int, double) __attribute__ ((__nothrow__ , __leaf__)); extern double __jn (int, double) __attribute__ ((__nothrow__ , __leaf__));
extern double y0 (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __y0 (double) __attribute__ ((__nothrow__ , __leaf__));
extern double y1 (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __y1 (double) __attribute__ ((__nothrow__ , __leaf__));
extern double yn (int, double) __attribute__ ((__nothrow__ , __leaf__)); extern double __yn (int, double) __attribute__ ((__nothrow__ , __leaf__));
extern double erf (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __erf (double) __attribute__ ((__nothrow__ , __leaf__));
extern double erfc (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __erfc (double) __attribute__ ((__nothrow__ , __leaf__));
extern double lgamma (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __lgamma (double) __attribute__ ((__nothrow__ , __leaf__));
extern double tgamma (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __tgamma (double) __attribute__ ((__nothrow__ , __leaf__));
extern double gamma (double) __attribute__ ((__nothrow__ , __leaf__)); extern double __gamma (double) __attribute__ ((__nothrow__ , __leaf__));
extern double lgamma_r (double, int *__signgamp) __attribute__ ((__nothrow__ , __leaf__)); extern double __lgamma_r (double, int *__signgamp) __attribute__ ((__nothrow__ , __leaf__));
extern double rint (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __rint (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double nextafter (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __nextafter (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double nexttoward (double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __nexttoward (double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double remainder (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __remainder (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double scalbn (double __x, int __n) __attribute__ ((__nothrow__ , __leaf__)); extern double __scalbn (double __x, int __n) __attribute__ ((__nothrow__ , __leaf__));
extern int ilogb (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern int __ilogb (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double scalbln (double __x, long int __n) __attribute__ ((__nothrow__ , __leaf__)); extern double __scalbln (double __x, long int __n) __attribute__ ((__nothrow__ , __leaf__));
extern double nearbyint (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern double __nearbyint (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double round (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __round (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double trunc (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __trunc (double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double remquo (double __x, double __y, int *__quo) __attribute__ ((__nothrow__ , __leaf__)); extern double __remquo (double __x, double __y, int *__quo) __attribute__ ((__nothrow__ , __leaf__));
extern long int lrint (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long int __lrint (double __x) __attribute__ ((__nothrow__ , __leaf__));
__extension__
extern long long int llrint (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long long int __llrint (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long int lround (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long int __lround (double __x) __attribute__ ((__nothrow__ , __leaf__));
__extension__
extern long long int llround (double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long long int __llround (double __x) __attribute__ ((__nothrow__ , __leaf__));
extern double fdim (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)); extern double __fdim (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__));
extern double fmax (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __fmax (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double fmin (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern double __fmin (double __x, double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern double fma (double __x, double __y, double __z) __attribute__ ((__nothrow__ , __leaf__)); extern double __fma (double __x, double __y, double __z) __attribute__ ((__nothrow__ , __leaf__));
extern double scalb (double __x, double __n) __attribute__ ((__nothrow__ , __leaf__)); extern double __scalb (double __x, double __n) __attribute__ ((__nothrow__ , __leaf__));
extern int __fpclassifyf (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __signbitf (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __isinff (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __finitef (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __isnanf (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __iseqsigf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern int __issignalingf (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern float acosf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __acosf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float asinf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __asinf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float atanf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __atanf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float atan2f (float __y, float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __atan2f (float __y, float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float cosf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __cosf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float sinf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __sinf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float tanf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __tanf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float coshf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __coshf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float sinhf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __sinhf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float tanhf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __tanhf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float acoshf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __acoshf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float asinhf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __asinhf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float atanhf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __atanhf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float expf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __expf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float frexpf (float __x, int *__exponent) __attribute__ ((__nothrow__ , __leaf__)); extern float __frexpf (float __x, int *__exponent) __attribute__ ((__nothrow__ , __leaf__));
extern float ldexpf (float __x, int __exponent) __attribute__ ((__nothrow__ , __leaf__)); extern float __ldexpf (float __x, int __exponent) __attribute__ ((__nothrow__ , __leaf__));
extern float logf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __logf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float log10f (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __log10f (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float modff (float __x, float *__iptr) __attribute__ ((__nothrow__ , __leaf__)); extern float __modff (float __x, float *__iptr) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern float expm1f (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __expm1f (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float log1pf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __log1pf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float logbf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __logbf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float exp2f (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __exp2f (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float log2f (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __log2f (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float powf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __powf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern float sqrtf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __sqrtf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float hypotf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __hypotf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern float cbrtf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __cbrtf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float ceilf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __ceilf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float fabsf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __fabsf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float floorf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __floorf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float fmodf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __fmodf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern int isinff (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int finitef (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern float dremf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __dremf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern float significandf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __significandf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float copysignf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __copysignf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float nanf (const char *__tagb) __attribute__ ((__nothrow__ , __leaf__)); extern float __nanf (const char *__tagb) __attribute__ ((__nothrow__ , __leaf__));
extern int isnanf (float __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern float j0f (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __j0f (float) __attribute__ ((__nothrow__ , __leaf__));
extern float j1f (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __j1f (float) __attribute__ ((__nothrow__ , __leaf__));
extern float jnf (int, float) __attribute__ ((__nothrow__ , __leaf__)); extern float __jnf (int, float) __attribute__ ((__nothrow__ , __leaf__));
extern float y0f (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __y0f (float) __attribute__ ((__nothrow__ , __leaf__));
extern float y1f (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __y1f (float) __attribute__ ((__nothrow__ , __leaf__));
extern float ynf (int, float) __attribute__ ((__nothrow__ , __leaf__)); extern float __ynf (int, float) __attribute__ ((__nothrow__ , __leaf__));
extern float erff (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __erff (float) __attribute__ ((__nothrow__ , __leaf__));
extern float erfcf (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __erfcf (float) __attribute__ ((__nothrow__ , __leaf__));
extern float lgammaf (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __lgammaf (float) __attribute__ ((__nothrow__ , __leaf__));
extern float tgammaf (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __tgammaf (float) __attribute__ ((__nothrow__ , __leaf__));
extern float gammaf (float) __attribute__ ((__nothrow__ , __leaf__)); extern float __gammaf (float) __attribute__ ((__nothrow__ , __leaf__));
extern float lgammaf_r (float, int *__signgamp) __attribute__ ((__nothrow__ , __leaf__)); extern float __lgammaf_r (float, int *__signgamp) __attribute__ ((__nothrow__ , __leaf__));
extern float rintf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __rintf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float nextafterf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __nextafterf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern float nexttowardf (float __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __nexttowardf (float __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern float remainderf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __remainderf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern float scalbnf (float __x, int __n) __attribute__ ((__nothrow__ , __leaf__)); extern float __scalbnf (float __x, int __n) __attribute__ ((__nothrow__ , __leaf__));
extern int ilogbf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern int __ilogbf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float scalblnf (float __x, long int __n) __attribute__ ((__nothrow__ , __leaf__)); extern float __scalblnf (float __x, long int __n) __attribute__ ((__nothrow__ , __leaf__));
extern float nearbyintf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern float __nearbyintf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float roundf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __roundf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float truncf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __truncf (float __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float remquof (float __x, float __y, int *__quo) __attribute__ ((__nothrow__ , __leaf__)); extern float __remquof (float __x, float __y, int *__quo) __attribute__ ((__nothrow__ , __leaf__));
extern long int lrintf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern long int __lrintf (float __x) __attribute__ ((__nothrow__ , __leaf__));
__extension__
extern long long int llrintf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern long long int __llrintf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern long int lroundf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern long int __lroundf (float __x) __attribute__ ((__nothrow__ , __leaf__));
__extension__
extern long long int llroundf (float __x) __attribute__ ((__nothrow__ , __leaf__)); extern long long int __llroundf (float __x) __attribute__ ((__nothrow__ , __leaf__));
extern float fdimf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)); extern float __fdimf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__));
extern float fmaxf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __fmaxf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float fminf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern float __fminf (float __x, float __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern float fmaf (float __x, float __y, float __z) __attribute__ ((__nothrow__ , __leaf__)); extern float __fmaf (float __x, float __y, float __z) __attribute__ ((__nothrow__ , __leaf__));
extern float scalbf (float __x, float __n) __attribute__ ((__nothrow__ , __leaf__)); extern float __scalbf (float __x, float __n) __attribute__ ((__nothrow__ , __leaf__));
extern int __fpclassifyl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __signbitl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __isinfl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __finitel (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __isnanl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int __iseqsigl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern int __issignalingl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern long double acosl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __acosl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double asinl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __asinl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double atanl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __atanl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double atan2l (long double __y, long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __atan2l (long double __y, long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double cosl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __cosl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double sinl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __sinl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double tanl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __tanl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double coshl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __coshl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double sinhl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __sinhl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double tanhl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __tanhl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double acoshl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __acoshl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double asinhl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __asinhl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double atanhl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __atanhl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double expl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __expl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double frexpl (long double __x, int *__exponent) __attribute__ ((__nothrow__ , __leaf__)); extern long double __frexpl (long double __x, int *__exponent) __attribute__ ((__nothrow__ , __leaf__));
extern long double ldexpl (long double __x, int __exponent) __attribute__ ((__nothrow__ , __leaf__)); extern long double __ldexpl (long double __x, int __exponent) __attribute__ ((__nothrow__ , __leaf__));
extern long double logl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __logl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double log10l (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __log10l (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double modfl (long double __x, long double *__iptr) __attribute__ ((__nothrow__ , __leaf__)); extern long double __modfl (long double __x, long double *__iptr) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern long double expm1l (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __expm1l (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double log1pl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __log1pl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double logbl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __logbl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double exp2l (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __exp2l (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double log2l (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __log2l (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double powl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __powl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double sqrtl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __sqrtl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double hypotl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __hypotl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double cbrtl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __cbrtl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double ceill (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __ceill (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double fabsl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __fabsl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double floorl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __floorl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double fmodl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __fmodl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern int isinfl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern int finitel (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern long double dreml (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __dreml (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double significandl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __significandl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double copysignl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __copysignl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double nanl (const char *__tagb) __attribute__ ((__nothrow__ , __leaf__)); extern long double __nanl (const char *__tagb) __attribute__ ((__nothrow__ , __leaf__));
extern int isnanl (long double __value) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__const__));
extern long double j0l (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __j0l (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double j1l (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __j1l (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double jnl (int, long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __jnl (int, long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double y0l (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __y0l (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double y1l (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __y1l (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double ynl (int, long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __ynl (int, long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double erfl (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __erfl (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double erfcl (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __erfcl (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double lgammal (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __lgammal (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double tgammal (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __tgammal (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double gammal (long double) __attribute__ ((__nothrow__ , __leaf__)); extern long double __gammal (long double) __attribute__ ((__nothrow__ , __leaf__));
extern long double lgammal_r (long double, int *__signgamp) __attribute__ ((__nothrow__ , __leaf__)); extern long double __lgammal_r (long double, int *__signgamp) __attribute__ ((__nothrow__ , __leaf__));
extern long double rintl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __rintl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double nextafterl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __nextafterl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double nexttowardl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __nexttowardl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double remainderl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __remainderl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double scalbnl (long double __x, int __n) __attribute__ ((__nothrow__ , __leaf__)); extern long double __scalbnl (long double __x, int __n) __attribute__ ((__nothrow__ , __leaf__));
extern int ilogbl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern int __ilogbl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double scalblnl (long double __x, long int __n) __attribute__ ((__nothrow__ , __leaf__)); extern long double __scalblnl (long double __x, long int __n) __attribute__ ((__nothrow__ , __leaf__));
extern long double nearbyintl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long double __nearbyintl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double roundl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __roundl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double truncl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __truncl (long double __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double remquol (long double __x, long double __y, int *__quo) __attribute__ ((__nothrow__ , __leaf__)); extern long double __remquol (long double __x, long double __y, int *__quo) __attribute__ ((__nothrow__ , __leaf__));
extern long int lrintl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long int __lrintl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
__extension__
extern long long int llrintl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long long int __llrintl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long int lroundl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long int __lroundl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
__extension__
extern long long int llroundl (long double __x) __attribute__ ((__nothrow__ , __leaf__)); extern long long int __llroundl (long double __x) __attribute__ ((__nothrow__ , __leaf__));
extern long double fdiml (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)); extern long double __fdiml (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__));
extern long double fmaxl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __fmaxl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double fminl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)); extern long double __fminl (long double __x, long double __y) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern long double fmal (long double __x, long double __y, long double __z) __attribute__ ((__nothrow__ , __leaf__)); extern long double __fmal (long double __x, long double __y, long double __z) __attribute__ ((__nothrow__ , __leaf__));
extern long double scalbl (long double __x, long double __n) __attribute__ ((__nothrow__ , __leaf__)); extern long double __scalbl (long double __x, long double __n) __attribute__ ((__nothrow__ , __leaf__));
extern int signgam;
enum
{
FP_NAN =
0,
FP_INFINITE =
1,
FP_ZERO =
2,
FP_SUBNORMAL =
3,
FP_NORMAL =
4
};
typedef __int8_t int8_t;
typedef __int16_t int16_t;
typedef __int32_t int32_t;
typedef __int64_t int64_t;
typedef __uint8_t uint8_t;
typedef __uint16_t uint16_t;
typedef __uint32_t uint32_t;
typedef __uint64_t uint64_t;
typedef __int_least8_t int_least8_t;
typedef __int_least16_t int_least16_t;
typedef __int_least32_t int_least32_t;
typedef __int_least64_t int_least64_t;
typedef __uint_least8_t uint_least8_t;
typedef __uint_least16_t uint_least16_t;
typedef __uint_least32_t uint_least32_t;
typedef __uint_least64_t uint_least64_t;
typedef signed char int_fast8_t;
typedef long int int_fast16_t;
typedef long int int_fast32_t;
typedef long int int_fast64_t;
typedef unsigned char uint_fast8_t;
typedef unsigned long int uint_fast16_t;
typedef unsigned long int uint_fast32_t;
typedef unsigned long int uint_fast64_t;
typedef long int intptr_t;
typedef unsigned long int uintptr_t;
typedef __intmax_t intmax_t;
typedef __uintmax_t uintmax_t;
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
extern int *__errno_location (void) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
typedef int __gwchar_t;
typedef struct
{
long int quot;
long int rem;
} imaxdiv_t;
extern intmax_t imaxabs (intmax_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern imaxdiv_t imaxdiv (intmax_t __numer, intmax_t __denom)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern intmax_t strtoimax (const char *__restrict __nptr,
char **__restrict __endptr, int __base) __attribute__ ((__nothrow__ , __leaf__));
extern uintmax_t strtoumax (const char *__restrict __nptr,
char ** __restrict __endptr, int __base) __attribute__ ((__nothrow__ , __leaf__));
extern intmax_t wcstoimax (const __gwchar_t *__restrict __nptr,
__gwchar_t **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__));
extern uintmax_t wcstoumax (const __gwchar_t *__restrict __nptr,
__gwchar_t ** __restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__));
typedef long unsigned int size_t;
typedef __builtin_va_list __gnuc_va_list;
typedef struct
{
int __count;
union
{
unsigned int __wch;
char __wchb[4];
} __value;
} __mbstate_t;
typedef struct _G_fpos_t
{
__off_t __pos;
__mbstate_t __state;
} __fpos_t;
typedef struct _G_fpos64_t
{
__off64_t __pos;
__mbstate_t __state;
} __fpos64_t;
struct _IO_FILE;
typedef struct _IO_FILE __FILE;
struct _IO_FILE;
typedef struct _IO_FILE FILE;
struct _IO_FILE;
struct _IO_marker;
struct _IO_codecvt;
struct _IO_wide_data;
typedef void _IO_lock_t;
struct _IO_FILE
{
int _flags;
char *_IO_read_ptr;
char *_IO_read_end;
char *_IO_read_base;
char *_IO_write_base;
char *_IO_write_ptr;
char *_IO_write_end;
char *_IO_buf_base;
char *_IO_buf_end;
char *_IO_save_base;
char *_IO_backup_base;
char *_IO_save_end;
struct _IO_marker *_markers;
struct _IO_FILE *_chain;
int _fileno;
int _flags2;
__off_t _old_offset;
unsigned short _cur_column;
signed char _vtable_offset;
char _shortbuf[1];
_IO_lock_t *_lock;
__off64_t _offset;
struct _IO_codecvt *_codecvt;
struct _IO_wide_data *_wide_data;
struct _IO_FILE *_freeres_list;
void *_freeres_buf;
size_t __pad5;
int _mode;
char _unused2[15 * sizeof (int) - 4 * sizeof (void *) - sizeof (size_t)];
};
typedef __gnuc_va_list va_list;
typedef __off_t off_t;
typedef __ssize_t ssize_t;
typedef __fpos_t fpos_t;
extern FILE *stdin;
extern FILE *stdout;
extern FILE *stderr;
extern int remove (const char *__filename) __attribute__ ((__nothrow__ , __leaf__));
extern int rename (const char *__old, const char *__new) __attribute__ ((__nothrow__ , __leaf__));
extern int renameat (int __oldfd, const char *__old, int __newfd,
const char *__new) __attribute__ ((__nothrow__ , __leaf__));
extern int fclose (FILE *__stream);
extern FILE *tmpfile (void)
__attribute__ ((__malloc__)) __attribute__ ((__malloc__ (fclose, 1))) ;
extern char *tmpnam (char[20]) __attribute__ ((__nothrow__ , __leaf__)) ;
extern char *tmpnam_r (char __s[20]) __attribute__ ((__nothrow__ , __leaf__)) ;
extern char *tempnam (const char *__dir, const char *__pfx)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__malloc__ (__builtin_free, 1)));
extern int fflush (FILE *__stream);
extern int fflush_unlocked (FILE *__stream);
extern FILE *fopen (const char *__restrict __filename,
const char *__restrict __modes)
__attribute__ ((__malloc__)) __attribute__ ((__malloc__ (fclose, 1))) ;
extern FILE *freopen (const char *__restrict __filename,
const char *__restrict __modes,
FILE *__restrict __stream) ;
extern FILE *fdopen (int __fd, const char *__modes) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__malloc__)) __attribute__ ((__malloc__ (fclose, 1))) ;
extern FILE *fmemopen (void *__s, size_t __len, const char *__modes)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__malloc__ (fclose, 1))) ;
extern FILE *open_memstream (char **__bufloc, size_t *__sizeloc) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__malloc__)) __attribute__ ((__malloc__ (fclose, 1))) ;
extern void setbuf (FILE *__restrict __stream, char *__restrict __buf) __attribute__ ((__nothrow__ , __leaf__));
extern int setvbuf (FILE *__restrict __stream, char *__restrict __buf,
int __modes, size_t __n) __attribute__ ((__nothrow__ , __leaf__));
extern void setbuffer (FILE *__restrict __stream, char *__restrict __buf,
size_t __size) __attribute__ ((__nothrow__ , __leaf__));
extern void setlinebuf (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));
extern int fprintf (FILE *__restrict __stream,
const char *__restrict __format, ...);
extern int printf (const char *__restrict __format, ...);
extern int sprintf (char *__restrict __s,
const char *__restrict __format, ...) __attribute__ ((__nothrow__));
extern int vfprintf (FILE *__restrict __s, const char *__restrict __format,
__gnuc_va_list __arg);
extern int vprintf (const char *__restrict __format, __gnuc_va_list __arg);
extern int vsprintf (char *__restrict __s, const char *__restrict __format,
__gnuc_va_list __arg) __attribute__ ((__nothrow__));
extern int snprintf (char *__restrict __s, size_t __maxlen,
const char *__restrict __format, ...)
__attribute__ ((__nothrow__)) __attribute__ ((__format__ (__printf__, 3, 4)));
extern int vsnprintf (char *__restrict __s, size_t __maxlen,
const char *__restrict __format, __gnuc_va_list __arg)
__attribute__ ((__nothrow__)) __attribute__ ((__format__ (__printf__, 3, 0)));
extern int vdprintf (int __fd, const char *__restrict __fmt,
__gnuc_va_list __arg)
__attribute__ ((__format__ (__printf__, 2, 0)));
extern int dprintf (int __fd, const char *__restrict __fmt, ...)
__attribute__ ((__format__ (__printf__, 2, 3)));
extern int fscanf (FILE *__restrict __stream,
const char *__restrict __format, ...) ;
extern int scanf (const char *__restrict __format, ...) ;
extern int sscanf (const char *__restrict __s,
const char *__restrict __format, ...) __attribute__ ((__nothrow__ , __leaf__));
extern int fscanf (FILE *__restrict __stream, const char *__restrict __format, ...) __asm__ ("" "__isoc99_fscanf")
;
extern int scanf (const char *__restrict __format, ...) __asm__ ("" "__isoc99_scanf")
;
extern int sscanf (const char *__restrict __s, const char *__restrict __format, ...) __asm__ ("" "__isoc99_sscanf") __attribute__ ((__nothrow__ , __leaf__))
;
extern int vfscanf (FILE *__restrict __s, const char *__restrict __format,
__gnuc_va_list __arg)
__attribute__ ((__format__ (__scanf__, 2, 0))) ;
extern int vscanf (const char *__restrict __format, __gnuc_va_list __arg)
__attribute__ ((__format__ (__scanf__, 1, 0))) ;
extern int vsscanf (const char *__restrict __s,
const char *__restrict __format, __gnuc_va_list __arg)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__format__ (__scanf__, 2, 0)));
extern int vfscanf (FILE *__restrict __s, const char *__restrict __format, __gnuc_va_list __arg) __asm__ ("" "__isoc99_vfscanf")
__attribute__ ((__format__ (__scanf__, 2, 0))) ;
extern int vscanf (const char *__restrict __format, __gnuc_va_list __arg) __asm__ ("" "__isoc99_vscanf")
__attribute__ ((__format__ (__scanf__, 1, 0))) ;
extern int vsscanf (const char *__restrict __s, const char *__restrict __format, __gnuc_va_list __arg) __asm__ ("" "__isoc99_vsscanf") __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__format__ (__scanf__, 2, 0)));
extern int fgetc (FILE *__stream);
extern int getc (FILE *__stream);
extern int getchar (void);
extern int getc_unlocked (FILE *__stream);
extern int getchar_unlocked (void);
extern int fgetc_unlocked (FILE *__stream);
extern int fputc (int __c, FILE *__stream);
extern int putc (int __c, FILE *__stream);
extern int putchar (int __c);
extern int fputc_unlocked (int __c, FILE *__stream);
extern int putc_unlocked (int __c, FILE *__stream);
extern int putchar_unlocked (int __c);
extern int getw (FILE *__stream);
extern int putw (int __w, FILE *__stream);
extern char *fgets (char *__restrict __s, int __n, FILE *__restrict __stream)
__attribute__ ((__access__ (__write_only__, 1, 2)));
extern __ssize_t __getdelim (char **__restrict __lineptr,
size_t *__restrict __n, int __delimiter,
FILE *__restrict __stream) ;
extern __ssize_t getdelim (char **__restrict __lineptr,
size_t *__restrict __n, int __delimiter,
FILE *__restrict __stream) ;
extern __ssize_t getline (char **__restrict __lineptr,
size_t *__restrict __n,
FILE *__restrict __stream) ;
extern int fputs (const char *__restrict __s, FILE *__restrict __stream);
extern int puts (const char *__s);
extern int ungetc (int __c, FILE *__stream);
extern size_t fread (void *__restrict __ptr, size_t __size,
size_t __n, FILE *__restrict __stream) ;
extern size_t fwrite (const void *__restrict __ptr, size_t __size,
size_t __n, FILE *__restrict __s);
extern size_t fread_unlocked (void *__restrict __ptr, size_t __size,
size_t __n, FILE *__restrict __stream) ;
extern size_t fwrite_unlocked (const void *__restrict __ptr, size_t __size,
size_t __n, FILE *__restrict __stream);
extern int fseek (FILE *__stream, long int __off, int __whence);
extern long int ftell (FILE *__stream) ;
extern void rewind (FILE *__stream);
extern int fseeko (FILE *__stream, __off_t __off, int __whence);
extern __off_t ftello (FILE *__stream) ;
extern int fgetpos (FILE *__restrict __stream, fpos_t *__restrict __pos);
extern int fsetpos (FILE *__stream, const fpos_t *__pos);
extern void clearerr (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));
extern int feof (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern int ferror (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern void clearerr_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));
extern int feof_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern int ferror_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern void perror (const char *__s);
extern int fileno (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern int fileno_unlocked (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern int pclose (FILE *__stream);
extern FILE *popen (const char *__command, const char *__modes)
__attribute__ ((__malloc__)) __attribute__ ((__malloc__ (pclose, 1))) ;
extern char *ctermid (char *__s) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__access__ (__write_only__, 1)));
extern void flockfile (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));
extern int ftrylockfile (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__)) ;
extern void funlockfile (FILE *__stream) __attribute__ ((__nothrow__ , __leaf__));
extern int __uflow (FILE *);
extern int __overflow (FILE *, int);
typedef int wchar_t;
typedef struct
{
int quot;
int rem;
} div_t;
typedef struct
{
long int quot;
long int rem;
} ldiv_t;
__extension__ typedef struct
{
long long int quot;
long long int rem;
} lldiv_t;
extern size_t __ctype_get_mb_cur_max (void) __attribute__ ((__nothrow__ , __leaf__)) ;
extern double atof (const char *__nptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1))) ;
extern int atoi (const char *__nptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1))) ;
extern long int atol (const char *__nptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1))) ;
__extension__ extern long long int atoll (const char *__nptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1))) ;
extern double strtod (const char *__restrict __nptr,
char **__restrict __endptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern float strtof (const char *__restrict __nptr,
char **__restrict __endptr) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern long double strtold (const char *__restrict __nptr,
char **__restrict __endptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern long int strtol (const char *__restrict __nptr,
char **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern unsigned long int strtoul (const char *__restrict __nptr,
char **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
__extension__
extern long long int strtoq (const char *__restrict __nptr,
char **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
__extension__
extern unsigned long long int strtouq (const char *__restrict __nptr,
char **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
__extension__
extern long long int strtoll (const char *__restrict __nptr,
char **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
__extension__
extern unsigned long long int strtoull (const char *__restrict __nptr,
char **__restrict __endptr, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern char *l64a (long int __n) __attribute__ ((__nothrow__ , __leaf__)) ;
extern long int a64l (const char *__s)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1))) ;
typedef __u_char u_char;
typedef __u_short u_short;
typedef __u_int u_int;
typedef __u_long u_long;
typedef __quad_t quad_t;
typedef __u_quad_t u_quad_t;
typedef __fsid_t fsid_t;
typedef __loff_t loff_t;
typedef __ino_t ino_t;
typedef __dev_t dev_t;
typedef __gid_t gid_t;
typedef __mode_t mode_t;
typedef __nlink_t nlink_t;
typedef __uid_t uid_t;
typedef __pid_t pid_t;
typedef __id_t id_t;
typedef __daddr_t daddr_t;
typedef __caddr_t caddr_t;
typedef __key_t key_t;
typedef __clock_t clock_t;
typedef __clockid_t clockid_t;
typedef __time_t time_t;
typedef __timer_t timer_t;
typedef unsigned long int ulong;
typedef unsigned short int ushort;
typedef unsigned int uint;
typedef __uint8_t u_int8_t;
typedef __uint16_t u_int16_t;
typedef __uint32_t u_int32_t;
typedef __uint64_t u_int64_t;
typedef int register_t __attribute__ ((__mode__ (__word__)));
static __inline __uint16_t
__bswap_16 (__uint16_t __bsx)
{
return __builtin_bswap16 (__bsx);
}
static __inline __uint32_t
__bswap_32 (__uint32_t __bsx)
{
return __builtin_bswap32 (__bsx);
}
__extension__ static __inline __uint64_t
__bswap_64 (__uint64_t __bsx)
{
return __builtin_bswap64 (__bsx);
}
static __inline __uint16_t
__uint16_identity (__uint16_t __x)
{
return __x;
}
static __inline __uint32_t
__uint32_identity (__uint32_t __x)
{
return __x;
}
static __inline __uint64_t
__uint64_identity (__uint64_t __x)
{
return __x;
}
typedef struct
{
unsigned long int __val[(1024 / (8 * sizeof (unsigned long int)))];
} __sigset_t;
typedef __sigset_t sigset_t;
struct timeval
{
__time_t tv_sec;
__suseconds_t tv_usec;
};
struct timespec
{
__time_t tv_sec;
__syscall_slong_t tv_nsec;
};
typedef __suseconds_t suseconds_t;
typedef long int __fd_mask;
typedef struct
{
__fd_mask __fds_bits[1024 / (8 * (int) sizeof (__fd_mask))];
} fd_set;
typedef __fd_mask fd_mask;
extern int select (int __nfds, fd_set *__restrict __readfds,
fd_set *__restrict __writefds,
fd_set *__restrict __exceptfds,
struct timeval *__restrict __timeout);
extern int pselect (int __nfds, fd_set *__restrict __readfds,
fd_set *__restrict __writefds,
fd_set *__restrict __exceptfds,
const struct timespec *__restrict __timeout,
const __sigset_t *__restrict __sigmask);
typedef __blksize_t blksize_t;
typedef __blkcnt_t blkcnt_t;
typedef __fsblkcnt_t fsblkcnt_t;
typedef __fsfilcnt_t fsfilcnt_t;
typedef union
{
__extension__ unsigned long long int __value64;
struct
{
unsigned int __low;
unsigned int __high;
} __value32;
} __atomic_wide_counter;
typedef struct __pthread_internal_list
{
struct __pthread_internal_list *__prev;
struct __pthread_internal_list *__next;
} __pthread_list_t;
typedef struct __pthread_internal_slist
{
struct __pthread_internal_slist *__next;
} __pthread_slist_t;
struct __pthread_mutex_s
{
int __lock;
unsigned int __count;
int __owner;
unsigned int __nusers;
int __kind;
short __spins;
short __elision;
__pthread_list_t __list;
};
struct __pthread_rwlock_arch_t
{
unsigned int __readers;
unsigned int __writers;
unsigned int __wrphase_futex;
unsigned int __writers_futex;
unsigned int __pad3;
unsigned int __pad4;
int __cur_writer;
int __shared;
signed char __rwelision;
unsigned char __pad1[7];
unsigned long int __pad2;
unsigned int __flags;
};
struct __pthread_cond_s
{
__atomic_wide_counter __wseq;
__atomic_wide_counter __g1_start;
unsigned int __g_refs[2] ;
unsigned int __g_size[2];
unsigned int __g1_orig_size;
unsigned int __wrefs;
unsigned int __g_signals[2];
};
typedef unsigned int __tss_t;
typedef unsigned long int __thrd_t;
typedef struct
{
int __data ;
} __once_flag;
typedef unsigned long int pthread_t;
typedef union
{
char __size[4];
int __align;
} pthread_mutexattr_t;
typedef union
{
char __size[4];
int __align;
} pthread_condattr_t;
typedef unsigned int pthread_key_t;
typedef int pthread_once_t;
union pthread_attr_t
{
char __size[56];
long int __align;
};
typedef union pthread_attr_t pthread_attr_t;
typedef union
{
struct __pthread_mutex_s __data;
char __size[40];
long int __align;
} pthread_mutex_t;
typedef union
{
struct __pthread_cond_s __data;
char __size[48];
__extension__ long long int __align;
} pthread_cond_t;
typedef union
{
struct __pthread_rwlock_arch_t __data;
char __size[56];
long int __align;
} pthread_rwlock_t;
typedef union
{
char __size[8];
long int __align;
} pthread_rwlockattr_t;
typedef volatile int pthread_spinlock_t;
typedef union
{
char __size[32];
long int __align;
} pthread_barrier_t;
typedef union
{
char __size[4];
int __align;
} pthread_barrierattr_t;
extern long int random (void) __attribute__ ((__nothrow__ , __leaf__));
extern void srandom (unsigned int __seed) __attribute__ ((__nothrow__ , __leaf__));
extern char *initstate (unsigned int __seed, char *__statebuf,
size_t __statelen) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern char *setstate (char *__statebuf) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
struct random_data
{
int32_t *fptr;
int32_t *rptr;
int32_t *state;
int rand_type;
int rand_deg;
int rand_sep;
int32_t *end_ptr;
};
extern int random_r (struct random_data *__restrict __buf,
int32_t *__restrict __result) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int srandom_r (unsigned int __seed, struct random_data *__buf)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern int initstate_r (unsigned int __seed, char *__restrict __statebuf,
size_t __statelen,
struct random_data *__restrict __buf)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 4)));
extern int setstate_r (char *__restrict __statebuf,
struct random_data *__restrict __buf)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int rand (void) __attribute__ ((__nothrow__ , __leaf__));
extern void srand (unsigned int __seed) __attribute__ ((__nothrow__ , __leaf__));
extern int rand_r (unsigned int *__seed) __attribute__ ((__nothrow__ , __leaf__));
extern double drand48 (void) __attribute__ ((__nothrow__ , __leaf__));
extern double erand48 (unsigned short int __xsubi[3]) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern long int lrand48 (void) __attribute__ ((__nothrow__ , __leaf__));
extern long int nrand48 (unsigned short int __xsubi[3])
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern long int mrand48 (void) __attribute__ ((__nothrow__ , __leaf__));
extern long int jrand48 (unsigned short int __xsubi[3])
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern void srand48 (long int __seedval) __attribute__ ((__nothrow__ , __leaf__));
extern unsigned short int *seed48 (unsigned short int __seed16v[3])
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern void lcong48 (unsigned short int __param[7]) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
struct drand48_data
{
unsigned short int __x[3];
unsigned short int __old_x[3];
unsigned short int __c;
unsigned short int __init;
__extension__ unsigned long long int __a;
};
extern int drand48_r (struct drand48_data *__restrict __buffer,
double *__restrict __result) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int erand48_r (unsigned short int __xsubi[3],
struct drand48_data *__restrict __buffer,
double *__restrict __result) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int lrand48_r (struct drand48_data *__restrict __buffer,
long int *__restrict __result)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int nrand48_r (unsigned short int __xsubi[3],
struct drand48_data *__restrict __buffer,
long int *__restrict __result)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int mrand48_r (struct drand48_data *__restrict __buffer,
long int *__restrict __result)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int jrand48_r (unsigned short int __xsubi[3],
struct drand48_data *__restrict __buffer,
long int *__restrict __result)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int srand48_r (long int __seedval, struct drand48_data *__buffer)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern int seed48_r (unsigned short int __seed16v[3],
struct drand48_data *__buffer) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int lcong48_r (unsigned short int __param[7],
struct drand48_data *__buffer)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern void *malloc (size_t __size) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__))
__attribute__ ((__alloc_size__ (1))) ;
extern void *calloc (size_t __nmemb, size_t __size)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__alloc_size__ (1, 2))) ;
extern void *realloc (void *__ptr, size_t __size)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__warn_unused_result__)) __attribute__ ((__alloc_size__ (2)));
extern void free (void *__ptr) __attribute__ ((__nothrow__ , __leaf__));
extern void *reallocarray (void *__ptr, size_t __nmemb, size_t __size)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__warn_unused_result__))
__attribute__ ((__alloc_size__ (2, 3)))
__attribute__ ((__malloc__ (__builtin_free, 1)));
extern void *reallocarray (void *__ptr, size_t __nmemb, size_t __size)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__ (reallocarray, 1)));
extern void *alloca (size_t __size) __attribute__ ((__nothrow__ , __leaf__));
extern void *valloc (size_t __size) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__))
__attribute__ ((__alloc_size__ (1))) ;
extern int posix_memalign (void **__memptr, size_t __alignment, size_t __size)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1))) ;
extern void *aligned_alloc (size_t __alignment, size_t __size)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__alloc_align__ (1)))
__attribute__ ((__alloc_size__ (2))) ;
extern void abort (void) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__noreturn__));
extern int atexit (void (*__func) (void)) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern int at_quick_exit (void (*__func) (void)) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern int on_exit (void (*__func) (int __status, void *__arg), void *__arg)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern void exit (int __status) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__noreturn__));
extern void quick_exit (int __status) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__noreturn__));
extern void _Exit (int __status) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__noreturn__));
extern char *getenv (const char *__name) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1))) ;
extern int putenv (char *__string) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern int setenv (const char *__name, const char *__value, int __replace)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern int unsetenv (const char *__name) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern int clearenv (void) __attribute__ ((__nothrow__ , __leaf__));
extern char *mktemp (char *__template) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern int mkstemp (char *__template) __attribute__ ((__nonnull__ (1))) ;
extern int mkstemps (char *__template, int __suffixlen) __attribute__ ((__nonnull__ (1))) ;
extern char *mkdtemp (char *__template) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1))) ;
extern int system (const char *__command) ;
extern char *realpath (const char *__restrict __name,
char *__restrict __resolved) __attribute__ ((__nothrow__ , __leaf__)) ;
typedef int (*__compar_fn_t) (const void *, const void *);
extern void *bsearch (const void *__key, const void *__base,
size_t __nmemb, size_t __size, __compar_fn_t __compar)
__attribute__ ((__nonnull__ (1, 2, 5))) ;
extern void qsort (void *__base, size_t __nmemb, size_t __size,
__compar_fn_t __compar) __attribute__ ((__nonnull__ (1, 4)));
extern int abs (int __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)) ;
extern long int labs (long int __x) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)) ;
__extension__ extern long long int llabs (long long int __x)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)) ;
extern div_t div (int __numer, int __denom)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)) ;
extern ldiv_t ldiv (long int __numer, long int __denom)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)) ;
__extension__ extern lldiv_t lldiv (long long int __numer,
long long int __denom)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__)) ;
extern char *ecvt (double __value, int __ndigit, int *__restrict __decpt,
int *__restrict __sign) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4))) ;
extern char *fcvt (double __value, int __ndigit, int *__restrict __decpt,
int *__restrict __sign) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4))) ;
extern char *gcvt (double __value, int __ndigit, char *__buf)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3))) ;
extern char *qecvt (long double __value, int __ndigit,
int *__restrict __decpt, int *__restrict __sign)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4))) ;
extern char *qfcvt (long double __value, int __ndigit,
int *__restrict __decpt, int *__restrict __sign)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4))) ;
extern char *qgcvt (long double __value, int __ndigit, char *__buf)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3))) ;
extern int ecvt_r (double __value, int __ndigit, int *__restrict __decpt,
int *__restrict __sign, char *__restrict __buf,
size_t __len) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4, 5)));
extern int fcvt_r (double __value, int __ndigit, int *__restrict __decpt,
int *__restrict __sign, char *__restrict __buf,
size_t __len) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4, 5)));
extern int qecvt_r (long double __value, int __ndigit,
int *__restrict __decpt, int *__restrict __sign,
char *__restrict __buf, size_t __len)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4, 5)));
extern int qfcvt_r (long double __value, int __ndigit,
int *__restrict __decpt, int *__restrict __sign,
char *__restrict __buf, size_t __len)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (3, 4, 5)));
extern int mblen (const char *__s, size_t __n) __attribute__ ((__nothrow__ , __leaf__));
extern int mbtowc (wchar_t *__restrict __pwc,
const char *__restrict __s, size_t __n) __attribute__ ((__nothrow__ , __leaf__));
extern int wctomb (char *__s, wchar_t __wchar) __attribute__ ((__nothrow__ , __leaf__));
extern size_t mbstowcs (wchar_t *__restrict __pwcs,
const char *__restrict __s, size_t __n) __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__access__ (__read_only__, 2)));
extern size_t wcstombs (char *__restrict __s,
const wchar_t *__restrict __pwcs, size_t __n)
__attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__access__ (__write_only__, 1, 3)))
__attribute__ ((__access__ (__read_only__, 2)));
extern int rpmatch (const char *__response) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1))) ;
extern int getsubopt (char **__restrict __optionp,
char *const *__restrict __tokens,
char **__restrict __valuep)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2, 3))) ;
extern int getloadavg (double __loadavg[], int __nelem)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern void *memcpy (void *__restrict __dest, const void *__restrict __src,
size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern void *memmove (void *__dest, const void *__src, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern void *memccpy (void *__restrict __dest, const void *__restrict __src,
int __c, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2))) __attribute__ ((__access__ (__write_only__, 1, 4)));
extern void *memset (void *__s, int __c, size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern int memcmp (const void *__s1, const void *__s2, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern int __memcmpeq (const void *__s1, const void *__s2, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern void *memchr (const void *__s, int __c, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern char *strcpy (char *__restrict __dest, const char *__restrict __src)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strncpy (char *__restrict __dest,
const char *__restrict __src, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strcat (char *__restrict __dest, const char *__restrict __src)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strncat (char *__restrict __dest, const char *__restrict __src,
size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern int strcmp (const char *__s1, const char *__s2)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern int strncmp (const char *__s1, const char *__s2, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern int strcoll (const char *__s1, const char *__s2)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern size_t strxfrm (char *__restrict __dest,
const char *__restrict __src, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2))) __attribute__ ((__access__ (__write_only__, 1, 3)));
struct __locale_struct
{
struct __locale_data *__locales[13];
const unsigned short int *__ctype_b;
const int *__ctype_tolower;
const int *__ctype_toupper;
const char *__names[13];
};
typedef struct __locale_struct *__locale_t;
typedef __locale_t locale_t;
extern int strcoll_l (const char *__s1, const char *__s2, locale_t __l)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2, 3)));
extern size_t strxfrm_l (char *__dest, const char *__src, size_t __n,
locale_t __l) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 4)))
__attribute__ ((__access__ (__write_only__, 1, 3)));
extern char *strdup (const char *__s)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__nonnull__ (1)));
extern char *strndup (const char *__string, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__malloc__)) __attribute__ ((__nonnull__ (1)));
extern char *strchr (const char *__s, int __c)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern char *strrchr (const char *__s, int __c)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern size_t strcspn (const char *__s, const char *__reject)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern size_t strspn (const char *__s, const char *__accept)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strpbrk (const char *__s, const char *__accept)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strstr (const char *__haystack, const char *__needle)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strtok (char *__restrict __s, const char *__restrict __delim)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2)));
extern char *__strtok_r (char *__restrict __s,
const char *__restrict __delim,
char **__restrict __save_ptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 3)));
extern char *strtok_r (char *__restrict __s, const char *__restrict __delim,
char **__restrict __save_ptr)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (2, 3)));
extern size_t strlen (const char *__s)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern size_t strnlen (const char *__string, size_t __maxlen)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern char *strerror (int __errnum) __attribute__ ((__nothrow__ , __leaf__));
extern int strerror_r (int __errnum, char *__buf, size_t __buflen) __asm__ ("" "__xpg_strerror_r") __attribute__ ((__nothrow__ , __leaf__))
__attribute__ ((__nonnull__ (2)))
__attribute__ ((__access__ (__write_only__, 2, 3)));
extern char *strerror_l (int __errnum, locale_t __l) __attribute__ ((__nothrow__ , __leaf__));
extern int bcmp (const void *__s1, const void *__s2, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern void bcopy (const void *__src, void *__dest, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern void bzero (void *__s, size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
extern char *index (const char *__s, int __c)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern char *rindex (const char *__s, int __c)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1)));
extern int ffs (int __i) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern int ffsl (long int __l) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
__extension__ extern int ffsll (long long int __ll)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern int strcasecmp (const char *__s1, const char *__s2)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern int strncasecmp (const char *__s1, const char *__s2, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2)));
extern int strcasecmp_l (const char *__s1, const char *__s2, locale_t __loc)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2, 3)));
extern int strncasecmp_l (const char *__s1, const char *__s2,
size_t __n, locale_t __loc)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__pure__)) __attribute__ ((__nonnull__ (1, 2, 4)));
extern void explicit_bzero (void *__s, size_t __n) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)))
__attribute__ ((__access__ (__write_only__, 1, 2)));
extern char *strsep (char **__restrict __stringp,
const char *__restrict __delim)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *strsignal (int __sig) __attribute__ ((__nothrow__ , __leaf__));
extern char *__stpcpy (char *__restrict __dest, const char *__restrict __src)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *stpcpy (char *__restrict __dest, const char *__restrict __src)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *__stpncpy (char *__restrict __dest,
const char *__restrict __src, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
extern char *stpncpy (char *__restrict __dest,
const char *__restrict __src, size_t __n)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1, 2)));
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
return a & ((1U << p) - 1);
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
static __attribute__((always_inline)) inline int64_t av_sat_add64_c(int64_t a, int64_t b) {
int64_t tmp;
return !__builtin_add_overflow(a, b, &tmp) ? tmp : (tmp < 0 ? (9223372036854775807L) : (-9223372036854775807L -1));
}
static __attribute__((always_inline)) inline int64_t av_sat_sub64_c(int64_t a, int64_t b) {
int64_t tmp;
return !__builtin_sub_overflow(a, b, &tmp) ? tmp : (tmp < 0 ? (9223372036854775807L) : (-9223372036854775807L -1));
}
static __attribute__((always_inline)) inline __attribute__((const)) float av_clipf_c(float a, float amin, float amax)
{
return ((((a) > (amin) ? (a) : (amin))) > (amax) ? (amax) : (((a) > (amin) ? (a) : (amin))));
}
static __attribute__((always_inline)) inline __attribute__((const)) double av_clipd_c(double a, double amin, double amax)
{
return ((((a) > (amin) ? (a) : (amin))) > (amax) ? (amax) : (((a) > (amin) ? (a) : (amin))));
}
static __attribute__((always_inline)) inline __attribute__((const)) int av_ceil_log2_c(int x)
{
return av_log2((x - 1U) << 1);
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
void *av_malloc(size_t size) __attribute__((__malloc__)) __attribute__((alloc_size(1)));
void *av_mallocz(size_t size) __attribute__((__malloc__)) __attribute__((alloc_size(1)));
__attribute__((alloc_size(1, 2))) void *av_malloc_array(size_t nmemb, size_t size);
void *av_calloc(size_t nmemb, size_t size) __attribute__((__malloc__)) __attribute__((alloc_size(1, 2)));
__attribute__((deprecated))
void *av_mallocz_array(size_t nmemb, size_t size) __attribute__((__malloc__)) __attribute__((alloc_size(1, 2)));
void *av_realloc(void *ptr, size_t size) __attribute__((alloc_size(2)));
__attribute__((warn_unused_result))
int av_reallocp(void *ptr, size_t size);
void *av_realloc_f(void *ptr, size_t nelem, size_t elsize);
__attribute__((alloc_size(2, 3))) void *av_realloc_array(void *ptr, size_t nmemb, size_t size);
int av_reallocp_array(void *ptr, size_t nmemb, size_t size);
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
int av_size_mult(size_t a, size_t b, size_t *r);
void av_max_alloc(size_t max);
typedef long int ptrdiff_t;
typedef struct {
long long __max_align_ll __attribute__((__aligned__(__alignof__(long long))));
long double __max_align_ld __attribute__((__aligned__(__alignof__(long double))));
} max_align_t;
int av_strerror(int errnum, char *errbuf, size_t errbuf_size);
static inline char *av_make_error_string(char *errbuf, size_t errbuf_size, int errnum)
{
av_strerror(errnum, errbuf, errbuf_size);
return errbuf;
}
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
else return (-0x7fffffff - 1);
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
AVRational av_gcd_q(AVRational a, AVRational b, int max_den, AVRational def);
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
AVClassCategory category;
AVClassCategory (*get_category)(void* ctx);
int (*query_ranges)(struct AVOptionRanges **, void *obj, const char *key, int flags);
void* (*child_next)(void *obj, void *prev);
const struct AVClass* (*child_class_iterate)(void **iter);
} AVClass;
void av_log(void *avcl, int level, const char *fmt, ...) __attribute__((__format__(__printf__, 3, 4)));
void av_log_once(void* avcl, int initial_level, int subsequent_level, int *state, const char *fmt, ...) __attribute__((__format__(__printf__, 5, 6)));
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
AV_PIX_FMT_VAAPI,
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
AV_PIX_FMT_YUVA422P12BE,
AV_PIX_FMT_YUVA422P12LE,
AV_PIX_FMT_YUVA444P12BE,
AV_PIX_FMT_YUVA444P12LE,
AV_PIX_FMT_NV24,
AV_PIX_FMT_NV42,
AV_PIX_FMT_VULKAN,
AV_PIX_FMT_Y210BE,
AV_PIX_FMT_Y210LE,
AV_PIX_FMT_X2RGB10LE,
AV_PIX_FMT_X2RGB10BE,
AV_PIX_FMT_X2BGR10LE,
AV_PIX_FMT_X2BGR10BE,
AV_PIX_FMT_P210BE,
AV_PIX_FMT_P210LE,
AV_PIX_FMT_P410BE,
AV_PIX_FMT_P410LE,
AV_PIX_FMT_P216BE,
AV_PIX_FMT_P216LE,
AV_PIX_FMT_P416BE,
AV_PIX_FMT_P416LE,
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
AVCOL_PRI_EBU3213 = 22,
AVCOL_PRI_JEDEC_P22 = AVCOL_PRI_EBU3213,
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
size_t size;
} AVBufferRef;
AVBufferRef *av_buffer_alloc(size_t size);
AVBufferRef *av_buffer_allocz(size_t size);
AVBufferRef *av_buffer_create(uint8_t *data, size_t size,
void (*free)(void *opaque, uint8_t *data),
void *opaque, int flags);
void av_buffer_default_free(void *opaque, uint8_t *data);
AVBufferRef *av_buffer_ref(const AVBufferRef *buf);
void av_buffer_unref(AVBufferRef **buf);
int av_buffer_is_writable(const AVBufferRef *buf);
void *av_buffer_get_opaque(const AVBufferRef *buf);
int av_buffer_get_ref_count(const AVBufferRef *buf);
int av_buffer_make_writable(AVBufferRef **buf);
int av_buffer_realloc(AVBufferRef **buf, size_t size);
int av_buffer_replace(AVBufferRef **dst, const AVBufferRef *src);
typedef struct AVBufferPool AVBufferPool;
AVBufferPool *av_buffer_pool_init(size_t size, AVBufferRef* (*alloc)(size_t size));
AVBufferPool *av_buffer_pool_init2(size_t size, void *opaque,
AVBufferRef* (*alloc)(void *opaque, size_t size),
void (*pool_free)(void *opaque));
void av_buffer_pool_uninit(AVBufferPool **pool);
AVBufferRef *av_buffer_pool_get(AVBufferPool *pool);
void *av_buffer_pool_buffer_get_opaque(const AVBufferRef *ref);
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
AV_FRAME_DATA_S12M_TIMECODE,
AV_FRAME_DATA_DYNAMIC_HDR_PLUS,
AV_FRAME_DATA_REGIONS_OF_INTEREST,
AV_FRAME_DATA_VIDEO_ENC_PARAMS,
AV_FRAME_DATA_SEI_UNREGISTERED,
AV_FRAME_DATA_FILM_GRAIN_PARAMS,
AV_FRAME_DATA_DETECTION_BBOXES,
AV_FRAME_DATA_DOVI_RPU_BUFFER,
AV_FRAME_DATA_DOVI_METADATA,
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
size_t size;
AVDictionary *metadata;
AVBufferRef *buf;
} AVFrameSideData;
typedef struct AVRegionOfInterest {
uint32_t self_size;
int top;
int bottom;
int left;
int right;
AVRational qoffset;
} AVRegionOfInterest;
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
int64_t pkt_dts;
AVRational time_base;
int coded_picture_number;
int display_picture_number;
int quality;
void *opaque;
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
AVBufferRef *hw_frames_ctx;
AVBufferRef *opaque_ref;
size_t crop_top;
size_t crop_bottom;
size_t crop_left;
size_t crop_right;
AVBufferRef *private_ref;
} AVFrame;
__attribute__((deprecated))
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
size_t size);
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
AV_HWDEVICE_TYPE_VULKAN,
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
int av_hwdevice_ctx_create_derived_opts(AVBufferRef **dst_ctx,
enum AVHWDeviceType type,
AVBufferRef *src_ctx,
AVDictionary *options, int flags);
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
AV_CODEC_ID_PGX,
AV_CODEC_ID_AVS3,
AV_CODEC_ID_MSP2,
AV_CODEC_ID_VVC,
AV_CODEC_ID_Y41P,
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
AV_CODEC_ID_HYMT,
AV_CODEC_ID_ARBC,
AV_CODEC_ID_AGM,
AV_CODEC_ID_LSCR,
AV_CODEC_ID_VP4,
AV_CODEC_ID_IMM5,
AV_CODEC_ID_MVDV,
AV_CODEC_ID_MVHA,
AV_CODEC_ID_CDTOONS,
AV_CODEC_ID_MV30,
AV_CODEC_ID_NOTCHLC,
AV_CODEC_ID_PFM,
AV_CODEC_ID_MOBICLIP,
AV_CODEC_ID_PHOTOCD,
AV_CODEC_ID_IPU,
AV_CODEC_ID_ARGO,
AV_CODEC_ID_CRI,
AV_CODEC_ID_SIMBIOSIS_IMX,
AV_CODEC_ID_SGA_VIDEO,
AV_CODEC_ID_GEM,
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
AV_CODEC_ID_PCM_S64LE,
AV_CODEC_ID_PCM_S64BE,
AV_CODEC_ID_PCM_F16LE,
AV_CODEC_ID_PCM_F24LE,
AV_CODEC_ID_PCM_VIDC,
AV_CODEC_ID_PCM_SGA,
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
AV_CODEC_ID_ADPCM_AFC,
AV_CODEC_ID_ADPCM_IMA_OKI,
AV_CODEC_ID_ADPCM_DTK,
AV_CODEC_ID_ADPCM_IMA_RAD,
AV_CODEC_ID_ADPCM_G726LE,
AV_CODEC_ID_ADPCM_THP_LE,
AV_CODEC_ID_ADPCM_PSX,
AV_CODEC_ID_ADPCM_AICA,
AV_CODEC_ID_ADPCM_IMA_DAT4,
AV_CODEC_ID_ADPCM_MTAF,
AV_CODEC_ID_ADPCM_AGM,
AV_CODEC_ID_ADPCM_ARGO,
AV_CODEC_ID_ADPCM_IMA_SSI,
AV_CODEC_ID_ADPCM_ZORK,
AV_CODEC_ID_ADPCM_IMA_APM,
AV_CODEC_ID_ADPCM_IMA_ALP,
AV_CODEC_ID_ADPCM_IMA_MTF,
AV_CODEC_ID_ADPCM_IMA_CUNNING,
AV_CODEC_ID_ADPCM_IMA_MOFLEX,
AV_CODEC_ID_ADPCM_IMA_ACORN,
AV_CODEC_ID_AMR_NB = 0x12000,
AV_CODEC_ID_AMR_WB,
AV_CODEC_ID_RA_144 = 0x13000,
AV_CODEC_ID_RA_288,
AV_CODEC_ID_ROQ_DPCM = 0x14000,
AV_CODEC_ID_INTERPLAY_DPCM,
AV_CODEC_ID_XAN_DPCM,
AV_CODEC_ID_SOL_DPCM,
AV_CODEC_ID_SDX2_DPCM,
AV_CODEC_ID_GREMLIN_DPCM,
AV_CODEC_ID_DERF_DPCM,
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
AV_CODEC_ID_FFWAVESYNTH,
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
AV_CODEC_ID_HCOM,
AV_CODEC_ID_ACELP_KELVIN,
AV_CODEC_ID_MPEGH_3D_AUDIO,
AV_CODEC_ID_SIREN,
AV_CODEC_ID_HCA,
AV_CODEC_ID_FASTAUDIO,
AV_CODEC_ID_MSNSIREN,
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
AV_CODEC_ID_MICRODVD,
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
AV_CODEC_ID_ARIB_CAPTION,
AV_CODEC_ID_FIRST_UNKNOWN = 0x18000,
AV_CODEC_ID_TTF = 0x18000,
AV_CODEC_ID_SCTE_35,
AV_CODEC_ID_EPG,
AV_CODEC_ID_BINTEXT,
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
enum AVMediaType avcodec_get_type(enum AVCodecID codec_id);
const char *avcodec_get_name(enum AVCodecID id);
int av_get_bits_per_sample(enum AVCodecID codec_id);
int av_get_exact_bits_per_sample(enum AVCodecID codec_id);
const char *avcodec_profile_name(enum AVCodecID codec_id, int profile);
enum AVCodecID av_get_pcm_codec(enum AVSampleFormat fmt, int be);
typedef struct AVProfile {
int profile;
const char *name;
} AVProfile;
typedef struct AVCodecDefault AVCodecDefault;
struct AVCodecContext;
struct AVSubtitle;
struct AVPacket;
typedef struct AVCodec {
const char *name;
const char *long_name;
enum AVMediaType type;
enum AVCodecID id;
int capabilities;
uint8_t max_lowres;
const AVRational *supported_framerates;
const enum AVPixelFormat *pix_fmts;
const int *supported_samplerates;
const enum AVSampleFormat *sample_fmts;
const uint64_t *channel_layouts;
const AVClass *priv_class;
const AVProfile *profiles;
const char *wrapper_name;
int caps_internal;
int priv_data_size;
int (*update_thread_context)(struct AVCodecContext *dst, const struct AVCodecContext *src);
int (*update_thread_context_for_user)(struct AVCodecContext *dst, const struct AVCodecContext *src);
const AVCodecDefault *defaults;
void (*init_static_data)(struct AVCodec *codec);
int (*init)(struct AVCodecContext *);
int (*encode_sub)(struct AVCodecContext *, uint8_t *buf, int buf_size,
const struct AVSubtitle *sub);
int (*encode2)(struct AVCodecContext *avctx, struct AVPacket *avpkt,
const struct AVFrame *frame, int *got_packet_ptr);
int (*decode)(struct AVCodecContext *avctx, void *outdata,
int *got_frame_ptr, struct AVPacket *avpkt);
int (*close)(struct AVCodecContext *);
int (*receive_packet)(struct AVCodecContext *avctx, struct AVPacket *avpkt);
int (*receive_frame)(struct AVCodecContext *avctx, struct AVFrame *frame);
void (*flush)(struct AVCodecContext *);
const char *bsfs;
const struct AVCodecHWConfigInternal *const *hw_configs;
const uint32_t *codec_tags;
} AVCodec;
const AVCodec *av_codec_iterate(void **opaque);
const AVCodec *avcodec_find_decoder(enum AVCodecID id);
const AVCodec *avcodec_find_decoder_by_name(const char *name);
const AVCodec *avcodec_find_encoder(enum AVCodecID id);
const AVCodec *avcodec_find_encoder_by_name(const char *name);
int av_codec_is_encoder(const AVCodec *codec);
int av_codec_is_decoder(const AVCodec *codec);
const char *av_get_profile_name(const AVCodec *codec, int profile);
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
const AVCodecHWConfig *avcodec_get_hw_config(const AVCodec *codec, int index);
typedef struct AVCodecDescriptor {
enum AVCodecID id;
enum AVMediaType type;
const char *name;
const char *long_name;
int props;
const char *const *mime_types;
const struct AVProfile *profiles;
} AVCodecDescriptor;
const AVCodecDescriptor *avcodec_descriptor_get(enum AVCodecID id);
const AVCodecDescriptor *avcodec_descriptor_next(const AVCodecDescriptor *prev);
const AVCodecDescriptor *avcodec_descriptor_get_by_name(const char *name);
enum AVFieldOrder {
AV_FIELD_UNKNOWN,
AV_FIELD_PROGRESSIVE,
AV_FIELD_TT,
AV_FIELD_BB,
AV_FIELD_TB,
AV_FIELD_BT,
};
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
AVCodecParameters *avcodec_parameters_alloc(void);
void avcodec_parameters_free(AVCodecParameters **par);
int avcodec_parameters_copy(AVCodecParameters *dst, const AVCodecParameters *src);
int av_get_audio_frame_duration2(AVCodecParameters *par, int frame_bytes);
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
typedef struct AVPanScan {
int id;
int width;
int height;
int16_t position[3][2];
} AVPanScan;
typedef struct AVCPBProperties {
int64_t max_bitrate;
int64_t min_bitrate;
int64_t avg_bitrate;
int64_t buffer_size;
uint64_t vbv_delay;
} AVCPBProperties;
AVCPBProperties *av_cpb_properties_alloc(size_t *size);
typedef struct AVProducerReferenceTime {
int64_t wallclock;
int flags;
} AVProducerReferenceTime;
unsigned int av_xiphlacing(unsigned char *s, unsigned int v);
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
AV_PKT_DATA_PRFT,
AV_PKT_DATA_ICC_PROFILE,
AV_PKT_DATA_DOVI_CONF,
AV_PKT_DATA_S12M_TIMECODE,
AV_PKT_DATA_DYNAMIC_HDR10_PLUS,
AV_PKT_DATA_NB
};
typedef struct AVPacketSideData {
uint8_t *data;
size_t size;
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
void *opaque;
AVBufferRef *opaque_ref;
AVRational time_base;
} AVPacket;
__attribute__((deprecated))
typedef struct AVPacketList {
AVPacket pkt;
struct AVPacketList *next;
} AVPacketList;
enum AVSideDataParamChangeFlags {
AV_SIDE_DATA_PARAM_CHANGE_CHANNEL_COUNT = 0x0001,
AV_SIDE_DATA_PARAM_CHANGE_CHANNEL_LAYOUT = 0x0002,
AV_SIDE_DATA_PARAM_CHANGE_SAMPLE_RATE = 0x0004,
AV_SIDE_DATA_PARAM_CHANGE_DIMENSIONS = 0x0008,
};
AVPacket *av_packet_alloc(void);
AVPacket *av_packet_clone(const AVPacket *src);
void av_packet_free(AVPacket **pkt);
__attribute__((deprecated))
void av_init_packet(AVPacket *pkt);
int av_new_packet(AVPacket *pkt, int size);
void av_shrink_packet(AVPacket *pkt, int size);
int av_grow_packet(AVPacket *pkt, int grow_by);
int av_packet_from_data(AVPacket *pkt, uint8_t *data, int size);
uint8_t* av_packet_new_side_data(AVPacket *pkt, enum AVPacketSideDataType type,
size_t size);
int av_packet_add_side_data(AVPacket *pkt, enum AVPacketSideDataType type,
uint8_t *data, size_t size);
int av_packet_shrink_side_data(AVPacket *pkt, enum AVPacketSideDataType type,
size_t size);
uint8_t* av_packet_get_side_data(const AVPacket *pkt, enum AVPacketSideDataType type,
size_t *size);
const char *av_packet_side_data_name(enum AVPacketSideDataType type);
uint8_t *av_packet_pack_dictionary(AVDictionary *dict, size_t *size);
int av_packet_unpack_dictionary(const uint8_t *data, size_t size,
AVDictionary **dict);
void av_packet_free_side_data(AVPacket *pkt);
int av_packet_ref(AVPacket *dst, const AVPacket *src);
void av_packet_unref(AVPacket *pkt);
void av_packet_move_ref(AVPacket *dst, AVPacket *src);
int av_packet_copy_props(AVPacket *dst, const AVPacket *src);
int av_packet_make_refcounted(AVPacket *pkt);
int av_packet_make_writable(AVPacket *pkt);
void av_packet_rescale_ts(AVPacket *pkt, AVRational tb_src, AVRational tb_dst);
typedef struct RcOverride{
int start_frame;
int end_frame;
int qscale;
float quality_factor;
} RcOverride;
struct AVCodecInternal;
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
float b_quant_offset;
int has_b_frames;
float i_quant_factor;
float i_quant_offset;
float lumi_masking;
float temporal_cplx_masking;
float spatial_cplx_masking;
float p_masking;
float dark_masking;
int slice_count;
int *slice_offset;
AVRational sample_aspect_ratio;
int me_cmp;
int me_sub_cmp;
int mb_cmp;
int ildct_cmp;
int dia_size;
int last_predictor_count;
int me_pre_cmp;
int pre_dia_size;
int me_subpel_quality;
int me_range;
int slice_flags;
int mb_decision;
uint16_t *intra_matrix;
uint16_t *inter_matrix;
int intra_dc_precision;
int skip_top;
int skip_bottom;
int mb_lmin;
int mb_lmax;
int bidir_refine;
int keyint_min;
int refs;
int mv0_threshold;
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
int trellis;
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
int thread_count;
int thread_type;
int active_thread_type;
__attribute__((deprecated))
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
__attribute__((deprecated))
int debug_mv;
uint16_t *chroma_intra_matrix;
uint8_t *dump_separator;
char *codec_whitelist;
unsigned properties;
AVPacketSideData *coded_side_data;
int nb_coded_side_data;
AVBufferRef *hw_frames_ctx;
__attribute__((deprecated))
int sub_text_format;
int trailing_padding;
int64_t max_pixels;
AVBufferRef *hw_device_ctx;
int hwaccel_flags;
int apply_cropping;
int extra_hw_frames;
int discard_damaged_percentage;
int64_t max_samples;
int export_side_data;
int (*get_encode_buffer)(struct AVCodecContext *s, AVPacket *pkt, int flags);
} AVCodecContext;
struct MpegEncContext;
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
unsigned avcodec_version(void);
const char *avcodec_configuration(void);
const char *avcodec_license(void);
AVCodecContext *avcodec_alloc_context3(const AVCodec *codec);
void avcodec_free_context(AVCodecContext **avctx);
const AVClass *avcodec_get_class(void);
__attribute__((deprecated))
const AVClass *avcodec_get_frame_class(void);
const AVClass *avcodec_get_subtitle_rect_class(void);
int avcodec_parameters_from_context(AVCodecParameters *par,
const AVCodecContext *codec);
int avcodec_parameters_to_context(AVCodecContext *codec,
const AVCodecParameters *par);
int avcodec_open2(AVCodecContext *avctx, const AVCodec *codec, AVDictionary **options);
int avcodec_close(AVCodecContext *avctx);
void avsubtitle_free(AVSubtitle *sub);
int avcodec_default_get_buffer2(AVCodecContext *s, AVFrame *frame, int flags);
int avcodec_default_get_encode_buffer(AVCodecContext *s, AVPacket *pkt, int flags);
void avcodec_align_dimensions(AVCodecContext *s, int *width, int *height);
void avcodec_align_dimensions2(AVCodecContext *s, int *width, int *height,
int linesize_align[8]);
int avcodec_enum_to_chroma_pos(int *xpos, int *ypos, enum AVChromaLocation pos);
enum AVChromaLocation avcodec_chroma_pos_to_enum(int xpos, int ypos);
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
const struct AVCodecParser *parser;
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
int codec_ids[7];
int priv_data_size;
int (*parser_init)(AVCodecParserContext *s);
int (*parser_parse)(AVCodecParserContext *s,
AVCodecContext *avctx,
const uint8_t **poutbuf, int *poutbuf_size,
const uint8_t *buf, int buf_size);
void (*parser_close)(AVCodecParserContext *s);
int (*split)(AVCodecContext *avctx, const uint8_t *buf, int buf_size);
} AVCodecParser;
const AVCodecParser *av_parser_iterate(void **opaque);
AVCodecParserContext *av_parser_init(int codec_id);
int av_parser_parse2(AVCodecParserContext *s,
AVCodecContext *avctx,
uint8_t **poutbuf, int *poutbuf_size,
const uint8_t *buf, int buf_size,
int64_t pts, int64_t dts,
int64_t pos);
void av_parser_close(AVCodecParserContext *s);
int avcodec_encode_subtitle(AVCodecContext *avctx, uint8_t *buf, int buf_size,
const AVSubtitle *sub);
unsigned int avcodec_pix_fmt_to_codec_tag(enum AVPixelFormat pix_fmt);
enum AVPixelFormat avcodec_find_best_pix_fmt_of_list(const enum AVPixelFormat *pix_fmt_list,
enum AVPixelFormat src_pix_fmt,
int has_alpha, int *loss_ptr);
enum AVPixelFormat avcodec_default_get_format(struct AVCodecContext *s, const enum AVPixelFormat * fmt);
void avcodec_string(char *buf, int buf_size, AVCodecContext *enc, int encode);
int avcodec_default_execute(AVCodecContext *c, int (*func)(AVCodecContext *c2, void *arg2),void *arg, int *ret, int count, int size);
int avcodec_default_execute2(AVCodecContext *c, int (*func)(AVCodecContext *c2, void *arg2, int, int),void *arg, int *ret, int count);
int avcodec_fill_audio_frame(AVFrame *frame, int nb_channels,
enum AVSampleFormat sample_fmt, const uint8_t *buf,
int buf_size, int align);
void avcodec_flush_buffers(AVCodecContext *avctx);
int av_get_audio_frame_duration(AVCodecContext *avctx, int frame_bytes);
void av_fast_padded_malloc(void *ptr, unsigned int *size, size_t min_size);
void av_fast_padded_mallocz(void *ptr, unsigned int *size, size_t min_size);
int avcodec_is_open(AVCodecContext *s);
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
long int tm_gmtoff;
const char *tm_zone;
};
struct itimerspec
{
struct timespec it_interval;
struct timespec it_value;
};
struct sigevent;
extern clock_t clock (void) __attribute__ ((__nothrow__ , __leaf__));
extern time_t time (time_t *__timer) __attribute__ ((__nothrow__ , __leaf__));
extern double difftime (time_t __time1, time_t __time0)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern time_t mktime (struct tm *__tp) __attribute__ ((__nothrow__ , __leaf__));
extern size_t strftime (char *__restrict __s, size_t __maxsize,
const char *__restrict __format,
const struct tm *__restrict __tp) __attribute__ ((__nothrow__ , __leaf__));
extern size_t strftime_l (char *__restrict __s, size_t __maxsize,
const char *__restrict __format,
const struct tm *__restrict __tp,
locale_t __loc) __attribute__ ((__nothrow__ , __leaf__));
extern struct tm *gmtime (const time_t *__timer) __attribute__ ((__nothrow__ , __leaf__));
extern struct tm *localtime (const time_t *__timer) __attribute__ ((__nothrow__ , __leaf__));
extern struct tm *gmtime_r (const time_t *__restrict __timer,
struct tm *__restrict __tp) __attribute__ ((__nothrow__ , __leaf__));
extern struct tm *localtime_r (const time_t *__restrict __timer,
struct tm *__restrict __tp) __attribute__ ((__nothrow__ , __leaf__));
extern char *asctime (const struct tm *__tp) __attribute__ ((__nothrow__ , __leaf__));
extern char *ctime (const time_t *__timer) __attribute__ ((__nothrow__ , __leaf__));
extern char *asctime_r (const struct tm *__restrict __tp,
char *__restrict __buf) __attribute__ ((__nothrow__ , __leaf__));
extern char *ctime_r (const time_t *__restrict __timer,
char *__restrict __buf) __attribute__ ((__nothrow__ , __leaf__));
extern char *__tzname[2];
extern int __daylight;
extern long int __timezone;
extern char *tzname[2];
extern void tzset (void) __attribute__ ((__nothrow__ , __leaf__));
extern int daylight;
extern long int timezone;
extern time_t timegm (struct tm *__tp) __attribute__ ((__nothrow__ , __leaf__));
extern time_t timelocal (struct tm *__tp) __attribute__ ((__nothrow__ , __leaf__));
extern int dysize (int __year) __attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__const__));
extern int nanosleep (const struct timespec *__requested_time,
struct timespec *__remaining);
extern int clock_getres (clockid_t __clock_id, struct timespec *__res) __attribute__ ((__nothrow__ , __leaf__));
extern int clock_gettime (clockid_t __clock_id, struct timespec *__tp) __attribute__ ((__nothrow__ , __leaf__));
extern int clock_settime (clockid_t __clock_id, const struct timespec *__tp)
__attribute__ ((__nothrow__ , __leaf__));
extern int clock_nanosleep (clockid_t __clock_id, int __flags,
const struct timespec *__req,
struct timespec *__rem);
extern int clock_getcpuclockid (pid_t __pid, clockid_t *__clock_id) __attribute__ ((__nothrow__ , __leaf__));
extern int timer_create (clockid_t __clock_id,
struct sigevent *__restrict __evp,
timer_t *__restrict __timerid) __attribute__ ((__nothrow__ , __leaf__));
extern int timer_delete (timer_t __timerid) __attribute__ ((__nothrow__ , __leaf__));
extern int timer_settime (timer_t __timerid, int __flags,
const struct itimerspec *__restrict __value,
struct itimerspec *__restrict __ovalue) __attribute__ ((__nothrow__ , __leaf__));
extern int timer_gettime (timer_t __timerid, struct itimerspec *__value)
__attribute__ ((__nothrow__ , __leaf__));
extern int timer_getoverrun (timer_t __timerid) __attribute__ ((__nothrow__ , __leaf__));
extern int timespec_get (struct timespec *__ts, int __base)
__attribute__ ((__nothrow__ , __leaf__)) __attribute__ ((__nonnull__ (1)));
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
int error;
int write_flag;
int max_packet_size;
int min_packet_size;
unsigned long checksum;
unsigned char *checksum_ptr;
unsigned long (*update_checksum)(unsigned long checksum, const uint8_t *buf, unsigned int size);
int (*read_pause)(void *opaque, int pause);
int64_t (*read_seek)(void *opaque, int stream_index,
int64_t timestamp, int flags);
int seekable;
int direct;
const char *protocol_whitelist;
const char *protocol_blacklist;
int (*write_data_type)(void *opaque, uint8_t *buf, int buf_size,
enum AVIODataMarkerType type, int64_t time);
int ignore_boundary_point;
__attribute__((deprecated))
int64_t written;
unsigned char *buf_ptr_max;
int64_t bytes_read;
int64_t bytes_written;
} AVIOContext;
const char *avio_find_protocol_name(const char *url);
int avio_check(const char *url, int flags);
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
return avio_seek(s, 0, 1);
}
int64_t avio_size(AVIOContext *s);
int avio_feof(AVIOContext *s);
int avio_printf(AVIOContext *s, const char *fmt, ...) __attribute__((__format__(__printf__, 2, 3)));
void avio_print_string_array(AVIOContext *s, const char *strings[]);
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
const AVClass *avio_protocol_get_class(const char *name);
int avio_pause(AVIOContext *h, int pause);
int64_t avio_seek_time(AVIOContext *h, int stream_index,
int64_t timestamp, int flags);
struct AVBPrint;
int avio_read_to_bprint(AVIOContext *h, struct AVBPrint *pb, size_t max_size);
int avio_accept(AVIOContext *s, AVIOContext **c);
int avio_handshake(AVIOContext *c);
struct AVFormatContext;
struct AVStream;
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
int priv_data_size;
int flags_internal;
int (*write_header)(struct AVFormatContext *);
int (*write_packet)(struct AVFormatContext *, AVPacket *pkt);
int (*write_trailer)(struct AVFormatContext *);
int (*interleave_packet)(struct AVFormatContext *s, AVPacket *pkt,
int flush, int has_packet);
int (*query_codec)(enum AVCodecID id, int std_compliance);
void (*get_output_timestamp)(struct AVFormatContext *s, int stream,
int64_t *dts, int64_t *wall);
int (*control_message)(struct AVFormatContext *s, int type,
void *data, size_t data_size);
int (*write_uncoded_frame)(struct AVFormatContext *, int stream_index,
AVFrame **frame, unsigned flags);
int (*get_device_list)(struct AVFormatContext *s, struct AVDeviceInfoList *device_list);
enum AVCodecID data_codec;
int (*init)(struct AVFormatContext *);
void (*deinit)(struct AVFormatContext *);
int (*check_bitstream)(struct AVFormatContext *s, struct AVStream *st,
const AVPacket *pkt);
} AVOutputFormat;
typedef struct AVInputFormat {
const char *name;
const char *long_name;
int flags;
const char *extensions;
const struct AVCodecTag * const *codec_tag;
const AVClass *priv_class;
const char *mime_type;
int raw_codec_id;
int priv_data_size;
int flags_internal;
int (*read_probe)(const AVProbeData *);
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
int av_disposition_from_string(const char *disp);
const char *av_disposition_to_string(int disposition);
typedef struct AVStream {
int index;
int id;
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
AVCodecParameters *codecpar;
int pts_wrap_bits;
} AVStream;
struct AVCodecParserContext *av_stream_get_parser(const AVStream *s);
int64_t av_stream_get_end_pts(const AVStream *st);
int64_t av_stream_get_first_dts(const AVStream *st);
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
int64_t id;
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
typedef struct AVFormatContext {
const AVClass *av_class;
const struct AVInputFormat *iformat;
const struct AVOutputFormat *oformat;
void *priv_data;
AVIOContext *pb;
int ctx_flags;
unsigned int nb_streams;
AVStream **streams;
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
int io_repositioned;
const AVCodec *video_codec;
const AVCodec *audio_codec;
const AVCodec *subtitle_codec;
const AVCodec *data_codec;
int metadata_header_padding;
void *opaque;
av_format_control_message control_message_cb;
int64_t output_ts_offset;
uint8_t *dump_separator;
enum AVCodecID data_codec_id;
char *protocol_whitelist;
int (*io_open)(struct AVFormatContext *s, AVIOContext **pb, const char *url,
int flags, AVDictionary **options);
void (*io_close)(struct AVFormatContext *s, AVIOContext *pb);
char *protocol_blacklist;
int max_streams;
int skip_estimate_duration_from_pts;
int max_probe_packets;
int (*io_close2)(struct AVFormatContext *s, AVIOContext *pb);
} AVFormatContext;
void av_format_inject_global_side_data(AVFormatContext *s);
enum AVDurationEstimationMethod av_fmt_ctx_get_duration_estimation_method(const AVFormatContext* ctx);
unsigned avformat_version(void);
const char *avformat_configuration(void);
const char *avformat_license(void);
int avformat_network_init(void);
int avformat_network_deinit(void);
const AVOutputFormat *av_muxer_iterate(void **opaque);
const AVInputFormat *av_demuxer_iterate(void **opaque);
AVFormatContext *avformat_alloc_context(void);
void avformat_free_context(AVFormatContext *s);
const AVClass *avformat_get_class(void);
const AVClass *av_stream_get_class(void);
AVStream *avformat_new_stream(AVFormatContext *s, const AVCodec *c);
int av_stream_add_side_data(AVStream *st, enum AVPacketSideDataType type,
uint8_t *data, size_t size);
uint8_t *av_stream_new_side_data(AVStream *stream,
enum AVPacketSideDataType type, size_t size);
uint8_t *av_stream_get_side_data(const AVStream *stream,
enum AVPacketSideDataType type, size_t *size);
AVProgram *av_new_program(AVFormatContext *s, int id);
int avformat_alloc_output_context2(AVFormatContext **ctx, const AVOutputFormat *oformat,
const char *format_name, const char *filename);
const AVInputFormat *av_find_input_format(const char *short_name);
const AVInputFormat *av_probe_input_format(const AVProbeData *pd, int is_opened);
const AVInputFormat *av_probe_input_format2(const AVProbeData *pd,
int is_opened, int *score_max);
const AVInputFormat *av_probe_input_format3(const AVProbeData *pd,
int is_opened, int *score_ret);
int av_probe_input_buffer2(AVIOContext *pb, const AVInputFormat **fmt,
const char *url, void *logctx,
unsigned int offset, unsigned int max_probe_size);
int av_probe_input_buffer(AVIOContext *pb, const AVInputFormat **fmt,
const char *url, void *logctx,
unsigned int offset, unsigned int max_probe_size);
int avformat_open_input(AVFormatContext **ps, const char *url,
const AVInputFormat *fmt, AVDictionary **options);
int avformat_find_stream_info(AVFormatContext *ic, AVDictionary **options);
AVProgram *av_find_program_from_stream(AVFormatContext *ic, AVProgram *last, int s);
void av_program_add_stream_index(AVFormatContext *ac, int progid, unsigned int idx);
int av_find_best_stream(AVFormatContext *ic,
enum AVMediaType type,
int wanted_stream_nb,
int related_stream,
const AVCodec **decoder_ret,
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
const AVOutputFormat *av_guess_format(const char *short_name,
const char *filename,
const char *mime_type);
enum AVCodecID av_guess_codec(const AVOutputFormat *fmt, const char *short_name,
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
int avformat_index_get_entries_count(const AVStream *st);
const AVIndexEntry *avformat_index_get_entry(AVStream *st, int idx);
const AVIndexEntry *avformat_index_get_entry_from_timestamp(AVStream *st,
int64_t wanted_timestamp,
int flags);
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
int av_image_fill_plane_sizes(size_t size[4], enum AVPixelFormat pix_fmt,
int height, const ptrdiff_t linesizes[4]);
int av_image_fill_pointers(uint8_t *data[4], enum AVPixelFormat pix_fmt, int height,
uint8_t *ptr, const int linesizes[4]);
int av_image_alloc(uint8_t *pointers[4], int linesizes[4],
int w, int h, enum AVPixelFormat pix_fmt, int align);
void av_image_copy_plane(uint8_t *dst, int dst_linesize,
const uint8_t *src, int src_linesize,
int bytewidth, int height);
void av_image_copy_plane_uc_from(uint8_t *dst, ptrdiff_t dst_linesize,
const uint8_t *src, ptrdiff_t src_linesize,
ptrdiff_t bytewidth, int height);
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
int sws_scale_frame(struct SwsContext *c, AVFrame *dst, const AVFrame *src);
int sws_frame_start(struct SwsContext *c, AVFrame *dst, const AVFrame *src);
void sws_frame_end(struct SwsContext *c);
int sws_send_slice(struct SwsContext *c, unsigned int slice_start,
unsigned int slice_height);
int sws_receive_slice(struct SwsContext *c, unsigned int slice_start,
unsigned int slice_height);
unsigned int sws_receive_slice_alignment(const struct SwsContext *c);
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
]]
