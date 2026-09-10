/*
 * lipi_runtime.h — Lipi Native Runtime Support Library
 * WHY: Every Lipi→C compiled program links against this header.
 *      Provides the type system, builtins, and memory model.
 *
 * Design decisions:
 *   - All Lipi values are LipiVal (tagged union)
 *   - Numbers are double (like JS/Lua — no int/float split)
 *   - Strings are heap-allocated char* (strdup)
 *   - Structs are LipiStruct (name + fields array)
 *   - Lists are LipiList (dynamic array)
 *   - NO garbage collector — arena or manual free for now
 */
#ifndef LIPI_RUNTIME_H
#define LIPI_RUNTIME_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdarg.h>
#include <time.h>
#include <ctype.h>  /* WHY: toupper/tolower for string ops */


/* ── Value Types ──────────────────────────────────────────── */
typedef enum {
    LV_NULL   = 0,
    LV_NUM    = 1,   /* double */
    LV_STR    = 2,   /* char* (heap) */
    LV_BOOL   = 3,   /* int: 1=true, 0=false */
    LV_LIST   = 4,   /* LipiList* */
    LV_STRUCT = 5,   /* LipiStruct* */
    LV_FN     = 6,   /* function pointer */
} LipiType;

/* Forward declarations */
typedef struct LipiVal   LipiVal;
typedef struct LipiList  LipiList;
typedef struct LipiStruct LipiStruct;

/* Dynamic list */
struct LipiList {
    LipiVal* items;
    int      count;
    int      cap;
};

/* Struct instance */
struct LipiStruct {
    const char* type_name;
    const char** field_names;
    LipiVal*     field_vals;
    int          field_count;
};

/* The universal Lipi value */
struct LipiVal {
    LipiType type;
    union {
        double       num;
        char*        str;
        int          bool_val;
        LipiList*    list;
        LipiStruct*  strct;
        LipiVal      (*fn)(LipiVal*, int);
    };
};

/* ── Constructors ─────────────────────────────────────────── */
static inline LipiVal lv_null()  { return (LipiVal){ LV_NULL }; }
static inline LipiVal lv_num(double n)  { LipiVal v; v.type=LV_NUM;  v.num=n;  return v; }
static inline LipiVal lv_bool(int b)    { LipiVal v; v.type=LV_BOOL; v.bool_val=b; return v; }

static inline LipiVal lv_str(const char* s) {
    LipiVal v;
    v.type = LV_STR;
    v.str  = s ? strdup(s) : strdup("");
    return v;
}

/* ── Type checks ──────────────────────────────────────────── */
static inline int lv_truthy(LipiVal v) {
    switch (v.type) {
        case LV_NULL:  return 0;
        case LV_NUM:   return v.num != 0.0;
        case LV_STR:   return v.str[0] != '\0';
        case LV_BOOL:  return v.bool_val;
        case LV_LIST:  return v.list->count > 0;
        default:       return 1;
    }
}

static inline int lv_equal(LipiVal a, LipiVal b) {
    if (a.type != b.type) return 0;
    switch (a.type) {
        case LV_NULL:  return 1;
        case LV_NUM:   return a.num == b.num;
        case LV_STR:   return strcmp(a.str, b.str) == 0;
        case LV_BOOL:  return a.bool_val == b.bool_val;
        default:       return 0;
    }
}

/* ── String conversion ────────────────────────────────────── */
static char _lv_buf[256];

static inline const char* lv_to_str(LipiVal v) {
    switch (v.type) {
        case LV_NULL:  return "null";
        case LV_STR:   return v.str;
        case LV_BOOL:  return v.bool_val ? "true" : "false";
        case LV_LIST:  return "[list]";
        case LV_STRUCT: return v.strct ? v.strct->type_name : "[struct]";
        case LV_NUM: {
            /* WHY: Print integers without decimal point (42 not 42.0) */
            if (v.num == (long long)v.num && v.num >= -1e15 && v.num <= 1e15) {
                snprintf(_lv_buf, sizeof(_lv_buf), "%lld", (long long)v.num);
            } else {
                snprintf(_lv_buf, sizeof(_lv_buf), "%g", v.num);
            }
            return _lv_buf;
        }
        default: return "?";
    }
}

/* ── Arithmetic operators ─────────────────────────────────── */
static inline LipiVal lv_add(LipiVal a, LipiVal b) {
    /* WHY: "hello" + "world" = string concat; num + num = math */
    if (a.type == LV_STR || b.type == LV_STR) {
        const char* sa = lv_to_str(a);
        const char* sb = lv_to_str(b);
        size_t la = strlen(sa), lb = strlen(sb);
        char* res = (char*)malloc(la + lb + 1);
        memcpy(res, sa, la);
        memcpy(res + la, sb, lb + 1);
        LipiVal v; v.type = LV_STR; v.str = res;
        return v;
    }
    return lv_num(a.num + b.num);
}
static inline LipiVal lv_sub(LipiVal a, LipiVal b) { return lv_num(a.num - b.num); }
static inline LipiVal lv_mul(LipiVal a, LipiVal b) { return lv_num(a.num * b.num); }
static inline LipiVal lv_div(LipiVal a, LipiVal b) {
    if (b.num == 0.0) { fprintf(stderr, "❌ Runtime Error: division by zero\n"); exit(1); }
    return lv_num(a.num / b.num);
}
static inline LipiVal lv_mod(LipiVal a, LipiVal b) {
    if (b.num == 0.0) { fprintf(stderr, "❌ Runtime Error: modulo by zero\n"); exit(1); }
    return lv_num(fmod(a.num, b.num));
}

static inline LipiVal lv_neg(LipiVal a) { return lv_num(-a.num); }

static inline int lv_lt(LipiVal a, LipiVal b) {
    if (a.type == LV_NUM && b.type == LV_NUM) return a.num < b.num;
    if (a.type == LV_STR && b.type == LV_STR) return strcmp(a.str, b.str) < 0;
    return 0;
}
static inline int lv_le(LipiVal a, LipiVal b) { return lv_lt(a,b) || lv_equal(a,b); }
static inline int lv_gt(LipiVal a, LipiVal b) { return lv_lt(b,a); }
static inline int lv_ge(LipiVal a, LipiVal b) { return lv_le(b,a); }

/* ── say / print ──────────────────────────────────────────── */
static inline void lipi_say(LipiVal v) {
    if (v.type == LV_NUM) {
        if (v.num == (long long)v.num && v.num >= -1e15 && v.num <= 1e15)
            printf("%lld\n", (long long)v.num);
        else
            printf("%g\n", v.num);
    } else {
        printf("%s\n", lv_to_str(v));
    }
}

/* ── List operations ──────────────────────────────────────── */
static inline LipiList* lv_list_new() {
    LipiList* lst = (LipiList*)malloc(sizeof(LipiList));
    lst->cap   = 8;
    lst->count = 0;
    lst->items = (LipiVal*)malloc(sizeof(LipiVal) * lst->cap);
    return lst;
}

static inline LipiVal lv_list_make(int n, ...) {
    va_list args;
    va_start(args, n);
    LipiList* lst = lv_list_new();
    for (int i = 0; i < n; i++) {
        if (lst->count == lst->cap) {
            lst->cap *= 2;
            lst->items = (LipiVal*)realloc(lst->items, sizeof(LipiVal) * lst->cap);
        }
        lst->items[lst->count++] = va_arg(args, LipiVal);
    }
    va_end(args);
    LipiVal v; v.type = LV_LIST; v.list = lst;
    return v;
}

static inline LipiVal lv_push(LipiVal lst_val, LipiVal item) {
    if (lst_val.type != LV_LIST) {
        fprintf(stderr, "❌ push: not a list\n"); exit(1);
    }
    LipiList* lst = lst_val.list;
    if (lst->count == lst->cap) {
        lst->cap *= 2;
        lst->items = (LipiVal*)realloc(lst->items, sizeof(LipiVal) * lst->cap);
    }
    lst->items[lst->count++] = item;
    return lst_val;
}

static inline LipiVal lv_get(LipiVal lst_val, LipiVal idx) {
    if (lst_val.type != LV_LIST) { fprintf(stderr,"❌ get: not a list\n"); exit(1); }
    int i = (int)idx.num;
    if (i < 0 || i >= lst_val.list->count) { fprintf(stderr,"❌ index out of range: %d\n", i); exit(1); }
    return lst_val.list->items[i];
}

static inline LipiVal lv_len(LipiVal v) {
    if (v.type == LV_STR)  return lv_num(strlen(v.str));
    if (v.type == LV_LIST) return lv_num(v.list->count);
    return lv_num(0);
}

/* WHY: lv_list_set_ret — set list[i]=val and return the list (for inline assignment)
   Lipi's list_set() mutates the list in-place and returns it. */
static inline LipiVal lv_list_set_ret(LipiVal lst_val, LipiVal idx, LipiVal val) {
    if (lst_val.type != LV_LIST) { fprintf(stderr,"❌ list_set: not a list\n"); exit(1); }
    int i = (int)idx.num;
    if (i < 0 || i >= lst_val.list->count) { fprintf(stderr,"❌ list_set: index out of range: %d\n", i); exit(1); }
    lst_val.list->items[i] = val;
    return lst_val;
}

/* WHY: lv_pop — remove and return the last element of a list */
static inline LipiVal lv_pop(LipiVal lst_val) {
    if (lst_val.type != LV_LIST || lst_val.list->count == 0) return lv_null();
    lst_val.list->count--;
    return lst_val.list->items[lst_val.list->count];
}

/* WHY: lv_sort — sort a list of numbers in ascending order (bubble sort) */
static inline LipiVal lv_sort(LipiVal lst) {
    if (lst.type != LV_LIST) return lst;
    int n = lst.list->count;
    for (int i = 0; i < n-1; i++)
        for (int j = 0; j < n-i-1; j++)
            if (lst.list->items[j].num > lst.list->items[j+1].num) {
                LipiVal tmp = lst.list->items[j];
                lst.list->items[j] = lst.list->items[j+1];
                lst.list->items[j+1] = tmp;
            }
    return lst;
}

/* WHY: lv_sum — sum all numeric elements in a list */
static inline LipiVal lv_sum(LipiVal lst) {
    if (lst.type != LV_LIST) return lv_num(0);
    double s = 0;
    for (int i = 0; i < lst.list->count; i++) s += lst.list->items[i].num;
    return lv_num(s);
}

/* WHY: lv_join — join a list of values into a single string with a separator */
static inline LipiVal lv_join(LipiVal lst, LipiVal sep) {
    if (lst.type != LV_LIST) return lv_str("");
    const char* sep_str = (sep.type == LV_STR) ? sep.str : "";
    char buf[65536]; buf[0] = '\0';
    for (int i = 0; i < lst.list->count; i++) {
        if (i > 0) strncat(buf, sep_str, sizeof(buf)-strlen(buf)-1);
        const char* vs = lv_to_str(lst.list->items[i]);
        strncat(buf, vs, sizeof(buf)-strlen(buf)-1);
    }
    return lv_str(buf);
}

/* ── String ops ──────────────────────────────────────────────── */
static inline LipiVal lv_str_upper(LipiVal v) {
    if (v.type != LV_STR) return v;
    char* buf = strdup(v.str);
    for (int i = 0; buf[i]; i++) buf[i] = toupper((unsigned char)buf[i]);
    LipiVal r = lv_str(buf); free(buf); return r;
}
static inline LipiVal lv_str_lower(LipiVal v) {
    if (v.type != LV_STR) return v;
    char* buf = strdup(v.str);
    for (int i = 0; buf[i]; i++) buf[i] = tolower((unsigned char)buf[i]);
    LipiVal r = lv_str(buf); free(buf); return r;
}
static inline LipiVal lv_str_trim(LipiVal v) {
    if (v.type != LV_STR) return v;
    const char* s = v.str;
    while (*s && isspace((unsigned char)*s)) s++;
    char* buf = strdup(s);
    int len = (int)strlen(buf);
    while (len > 0 && isspace((unsigned char)buf[len-1])) buf[--len] = '\0';
    LipiVal r = lv_str(buf); free(buf); return r;
}
static inline LipiVal lv_contains(LipiVal haystack, LipiVal needle) {
    if (haystack.type == LV_STR && needle.type == LV_STR)
        return lv_bool(strstr(haystack.str, needle.str) != NULL);
    if (haystack.type == LV_LIST) {
        for (int i=0;i<haystack.list->count;i++)
            if (lv_equal(haystack.list->items[i], needle)) return lv_bool(1);
    }
    return lv_bool(0);
}
static inline LipiVal lv_starts_with(LipiVal s, LipiVal prefix) {
    if (s.type != LV_STR || prefix.type != LV_STR) return lv_bool(0);
    return lv_bool(strncmp(s.str, prefix.str, strlen(prefix.str)) == 0);
}
static inline LipiVal lv_ends_with(LipiVal s, LipiVal suffix) {
    if (s.type != LV_STR || suffix.type != LV_STR) return lv_bool(0);
    size_t sl = strlen(s.str), el = strlen(suffix.str);
    if (el > sl) return lv_bool(0);
    return lv_bool(strcmp(s.str + sl - el, suffix.str) == 0);
}
static inline LipiVal lv_replace(LipiVal s, LipiVal from, LipiVal to) {
    if (s.type != LV_STR || from.type != LV_STR || to.type != LV_STR) return s;
    char buf[65536]; buf[0] = '\0';
    const char* p = s.str;
    size_t fl = strlen(from.str);
    while (*p) {
        if (fl > 0 && strncmp(p, from.str, fl) == 0) {
            strncat(buf, to.str, sizeof(buf)-strlen(buf)-1);
            p += fl;
        } else {
            char tmp[2] = {*p, '\0'};
            strncat(buf, tmp, sizeof(buf)-strlen(buf)-1);
            p++;
        }
    }
    return lv_str(buf);
}
static inline LipiVal lv_char_at(LipiVal s, LipiVal idx) {
    if (s.type != LV_STR) return lv_str("");
    /* WHY: Handle UTF-8 — count Unicode code points not bytes */
    const unsigned char* p = (const unsigned char*)s.str;
    int i = (int)idx.num;
    int pos = 0;
    while (*p) {
        if (pos == i) {
            /* Extract one UTF-8 character */
            int len = 1;
            if ((*p & 0x80) == 0) len = 1;
            else if ((*p & 0xE0) == 0xC0) len = 2;
            else if ((*p & 0xF0) == 0xE0) len = 3;
            else if ((*p & 0xF8) == 0xF0) len = 4;
            char tmp[5]; memcpy(tmp, p, len); tmp[len] = '\0';
            return lv_str(tmp);
        }
        /* Skip UTF-8 bytes */
        if ((*p & 0x80) == 0) p++;
        else if ((*p & 0xE0) == 0xC0) p += 2;
        else if ((*p & 0xF0) == 0xE0) p += 3;
        else if ((*p & 0xF8) == 0xF0) p += 4;
        else p++;
        pos++;
    }
    return lv_str("");
}
static inline LipiVal lv_index_of(LipiVal s, LipiVal needle) {
    if (s.type == LV_STR && needle.type == LV_STR) {
        const char* p = strstr(s.str, needle.str);
        if (!p) return lv_num(-1);
        return lv_num(p - s.str);
    }
    if (s.type == LV_LIST) {
        for (int i=0;i<s.list->count;i++)
            if (lv_equal(s.list->items[i], needle)) return lv_num(i);
        return lv_num(-1);
    }
    return lv_num(-1);
}
static inline LipiVal lv_split(LipiVal s, LipiVal sep) {
    LipiVal result = lv_list_make(0);
    if (s.type != LV_STR) { lv_push(result, s); return result; }
    if (sep.type != LV_STR || strlen(sep.str) == 0) {
        /* Split by whitespace */
        char* buf = strdup(s.str);
        char* tok = strtok(buf, " \t\n\r");
        while (tok) { result = lv_push(result, lv_str(tok)); tok = strtok(NULL, " \t\n\r"); }
        free(buf);
        return result;
    }
    const char* p = s.str;
    size_t sl = strlen(sep.str);
    while (*p) {
        const char* q = strstr(p, sep.str);
        if (!q) { result = lv_push(result, lv_str(p)); break; }
        char tmp[q-p+1]; memcpy(tmp, p, q-p); tmp[q-p] = '\0';
        result = lv_push(result, lv_str(tmp));
        p = q + sl;
    }
    return result;
}
static inline LipiVal lv_ord(LipiVal v) {
    if (v.type != LV_STR || !v.str[0]) return lv_num(0);
    /* WHY: Decode first UTF-8 code point */
    const unsigned char* p = (const unsigned char*)v.str;
    int cp = 0;
    if ((*p & 0x80) == 0) cp = *p;
    else if ((*p & 0xE0) == 0xC0) cp = ((*p & 0x1F)<<6) | (p[1] & 0x3F);
    else if ((*p & 0xF0) == 0xE0) cp = ((*p & 0x0F)<<12) | ((p[1] & 0x3F)<<6) | (p[2] & 0x3F);
    else if ((*p & 0xF8) == 0xF0) cp = ((*p & 0x07)<<18) | ((p[1] & 0x3F)<<12) | ((p[2] & 0x3F)<<6) | (p[3] & 0x3F);
    return lv_num(cp);
}
static inline LipiVal lv_chr(LipiVal v) {
    int cp = (int)v.num;
    char buf[5] = {0};
    if (cp < 0x80) { buf[0] = cp; }
    else if (cp < 0x800) { buf[0]=0xC0|(cp>>6); buf[1]=0x80|(cp&0x3F); }
    else if (cp < 0x10000) { buf[0]=0xE0|(cp>>12); buf[1]=0x80|((cp>>6)&0x3F); buf[2]=0x80|(cp&0x3F); }
    else { buf[0]=0xF0|(cp>>18); buf[1]=0x80|((cp>>12)&0x3F); buf[2]=0x80|((cp>>6)&0x3F); buf[3]=0x80|(cp&0x3F); }
    return lv_str(buf);
}

/* ── File I/O ────────────────────────────────────────────────── */
static inline LipiVal lv_file_read(LipiVal path) {
    if (path.type != LV_STR) return lv_null();
    FILE* f = fopen(path.str, "r");
    if (!f) { fprintf(stderr,"❌ file_read: cannot open %s\n", path.str); return lv_null(); }
    fseek(f, 0, SEEK_END); long sz = ftell(f); rewind(f);
    char* buf = (char*)malloc(sz+1); fread(buf, 1, sz, f); buf[sz] = '\0'; fclose(f);
    LipiVal r = lv_str(buf); free(buf); return r;
}
static inline LipiVal lv_file_write(LipiVal path, LipiVal content) {
    if (path.type != LV_STR) return lv_null();
    const char* cs = (content.type == LV_STR) ? content.str : lv_to_str(content);
    FILE* f = fopen(path.str, "w");
    if (f) { fputs(cs, f); fclose(f); return lv_bool(1); }
    return lv_bool(0);
}
static inline LipiVal lv_file_append(LipiVal path, LipiVal content) {
    if (path.type != LV_STR) return lv_null();
    const char* cs = (content.type == LV_STR) ? content.str : lv_to_str(content);
    FILE* f = fopen(path.str, "a");
    if (f) { fputs(cs, f); fclose(f); return lv_bool(1); }
    return lv_bool(0);
}
static inline LipiVal lv_file_exists(LipiVal path) {
    if (path.type != LV_STR) return lv_bool(0);
    FILE* f = fopen(path.str, "r");
    if (f) { fclose(f); return lv_bool(1); }
    return lv_bool(0);
}

/* ── System ──────────────────────────────────────────────────── */
static inline LipiVal lv_argv(void) {
    /* WHY: argv() in native binaries reads _LIPI_ARGV env var (pipe-separated)
       matching the Python runtime behavior for portability. */
    LipiVal result = lv_list_make(0);
    const char* env = getenv("_LIPI_ARGV");
    if (env) {
        char* buf = strdup(env);
        char* tok = strtok(buf, "|");
        while (tok) { result = lv_push(result, lv_str(tok)); tok = strtok(NULL, "|"); }
        free(buf);
    }
    return result;
}
static inline LipiVal lv_exit(LipiVal code) { exit((int)code.num); return lv_null(); }
static inline LipiVal lv_type_str(LipiVal v) {
    switch(v.type) {
        case LV_NULL: return lv_str("null");
        case LV_NUM:  return lv_str("number");
        case LV_BOOL: return lv_str("bool");
        case LV_STR:  return lv_str("string");
        case LV_LIST: return lv_str("list");
        case LV_STRUCT: return lv_str("struct");
        case LV_FN:   return lv_str("function");
        default:      return lv_str("unknown");
    }
}
static inline LipiVal lv_env(LipiVal key) {
    if (key.type != LV_STR) return lv_null();
    const char* v = getenv(key.str);
    return v ? lv_str(v) : lv_null();
}
static inline LipiVal lv_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return lv_num((double)(ts.tv_sec * 1000LL + ts.tv_nsec / 1000000));
}

/* ── Math extras ─────────────────────────────────────────────── */
static inline LipiVal lv_min(LipiVal a, LipiVal b) { return lv_num(fmin(a.num, b.num)); }
static inline LipiVal lv_max(LipiVal a, LipiVal b) { return lv_num(fmax(a.num, b.num)); }
static inline LipiVal lv_pow(LipiVal a, LipiVal b) { return lv_num(pow(a.num, b.num)); }
static inline LipiVal lv_log(LipiVal v)  { return lv_num(log(v.num)); }
static inline LipiVal lv_log2(LipiVal v) { return lv_num(log2(v.num)); }
static inline LipiVal lv_log10(LipiVal v){ return lv_num(log10(v.num)); }
static inline LipiVal lv_sin(LipiVal v)  { return lv_num(sin(v.num)); }
static inline LipiVal lv_cos(LipiVal v)  { return lv_num(cos(v.num)); }
static inline LipiVal lv_tan(LipiVal v)  { return lv_num(tan(v.num)); }
static inline LipiVal lv_round(LipiVal v){ return lv_num(round(v.num)); }


/* ── Struct ───────────────────────────────────────────────── */
static inline LipiStruct* lv_struct_new(const char* name, const char** fields, int n) {
    LipiStruct* s = (LipiStruct*)calloc(1, sizeof(LipiStruct));
    s->type_name   = name;
    s->field_names = fields;
    s->field_vals  = (LipiVal*)calloc(n, sizeof(LipiVal));
    s->field_count = n;
    /* Initialize all fields to null */
    for (int i = 0; i < n; i++) s->field_vals[i] = lv_null();
    return s;
}

static inline LipiVal lv_field_get(LipiVal obj, const char* field) {
    if (obj.type != LV_STRUCT) { fprintf(stderr,"❌ field_get: not a struct\n"); exit(1); }
    LipiStruct* s = obj.strct;
    for (int i = 0; i < s->field_count; i++) {
        if (strcmp(s->field_names[i], field) == 0) return s->field_vals[i];
    }
    fprintf(stderr, "❌ no field '%s' on struct '%s'\n", field, s->type_name);
    exit(1);
}

static inline void lv_field_set(LipiVal obj, const char* field, LipiVal val) {
    if (obj.type != LV_STRUCT) { fprintf(stderr,"❌ field_set: not a struct\n"); exit(1); }
    LipiStruct* s = obj.strct;
    for (int i = 0; i < s->field_count; i++) {
        if (strcmp(s->field_names[i], field) == 0) { s->field_vals[i] = val; return; }
    }
    fprintf(stderr, "❌ no field '%s' on struct '%s'\n", field, s->type_name);
    exit(1);
}

/* ── Math builtins ────────────────────────────────────────── */
static inline LipiVal lipi_sqrt(LipiVal v) { return lv_num(sqrt(v.num)); }
static inline LipiVal lipi_abs(LipiVal v)  { return lv_num(fabs(v.num)); }
static inline LipiVal lipi_floor(LipiVal v) { return lv_num(floor(v.num)); }
static inline LipiVal lipi_ceil(LipiVal v)  { return lv_num(ceil(v.num)); }

/* ── Return exception via longjmp ─────────────────────────── */
/* WHY: Lipi functions use 'return' which in C is just a C return.
        The codegen handles this by generating proper C returns. */

#endif /* LIPI_RUNTIME_H */
