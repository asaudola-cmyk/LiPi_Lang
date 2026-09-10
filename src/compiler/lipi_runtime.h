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
