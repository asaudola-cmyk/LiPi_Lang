#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
global_rename.py — লিপি .lp ফাইলের সমস্ত Bengali identifier ও comment → English রূপান্তরকারী

Usage:
    python3 src/tools/global_rename.py --dir std/        --in-place
    python3 src/tools/global_rename.py --dir src/tools/  --in-place
    python3 src/tools/global_rename.py --dir examples/   --in-place
    python3 src/tools/global_rename.py --dir src/compiler/ --in-place
    python3 src/tools/global_rename.py --dir tests/      --in-place

WHY: Lipi codebase-এ mixed Bengali/English identifiers থাকলে IDE সাপোর্ট,
grep, linting, এবং CI/CD pipeline-এ সমস্যা হয়। এই script সমগ্র codebase-কে
pure-ASCII identifier-এ রূপান্তর করে — lexer-aware parsing দিয়ে যাতে
string literal-এর ভেতরের Bengali text অক্ষত থাকে।
"""

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# =============================================================================
# ১. Comprehensive Bengali → English Identifier Mapping
#    WHY: প্রতিটি entry longest-match-first ক্রমে sort করা হয় — এটি নিশ্চিত করে
#    যে 'মেমরি_বাইট_লেখো' আগে match হবে, পরে 'মেমরি_লেখো'।
# =============================================================================
IDENT_MAP: Dict[str, str] = {
    # Memory operations
    'মেমরি_বাইট_লেখো':                 'mem_write_byte',
    'মেমরি_বাইট_পড়ো':                  'mem_read_byte',
    'মেমরি_শব্দ_লেখো':                  'mem_write_word',
    'মেমরি_শব্দ_পড়ো':                   'mem_read_word',
    'মেমরি_লেখো':                       'mem_write',
    'মেমরি_পড়ো':                        'mem_read',
    'মেমরি_পূরণ':                       'mem_fill',
    'মেমরি_অনুলিপি':                    'mem_copy',
    'মেমরি_বরাদ্দ':                     'malloc',
    'মেমরি_মুক্তি':                     'free',
    'মেমরি_ঠিকানা':                     'mem_addr',
    'হিপ_ঠিকানা':                       'heap_addr',
    # Buffers
    'হেডার_বাফার':                       'header_buffer',
    'রেসপন্স_বাফার':                     'response_buffer',
    'ইমেজ_বাফার':                        'image_buffer',
    'ফ্রেম_বাফার':                       'frame_buffer',
    'প্যাডেড_বাফার':                     'padded_buffer',
    'বাফার_ঠিকানা':                      'buffer_addr',
    'বাফার':                             'buffer',
    # Syscall (longest first)
    'সিসকল_এপোল_ওয়েট':                  'syscall_epoll_wait',
    'সিসকল_আয়োরিং':                     'syscall_io_uring',
    'সিসকল_এফস্ট্যাট':                   'syscall_fstat',
    'সিসকল_এপোল':                        'syscall_epoll',
    'সিসকল_ফিউটেক্স':                    'syscall_futex',
    'সিসকল_আনম্যাপ':                     'syscall_munmap',
    'সিসকল_একসেপ্ট':                     'syscall_accept',
    'সিসকল_কানেক্ট':                     'syscall_connect',
    'সিসকল_লিসেন':                       'syscall_listen',
    'সিসকল_বাইন্ড':                      'syscall_bind',
    'সিসকল_সকেট':                        'syscall_socket',
    'সিসকল_ক্লোন':                       'syscall_clone',
    'সিসকল_এক্সিট':                      'syscall_exit',
    'সিসকল_লিখ':                         'syscall_write',
    'সিসকল_পড়':                          'syscall_read',
    'সিসকল_খোলো':                        'syscall_open',
    'সিসকল_বন্ধ':                        'syscall_close',
    'সিসকল_ম্যাপ':                       'syscall_mmap',
    'সিসকল_সিক':                         'syscall_seek',
    'সিসকল':                             'syscall',
    # Variables & common names
    'ফলাফল':                             'result',
    'মান_ক':                             'val_a',
    'মান_খ':                             'val_b',
    'মান':                               'value',
    'গণনা':                              'count',
    'সূচক':                              'index',
    'আকার':                              'size',
    'সাইজ':                              'size',
    'অফসেট':                             'offset',
    'বেস':                               'base',
    'পোর্ট':                             'port',
    'ম্যাপ_পয়েন্টার':                    'map_ptr',
    'পয়েন্টার':                          'ptr',
    'হ্যাশ':                             'hash',
    'স্লট':                              'slot',
    'পুল':                               'pool',
    'স্ট্যাটাস':                          'status',
    'রঙ':                                'color',
    # Display / UI
    'ক্যানভাস':                           'canvas',
    'প্রস্থ':                             'width',
    'উচ্চতা':                             'height',
    'বি_কার্সার':                         'cursor',
    'কার্সর':                             'cursor',
    'কার্সার':                            'cursor',
    'ক্যাপাসিটি':                         'capacity',
    # Network
    'ক্লায়েন্ট_এফডি':                    'client_fd',
    'সকেট_এফডি':                          'socket_fd',
    'সকঅ্যাড্রেস':                        'sock_addr',
    'এফডি':                              'fd',
    # Function params / general
    'নাম':                               'name',
    'বার্তা':                             'message',
    'হেডার':                             'header',
    'প্রধান':                             'main',
    'দাবি':                              'assert_val',
    'কোড_অফসেট':                          'code_offset',
    'কলাম_লেখো':                          'col_write',
    # Arithmetic
    'যোগফল':                             'sum',
    'যোগ_করো':                            'add',
    'যোগ':                               'add',
    'বিয়োগ':                             'subtract',
    'গুণফল':                             'product',
    'গুণ_করো':                            'multiply',
    'গুণ':                               'multiply',
    'ভাগফল':                             'quotient',
    'ভাগ':                               'divide',
    'বিভাজন':                            'divide',
    'শেষফল':                             'remainder',
    'বর্গমূল':                            'sqrt',
    'পরম_মান':                            'abs_val',
    # Data structures
    'তালিকা':                            'list',
    'অভিধান':                            'dict',
    'স্ট্রিং':                            'string',
    'পূর্ণসংখ্যা':                        'integer',
    'দশমিক':                             'decimal',
    'বুলিয়ান':                           'boolean',
    # Common function names
    'ফিবোনাচ্চি':                         'fibonacci',
    'ফ্যাক্টোরিয়াল':                     'factorial',
    'প্রধান_কার্যনির্বাহী':               'main_exec',
    # Loop / math vars
    'পদ':                                'term',
    'দাম':                               'price',
    'পরিমাণ':                            'qty',
    'মোট_যোগফল':                          'total_sum',
    'মোট':                               'total',
    'শুভেচ্ছা':                           'greeting',
    'সংখ্যা':                            'num',
    'ন1':                                'n1',
    'ন2':                                'n2',
    'সংস্করণ':                           'version',
    # HTTP / web
    'পথনাম':                             'pathname',
    'পথ':                                'path',
    'বডি':                               'body',
    'অনুরোধ':                            'request',
    'সাড়া':                              'response',
    'রুট':                               'route',
    'হ্যান্ডলার':                         'handler',
    'সংযোগ':                             'connection',
    # Error handling
    'ত্রুটি':                             'error',
    'সতর্কতা':                           'warning',
    'সফল':                               'success',
    'ব্যর্থ':                             'fail',
    # Time
    'ইপোক_সেকেন্ড':                       'epoch_sec',
    'ক্লক_ব্যবধান':                       'clock_delta',
    'ইপোক':                              'epoch',
    'সময়':                               'time',
    # Misc
    'তাপমাত্রা':                          'temperature',
    'চাপ':                               'pressure',
    'হার':                               'rate',
    'আউটপুট':                            'output',
    'ইনপুট':                             'input',
    'প্রকার':                             'type_val',
    'পরীক্ষা':                           'test',
    'ডেটা':                              'data',
    'ফাইল':                              'file',
    'ডিরেক্টরি':                          'dir',
    'বিভাগ':                             'section',
    'নোড':                               'node',
    'প্রান্ত':                            'edge',
    'তরঙ্গ':                             'wave',
    'মাত্রা':                             'dim',
    'শ্রেণী':                            'class_val',
    'উদাহরণ':                            'example',
    'বস্তু':                             'obj',
    'আরও':                               'more',
    'কম':                                'less',
    'বেশি':                              'more',
    # Graphics / pixel
    'পিক্সেল_রং':                         'pixel_color',
    'পিক্সেল':                            'pixel',
    'পর্দা':                             'screen',
    'উইন্ডো':                            'window',
    'ইভেন্ট':                            'event',
    # Crypto
    'বার্তা_হ্যাশ':                       'msg_hash',
    'চাবি':                              'key',
    'সংকেত':                             'cipher',
    'গুপ্ত':                             'secret',
    # Database
    'সারি':                              'row',
    'কলাম':                              'column',
    'টেবিল':                             'table',
    'প্রশ্ন':                             'query',
    'ডাটাবেস':                           'database',
    'ডাটাবেজ':                           'database',
    # AI / Neural network
    'নিউরন_আউটপুট':                      'neuron_output',
    'নিউরন':                             'neuron',
    'স্তর':                              'layer',
    'ওজন':                               'weight',
    'পক্ষপাত':                           'bias',
    'শিক্ষণ_হার':                         'learning_rate',
    # Misc technical
    'ব্রেকপয়েন্ট_সক্রিয়':                'breakpoint_active',
    'আনম্যাপ_কোড':                        'unmap_code',
    'পাওয়ার_মান':                         'power_val',
    'প্রথম_বাইট':                         'first_byte',
    'বাইট_1':                            'byte1',
    # Single-letter / short params
    'ক':                                 'a',
    'খ':                                 'b',
    # Hashmap specific
    'হ্যাশম্যাপ_তৈরি':                    'hashmap_create',
    'হ্যাশম্যাপ_ইনসার্ট':                 'hashmap_insert',
    'হ্যাশম্যাপ_লুকআপ':                   'hashmap_lookup',
    'হ্যাশম্যাপ_মুছে_ফেলো':               'hashmap_delete',
    'ফাস্ট_হ্যাশ':                        'fast_hash',
    # Net specific
    'সকেট_তৈরি':                          'socket_create',
    'সকেট_অপশন_সেট':                      'socket_opt_set',
    'সকেট_ননব্লকিং_সেট':                  'socket_set_nonblocking',
    'সকেট_ঠিকানা_প্রস্তুত':               'socket_addr_prepare',
    'পোর্ট_বাইন্ড':                       'port_bind',
    'সকেট_লিসেন':                         'socket_listen',
    'সকেট_গ্রহণ':                         'socket_accept',
    'সকেট_বন্ধ':                          'socket_close',
    # Columnstore
    'কলাম_তৈরি':                          'column_create',
    'কলাম_পড়ো':                           'column_read',
    'কলাম_শর্তযুক্ত_যোগফল':              'column_cond_sum',
    'কলাম_মুছে_ফেলো':                     'column_delete',
    # DB
    'ডাটাবেজ_খোলো':                       'database_open',
    'ডাটাবেজ_রাখো':                       'database_put',
    'ডাটাবেজ_পড়ো':                        'database_get',
    'ডাটাবেজ_সিঙ্ক':                      'database_sync',
    'ডাটাবেজ_বন্ধ':                       'database_close',
    # AI functions
    'এআই_কোসাইন_সিমিলারিটি':             'ai_cosine_similarity',
    'এআই_সফটম্যাক্স':                    'ai_softmax',
    'এআই_অ্যাটেনশন':                     'ai_attention',
    # GGUF
    'জিজিইউএফ_হেডার_যাচাই':              'gguf_header_verify',
    'জিজিইউএফ_কিউ4_আনপ্যাক':            'gguf_q4_unpack',
    'জিজিইউএফ_ম্যাট্রিক্স_ভেক্টর_গুণন':  'gguf_matmul',
    'জিজিইউএফ_টোকেন_আর্গম্যাক্স':        'gguf_token_argmax',
    # GRPC
    'GRPC_সার্ভার_তৈরি':                  'grpc_server_create',
    'GRPC_পদ্ধতি_যোগ':                   'grpc_method_add',
    'GRPC_সার্ভার_চালু':                  'grpc_server_start',
    'GRPC_ক্লায়েন্ট_সংযোগ':             'grpc_client_connect',
    'GRPC_কল':                           'grpc_call',
    'GRPC_ক্লায়েন্ট_বন্ধ':               'grpc_client_close',
    # CLI
    'CLI_তৈরি':                          'cli_create',
    'CLI_flag_যোগ':                      'cli_flag_add',
    'CLI_help_দেখাও':                    'cli_help_show',
    'CLI_পার্স':                         'cli_parse',
    'CLI_flag_পড়ো':                      'cli_flag_read',
    'CLI_string_পড়ো':                    'cli_string_read',
    'CLI_number_পড়ো':                    'cli_number_read',
    'CLI_arg_পড়ো':                       'cli_arg_read',
    'CLI_মুক্তি':                        'cli_free',
    # Crypto2
    'Ed25519_keypair_মুক্তি':            'ed25519_keypair_free',
    'CRYPTO_পাসওয়ার্ড_হ্যাশ':           'crypto_password_hash',
    'CRYPTO_পাসওয়ার্ড_যাচাই':           'crypto_password_verify',
    # Crypto (crypto.lp)
    'সিলিকন_র্যান্ডম_সংখ্যা':           'silicon_random_int',
    'নিবল_থেকে_হেক্স':                   'nibble_to_hex',
    'sha256_কনস্ট্যান্ট_ইনিট':           'sha256_const_init',
    # Extra fields from files
    'ঠিকানা':                            'addr',
    'গন্তব্য':                           'dest',
    'উৎস':                              'src',
    'বাইট':                              'byte',
    'দূরত্ব':                            'distance',
    'কী':                                'key',
    'ভ্যালু':                            'val',
    'সর্বোচ্চ_উপাদান':                   'max_elements',
    'বর্তমান_কি':                         'cur_key',
    'বর্তমান_ভ্যালু':                    'cur_val',
    'বর্তমান_দূরত্ব':                    'cur_dist',
    'সংরক্ষিত_কি':                        'stored_key',
    'সংরক্ষিত_ভ্যালু':                   'stored_val',
    'সংরক্ষিত_দূরত্ব':                   'stored_dist',
    'লুপ_কাউন্ট':                         'loop_count',
    'কি_মান':                            'key_val',
    'ফ্ল্যাগ':                           'flag',
    'নতুন_ফ্ল্যাগ':                      'new_flag',
    'খোঁজার_কী':                         'search_key',
    'হাই_বাইট':                          'hi_byte',
    'লো_বাইট':                           'lo_byte',
    'ব্যাকলগ':                           'backlog',
    'রো_সংখ্যা':                         'row_count',
    'রো_ইনডেক্স':                        'row_index',
    'শর্ত_কলাম':                         'cond_col',
    'যোগফল_কলাম':                         'sum_col',
    'শর্ত_মান':                          'cond_val',
    'কলাম_পয়েন্টার':                     'col_ptr',
    # AI vectors
    'ভেক্টর1':                           'vec1',
    'ভেক্টর2':                           'vec2',
    'ডাইমেনশন':                          'dim',
    'অ্যাটেনশন_স্কোর_ক্যানভাস':          'attn_score_canvas',
    'টোকেন_সংখ্যা':                      'token_count',
    'কিউ_ম্যাট্রিক্স':                    'q_matrix',
    'কে_ম্যাট্রিক্স':                     'k_matrix',
    'ভি_ম্যাট্রিক্স':                     'v_matrix',
    # GGUF internals
    'প্যাকড_ঠিকানা':                     'packed_addr',
    'আনপ্যাকড_ঠিকানা':                   'unpacked_addr',
    'বাইট_সংখ্যা':                       'byte_count',
    'স্কেল':                             'scale',
    'ওজন_ম্যাট্রিক্স':                   'weight_matrix',
    'ইনপুট_ভেক্টর':                      'input_vec',
    'আউটপুট_ভেক্টর':                     'output_vec',
    'লগিট_ঠিকানা':                       'logit_addr',
    'ভোকাব_আকার':                         'vocab_size',
    # GRPC internals
    'পদ্ধতি_নাম':                         'method_name',
    'request_বাফার':                     'request_buffer',
    # CLI internals
    'বিবরণ':                             'description',
    'ধরন':                               'type_flag',
    'flag_নাম':                          'flag_name',
    # Misc remaining
    'কোড':                               'code',
    'নিবল':                              'nibble',
    'কে_মেমরি':                          'k_memory',
    'ফলাফল':                             'result',
    'ফল':                                'result',
}

# =============================================================================
# ২. Bengali Comment → English Translation (keyword-based heuristic)
#    WHY: Full NLP translation is overkill এবং offline environment-এ কাজ করে না।
# =============================================================================
COMMENT_WORD_MAP: Dict[str, str] = {
    'মেমরি': 'memory',
    'বরাদ্দ': 'allocation',
    'অবমুক্তি': 'deallocation',
    'মুক্তি': 'release',
    'কার্নেল': 'kernel',
    'সরাসরি': 'direct',
    'নির্দেশ': 'instruction',
    'পেজ': 'page',
    'প্রাইভেট': 'private',
    'ভার্চুয়াল': 'virtual',
    'অ্যাড্রেস': 'address',
    'স্পেস': 'space',
    'পড়া': 'read',
    'লেখা': 'write',
    'সংরক্ষণ': 'store',
    'লোড': 'load',
    'তৈরি': 'create',
    'বন্ধ': 'close',
    'খোলো': 'open',
    'গ্রহণ': 'accept',
    'লিসেন': 'listen',
    'বাইন্ড': 'bind',
    'ফিরিয়ে': 'return',
    'দেওয়া': 'give',
    'পাঠ': 'reading',
    'সফলভাবে': 'successfully',
    'বরাদ্দকৃত': 'allocated',
    'ব্লক': 'block',
    'ট্রান্সফার': 'transfer',
    'প্রতিটি': 'each',
    'বাইট': 'byte',
    'শব্দ': 'word',
    'ইনডেক্স': 'index',
    'অ্যারে': 'array',
    'স্ট্রাকচার': 'structure',
    'দ্রুত': 'fast',
    'সিসকল': 'syscall',
    'ত্রুটি': 'error',
    'এড়ানো': 'avoiding',
    'নেটওয়ার্ক': 'network',
    'সকেট': 'socket',
    'সংযোগ': 'connection',
    'রিসোর্স': 'resource',
    'কার্নেলকে': 'to-kernel',
    'ফাইল': 'file',
    'ডেসক্রিপ্টর': 'descriptor',
    'টোকেন': 'token',
    'ম্যাপ': 'map',
    'হ্যাশ': 'hash',
    'লুকআপ': 'lookup',
    'কলিশন': 'collision',
    'ইনসার্ট': 'insert',
    'প্রাইম': 'prime',
    'গণনা': 'count',
    'দূরত্ব': 'distance',
    'সংখ্যা': 'number',
    'ক্যাশ': 'cache',
    'ডেটা': 'data',
    'হিপ': 'heap',
    'থেকে': 'from',
    'অন্য': 'other',
    'কোনো': 'any',
    'সঠিকভাবে': 'correctly',
    'রিটার্ন': 'return',
    'পড়ো': 'read',
    'লেখো': 'write',
    'মুছে': 'delete',
    'ফেলো': 'discard',
    'বড়': 'large',
    'ছোট': 'small',
    'পূর্ণ': 'full',
    'শূন্য': 'zero',
    'ইনকামিং': 'incoming',
    'পেন্ডিং': 'pending',
    'ক্লায়েন্ট': 'client',
    'সার্ভার': 'server',
    'রিস্টার্ট': 'restart',
    'সময়': 'time',
    'অপারেটর': 'operator',
    'না': 'not',
    'আমরা': 'we',
    'সিম্পল': 'simple',
    'লিনিয়ার': 'linear',
    'জেনারেটর': 'generator',
    'ব্যবহার': 'use',
    'বিট': 'bit',
    'শিফট': 'shift',
    'পোর্ট': 'port',
    'আইপি': 'IP',
    'বিগ': 'big',
    'এনডিয়ান': 'endian',
    'প্রতি': 'each',
    'স্লটে': 'per-slot',
    'লাগবে': 'needed',
}

# =============================================================================
# ৩. Helper: Bengali character detection
# =============================================================================
def has_bengali(text: str) -> bool:
    """Returns True if text contains at least one Bengali Unicode character."""
    return any('\u0980' <= ch <= '\u09FF' for ch in text)


# =============================================================================
# ৪. Pre-sorted identifier list (longest-match first)
#    WHY: 'মেমরি_বাইট_লেখো' must be tried before 'মেমরি_লেখো' to avoid
#    partial replacement leaving broken identifiers.
# =============================================================================
_SORTED_IDENTS: List[Tuple[str, str]] = sorted(
    IDENT_MAP.items(),
    key=lambda kv: len(kv[0]),
    reverse=True,
)


def replace_identifiers_in_token(token: str) -> Tuple[str, int]:
    """
    Replace Bengali identifiers in a non-string code segment.
    Returns (new_token, replacement_count).
    WHY: Uses word-boundary-aware regex to avoid partial identifier matches.
    """
    result = token
    count = 0
    for bn, en in _SORTED_IDENTS:
        if bn not in result:
            continue
        # Negative lookbehind/ahead for identifier chars (Bengali + ASCII alnum + _)
        pattern = re.compile(
            r'(?<![^\W\d_\u0980-\u09FF])' + re.escape(bn) + r'(?![^\W\d_\u0980-\u09FF])',
            re.UNICODE
        )
        new_result, n = pattern.subn(en, result)
        result = new_result
        count += n
    return result, count


def translate_comment_text(text: str) -> Tuple[str, int]:
    """
    Heuristic translation of Bengali comment text.
    - First pass: identifier map (compound identifier names in comments)
    - Second pass: word-level comment keyword map
    WHY: Preserves all information while maximising English readability.
    """
    count = 0
    # First pass: identifier map
    for bn, en in _SORTED_IDENTS:
        if bn in text:
            occurrences = text.count(bn)
            text = text.replace(bn, en)
            count += occurrences
    # Second pass: word-level keyword map
    words = text.split(' ')
    new_words = []
    for w in words:
        stripped = w.rstrip('\u0964,:;!?')  # ।  and punctuation
        suffix = w[len(stripped):]
        if stripped in COMMENT_WORD_MAP:
            new_words.append(COMMENT_WORD_MAP[stripped] + suffix)
            count += 1
        else:
            new_words.append(w)
    return ' '.join(new_words), count


# =============================================================================
# ৫. Line-level tokenizer
#    WHY: string literal-এর ভেতরে replace করলে user-facing Bengali output
#    (say "...") নষ্ট হয়। tokenizer সেটা প্রতিরোধ করে।
# =============================================================================
def tokenize_line(line: str) -> List[Tuple[str, bool]]:
    """
    Split a line into segments: (text, is_string_literal).
    Handles both "..." and '...' delimiters, with backslash-escape awareness.
    """
    segments: List[Tuple[str, bool]] = []
    i = 0
    current: List[str] = []
    in_string = False
    string_char = ''

    while i < len(line):
        ch = line[i]
        if not in_string:
            if ch in ('"', "'"):
                if current:
                    segments.append((''.join(current), False))
                    current = []
                in_string = True
                string_char = ch
                current.append(ch)
            else:
                current.append(ch)
        else:
            current.append(ch)
            if ch == string_char and (i == 0 or line[i - 1] != '\\'):
                segments.append((''.join(current), True))
                current = []
                in_string = False
                string_char = ''
        i += 1

    if current:
        segments.append((''.join(current), in_string))

    return segments


def _find_comment_start(line: str) -> int:
    """
    Find index of '//' that is outside any string literal.
    Returns -1 if no inline comment found.
    """
    in_string = False
    string_char = ''
    i = 0
    while i < len(line):
        ch = line[i]
        if not in_string:
            if ch in ('"', "'"):
                in_string = True
                string_char = ch
            elif ch == '/' and i + 1 < len(line) and line[i + 1] == '/':
                return i
        else:
            if ch == string_char and (i == 0 or line[i - 1] != '\\'):
                in_string = False
                string_char = ''
        i += 1
    return -1


def _replace_in_code(code: str) -> Tuple[str, int]:
    """Replace Bengali identifiers in code (string-literal-safe)."""
    segments = tokenize_line(code)
    result_parts = []
    total = 0
    for text, is_str in segments:
        if is_str:
            result_parts.append(text)
        else:
            new_text, c = replace_identifiers_in_token(text)
            result_parts.append(new_text)
            total += c
    return ''.join(result_parts), total


# =============================================================================
# ৬. Single line transformer
# =============================================================================
def transform_line(line: str) -> Tuple[str, int]:
    """
    Transform a single .lp source line:
    - Comment lines (// prefix): translate Bengali text heuristically
    - Code lines: replace Bengali identifiers outside string literals
    - Inline comments: both code and comment parts handled separately
    Returns (new_line, replacement_count).
    """
    stripped = line.lstrip()
    count = 0

    # Case 1: Pure comment line
    if stripped.startswith('//'):
        indent = line[:len(line) - len(stripped)]
        if has_bengali(stripped):
            new_rest, c = translate_comment_text(stripped)
            count += c
            nl = '\n' if line.endswith('\n') else ''
            return indent + new_rest.rstrip('\n') + nl, count
        return line, 0

    # Case 2: Inline comment in code line
    comment_idx = _find_comment_start(line)
    if comment_idx != -1:
        code_part = line[:comment_idx]
        comment_part = line[comment_idx:]
        new_code, c1 = _replace_in_code(code_part)
        if has_bengali(comment_part):
            new_comment, c2 = translate_comment_text(comment_part)
        else:
            new_comment, c2 = comment_part, 0
        return new_code + new_comment, c1 + c2

    # Case 3: Pure code line
    return _replace_in_code(line)


# =============================================================================
# ৭. File processor
# =============================================================================
def process_file(path: Path, in_place: bool = True, verbose: bool = False) -> Dict:
    """
    Process a single .lp file. Returns stats dict.
    Creates a .lp.bak backup on first run (idempotent).
    """
    try:
        original = path.read_text(encoding='utf-8')
    except (UnicodeDecodeError, IOError) as exc:
        return {'file': str(path), 'error': str(exc), 'replacements': 0, 'modified': False}

    lines = original.splitlines(keepends=True)
    new_lines = []
    total_replacements = 0
    changed_lines = 0

    for line_no, line in enumerate(lines, 1):
        new_line, cnt = transform_line(line)
        new_lines.append(new_line)
        if cnt > 0:
            total_replacements += cnt
            changed_lines += 1
            if verbose:
                print(f"  [{line_no:4d}] {cnt}x  Before: {line.rstrip()}")
                print(f"         After : {new_line.rstrip()}")

    new_content = ''.join(new_lines)
    modified = new_content != original

    if in_place and modified:
        bak_path = path.with_suffix('.lp.bak')
        if not bak_path.exists():
            bak_path.write_text(original, encoding='utf-8')
        path.write_text(new_content, encoding='utf-8')

    return {
        'file': str(path),
        'lines': len(lines),
        'replacements': total_replacements,
        'changed_lines': changed_lines,
        'modified': modified,
    }


# =============================================================================
# ৮. Directory scanner
# =============================================================================
def scan_directory(directory: Path, in_place: bool, verbose: bool) -> List[Dict]:
    """Recursively process all .lp files in directory."""
    results = []
    lp_files = sorted(directory.rglob('*.lp'))
    if not lp_files:
        print(f"  ⚠️  কোনো .lp ফাইল পাওয়া যায়নি: {directory}")
        return results
    for fp in lp_files:
        if '.bak' in fp.suffixes:
            continue
        if verbose:
            print(f"\n📄 প্রসেস করছি: {fp}")
        result = process_file(fp, in_place=in_place, verbose=verbose)
        results.append(result)
    return results


# =============================================================================
# ৯. Report printer (Bengali)
# =============================================================================
def print_report(all_results: List[Dict], dir_label: str) -> None:
    """Print a Bengali summary report."""
    print(f"\n{'═' * 68}")
    print(f"  📊 রিপোর্ট — {dir_label}")
    print(f"{'═' * 68}")

    total_files = len(all_results)
    modified_files = sum(1 for r in all_results if r.get('modified'))
    total_replacements = sum(r.get('replacements', 0) for r in all_results)
    errors = [r for r in all_results if 'error' in r]

    for r in all_results:
        name = Path(r['file']).name
        if 'error' in r:
            print(f"  ❌ {name:42s} ত্রুটি: {r['error']}")
        elif r.get('modified'):
            print(f"  ✅ {name:42s} {r['replacements']:4d} replacement(s)  ({r['changed_lines']} লাইন)")
        else:
            print(f"  ⬜ {name:42s} পরিবর্তন নেই")

    print(f"\n{'─' * 68}")
    print(f"  মোট ফাইল প্রসেস   : {total_files}")
    print(f"  পরিবর্তিত ফাইল   : {modified_files}")
    print(f"  মোট replacement   : {total_replacements}")
    if errors:
        print(f"  ত্রুটি            : {len(errors)}")
    print(f"{'═' * 68}\n")


# =============================================================================
# ১০. CLI entry point
# =============================================================================
def main() -> None:
    parser = argparse.ArgumentParser(
        description='লিপি .lp ফাইলের Bengali → English রূপান্তরকারী',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
উদাহরণ:
  python3 src/tools/global_rename.py --dir std/          --in-place
  python3 src/tools/global_rename.py --dir examples/     --in-place --verbose
  python3 src/tools/global_rename.py --dir src/compiler/ --in-place
        """,
    )
    parser.add_argument('--dir', required=False, default=None,
                        help='যে directory তে .lp ফাইল খোঁজা হবে (recursive)')
    parser.add_argument('--file', default=None,
                        help='একটি নির্দিষ্ট .lp ফাইল প্রসেস করো')
    parser.add_argument('--in-place', action='store_true',
                        help='ফাইলগুলো সরাসরি overwrite করো (না হলে dry-run)')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='প্রতিটি পরিবর্তন দেখাও')

    args = parser.parse_args()
    base = Path.cwd()

    if args.file:
        fp = Path(args.file)
        if not fp.is_absolute():
            fp = base / fp
        if not fp.exists():
            print(f"❌ ফাইল খুঁজে পাওয়া যায়নি: {fp}", file=sys.stderr)
            sys.exit(1)
        result = process_file(fp, in_place=args.in_place, verbose=args.verbose)
        print_report([result], str(fp))
        return

    if not args.dir:
        parser.error("--dir অথবা --file একটি দিতে হবে")

    target_dir = Path(args.dir)
    if not target_dir.is_absolute():
        target_dir = base / target_dir
    if not target_dir.exists():
        print(f"❌ Directory খুঁজে পাওয়া যায়নি: {target_dir}", file=sys.stderr)
        sys.exit(1)

    mode = "in-place ✏️" if args.in_place else "dry-run 👀"
    print(f"\n🚀 Bengali → English রূপান্তর শুরু হচ্ছে")
    print(f"   Directory : {target_dir}")
    print(f"   Mode      : {mode}")

    results = scan_directory(target_dir, in_place=args.in_place, verbose=args.verbose)
    print_report(results, str(target_dir))

    if any('error' in r for r in results):
        sys.exit(1)


if __name__ == '__main__':
    main()
# ── এই ফাইলে append করা হয়েছে (patch pass 2) ──
