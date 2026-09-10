#!/usr/bin/env python3
"""
elf_emitter.py — Lipi Sovereign Direct x86_64 ELF Machine Code Emitter
=====================================================================
👑 Pillar 1: Direct Machine Code — Zero GCC / Zero Clang / Zero as / Zero ld
🏛️ Pillar 2: Libc-less Baremetal — Zero libc / Zero glibc / Zero dynamic linker

This compiler backend directly emits Linux ELF64 binary executables from
Lipi source AST. The generated binaries are 100% statically self-contained,
have NO section headers required, NO dynamic loader, and communicate directly
with the Linux kernel via AMD64 syscall ABI.

Binary Structure:
  [0x0000..0x003F]  ELF64 Header (64 bytes)
  [0x0040..0x0077]  ELF64 Program Header (PT_LOAD, 56 bytes)
  [0x0078..CODE]    Entry point (_start) + Builtin Syscall Stubs + User Code
  [CODE..DATA]      Constant Pool (Pascal/C hybrid strings: [qword len][bytes][0])
  [DATA..END]       Global variable storage (.bss / data)

Base virtual address: 0x400000
Entry point address:  0x400078
"""

from __future__ import annotations
import os
import sys
import re
import struct
from typing import Dict, List, Tuple, Optional, Any, Set

from src.runtime.ast_nodes import (
    Program, Block, Number, String, Bool, Null, Identifier,
    BinOp, UnaryOp, Assign, FieldAssign, FieldAccess,
    FnDef, FnCall, Return, If, While, Repeat, ForRange, ForEach,
    Include, StructDef, Break, Continue, Node
)

# ── X86_64 Register Encodings ───────────────────────────────────────────────
RAX = 0
RCX = 1
RDX = 2
RBX = 3
RSP = 4
RBP = 5
RSI = 6
RDI = 7
R8  = 8
R9  = 9
R10 = 10
R11 = 11
R12 = 12
R13 = 13
R14 = 14
R15 = 15

# Type tags for compiler type inference
TYPE_INT     = 1
TYPE_STR     = 2
TYPE_BOOL    = 3
TYPE_STRUCT  = 4
TYPE_DYNAMIC = 5


class X86Emitter:
    """
    Emits raw x86_64 machine code bytes with automatic label resolution
    and relative 32-bit displacement backpatching.
    """

    def __init__(self, base_vaddr: int = 0x400078):
        self.base_vaddr = base_vaddr
        self.code = bytearray()
        self.labels: Dict[str, int] = {}
        # List of (patch_offset, target_label_name, rel32_next_rip_offset)
        self.relocs: List[Tuple[int, str, int]] = []
        self._label_counter = 0

    def new_label(self, prefix: str = "L") -> str:
        self._label_counter += 1
        return f"{prefix}_{self._label_counter}"

    def define_label(self, name: str):
        # WHY: Store current byte offset for this label
        self.labels[name] = len(self.code)

    def current_offset(self) -> int:
        return len(self.code)

    def emit(self, bs: bytes):
        self.code.extend(bs)

    def emit_u8(self, val: int):
        self.code.append(val & 0xFF)

    def emit_u32(self, val: int):
        self.code.extend(struct.pack("<I", val & 0xFFFFFFFF))

    def emit_u64(self, val: int):
        self.code.extend(struct.pack("<Q", val & 0xFFFFFFFFFFFFFFFF))

    def emit_i32(self, val: int):
        self.code.extend(struct.pack("<i", val))

    def emit_i64(self, val: int):
        self.code.extend(struct.pack("<q", val))

    # ── Instruction Encoders ────────────────────────────────────────────────

    def push_rbp(self):
        self.emit(b"\x55")

    def mov_rbp_rsp(self):
        self.emit(b"\x48\x89\xe5")

    def pop_rbp(self):
        self.emit(b"\x5d")

    def leave(self):
        self.emit(b"\xc9")

    def ret(self):
        self.emit(b"\xc3")

    def syscall(self):
        self.emit(b"\x0f\x05")

    def sub_rsp(self, bytes_count: int):
        if bytes_count == 0:
            return
        if bytes_count <= 127:
            self.emit(b"\x48\x83\xec" + bytes([bytes_count]))
        else:
            self.emit(b"\x48\x81\xec" + struct.pack("<I", bytes_count))

    def add_rsp(self, bytes_count: int):
        if bytes_count == 0:
            return
        if bytes_count <= 127:
            self.emit(b"\x48\x83\xc4" + bytes([bytes_count]))
        else:
            self.emit(b"\x48\x81\xc4" + struct.pack("<I", bytes_count))

    def push_reg(self, reg: int):
        if reg >= 8:
            self.emit(b"\x41" + bytes([0x50 + (reg & 7)]))
        else:
            self.emit(bytes([0x50 + reg]))

    def pop_reg(self, reg: int):
        if reg >= 8:
            self.emit(b"\x41" + bytes([0x58 + (reg & 7)]))
        else:
            self.emit(bytes([0x58 + reg]))

    def mov_reg_imm64(self, reg: int, val: int):
        # REX.W (0x48) + B if reg >= 8
        rex = 0x48 | (1 if reg >= 8 else 0)
        opcode = 0xB8 + (reg & 7)
        self.emit(bytes([rex, opcode]) + struct.pack("<q", val))

    def mov_reg_reg(self, dst: int, src: int):
        # 64-bit mov dst, src: REX.W [0x48 | R(src) | B(dst)] 0x89 ModR/M
        rex = 0x48
        if src >= 8:
            rex |= 0x04  # REX.R
        if dst >= 8:
            rex |= 0x01  # REX.B
        modrm = 0xC0 | ((src & 7) << 3) | (dst & 7)
        self.emit(bytes([rex, 0x89, modrm]))

    def mov_stack_rax(self, rbp_offset: int):
        # mov [rbp - offset], rax
        disp = -rbp_offset
        if -128 <= disp <= 127:
            self.emit(b"\x48\x89\x45" + struct.pack("<b", disp))
        else:
            self.emit(b"\x48\x89\x85" + struct.pack("<i", disp))

    def mov_rax_stack(self, rbp_offset: int):
        # mov rax, [rbp - offset]
        disp = -rbp_offset
        if -128 <= disp <= 127:
            self.emit(b"\x48\x8b\x45" + struct.pack("<b", disp))
        else:
            self.emit(b"\x48\x8b\x85" + struct.pack("<i", disp))

    def mov_stack_reg(self, rbp_offset: int, reg: int):
        # mov [rbp - offset], reg
        disp = -rbp_offset
        rex = 0x48 | (0x04 if reg >= 8 else 0)
        if -128 <= disp <= 127:
            modrm = 0x45 | ((reg & 7) << 3)
            self.emit(bytes([rex, 0x89, modrm]) + struct.pack("<b", disp))
        else:
            modrm = 0x85 | ((reg & 7) << 3)
            self.emit(bytes([rex, 0x89, modrm]) + struct.pack("<i", disp))

    def mov_reg_stack(self, reg: int, rbp_offset: int):
        # mov reg, [rbp - offset]
        disp = -rbp_offset
        rex = 0x48 | (0x04 if reg >= 8 else 0)
        if -128 <= disp <= 127:
            modrm = 0x45 | ((reg & 7) << 3)
            self.emit(bytes([rex, 0x8b, modrm]) + struct.pack("<b", disp))
        else:
            modrm = 0x85 | ((reg & 7) << 3)
            self.emit(bytes([rex, 0x8b, modrm]) + struct.pack("<i", disp))

    def lea_reg_rip(self, reg: int, label_name: str):
        # lea reg, [rip + disp32]
        rex = 0x48 | (0x04 if reg >= 8 else 0)
        modrm = 0x05 | ((reg & 7) << 3)
        pos = len(self.code)
        self.emit(bytes([rex, 0x8D, modrm, 0x00, 0x00, 0x00, 0x00]))
        # disp32 is at pos + 3. next_rip is pos + 7.
        self.relocs.append((pos + 3, label_name, 7))

    # ── Arithmetic & Logical ───────────────────────────────────────────────

    def add_rax_rbx(self):
        self.emit(b"\x48\x01\xd8")

    def sub_rax_rbx(self):
        # rax = rax - rbx
        self.emit(b"\x48\x29\xd8")

    def imul_rax_rbx(self):
        # rax = rax * rbx
        self.emit(b"\x48\x0f\xaf\xc3")

    def idiv_rbx(self):
        # rax = rax / rbx, rdx = rem
        self.emit(b"\x48\x99\x48\xf7\xfb")

    def imod_rbx(self):
        # remainder in rdx -> move to rax
        self.emit(b"\x48\x99\x48\xf7\xfb\x48\x89\xd0")

    def neg_rax(self):
        self.emit(b"\x48\xf7\xd8")

    def not_rax(self):
        # Logical NOT: test rax, rax; sete al; movzx rax, al
        self.emit(b"\x48\x85\xc0\x0f\x94\xc0\x48\x0f\xb6\xc0")

    def bit_not_rax(self):
        self.emit(b"\x48\xf7\xd0")

    def and_rax_rbx(self):
        # Normalized boolean AND
        self.emit(b"\x48\x85\xc0\x0f\x95\xc0\x48\x0f\xb6\xc0")  # setne al; movzx rax, al
        self.emit(b"\x48\x85\xdb\x0f\x95\xc3\x48\x0f\xb6\xdb")  # setne bl; movzx rbx, bl
        self.emit(b"\x48\x21\xd8")                              # and rax, rbx

    def or_rax_rbx(self):
        # Normalized boolean OR
        self.emit(b"\x48\x85\xc0\x0f\x95\xc0\x48\x0f\xb6\xc0")  # setne al; movzx rax, al
        self.emit(b"\x48\x85\xdb\x0f\x95\xc3\x48\x0f\xb6\xdb")  # setne bl; movzx rbx, bl
        self.emit(b"\x48\x09\xd8")                              # or rax, rbx

    def xor_rax_rbx(self):
        self.emit(b"\x48\x31\xd8")

    def cmp_rax_rbx(self):
        # cmp rax, rbx
        self.emit(b"\x48\x39\xd8")

    def set_cmp(self, op: str):
        # Compare rax with rbx (left=rax, right=rbx)
        # Note: in `a < b`, we want rax=a, rbx=b, cmp rax, rbx, setl
        cmp_map = {
            "==": b"\x0f\x94\xc0",  # sete
            "!=": b"\x0f\x95\xc0",  # setne
            "<":  b"\x0f\x9c\xc0",  # setl
            "<=": b"\x0f\x9e\xc0",  # setle
            ">":  b"\x0f\x9f\xc0",  # setg
            ">=": b"\x0f\x9d\xc0",  # setge
        }
        self.cmp_rax_rbx()
        self.emit(cmp_map[op])
        self.emit(b"\x48\x0f\xb6\xc0")  # movzx rax, al

    # ── Jumps and Calls ─────────────────────────────────────────────────────

    def jmp(self, label_name: str):
        pos = len(self.code)
        self.emit(b"\xe9\x00\x00\x00\x00")
        self.relocs.append((pos + 1, label_name, 5))

    def jz(self, label_name: str):
        # Jump if zero / false
        pos = len(self.code)
        self.emit(b"\x0f\x84\x00\x00\x00\x00")
        self.relocs.append((pos + 2, label_name, 6))

    def jnz(self, label_name: str):
        # Jump if not zero / true
        pos = len(self.code)
        self.emit(b"\x0f\x85\x00\x00\x00\x00")
        self.relocs.append((pos + 2, label_name, 6))

    def call(self, label_name: str):
        pos = len(self.code)
        self.emit(b"\xe8\x00\x00\x00\x00")
        self.relocs.append((pos + 1, label_name, 5))

    def backpatch(self):
        """
        Backpatch all relative displacements once all labels are defined.
        WHY: Jump and Call displacements in x86_64 are relative to the
        address of the NEXT instruction: target_offset - next_rip_offset.
        """
        for patch_pos, target_name, inst_len in self.relocs:
            if target_name not in self.labels:
                raise ValueError(f"Undefined label in machine code: {target_name}")
            target_pos = self.labels[target_name]
            inst_start = patch_pos - (inst_len - 4)
            next_rip = inst_start + inst_len
            disp = target_pos - next_rip
            self.code[patch_pos:patch_pos + 4] = struct.pack("<i", disp)


class LipiElfCompiler:
    """
    Compiles Lipi AST nodes directly into an executable Linux ELF64 binary.
    """

    def __init__(self):
        self.asm = X86Emitter()
        self.string_pool: Dict[str, str] = {}  # string_content -> label_name
        self.functions: Set[str] = set()
        self.fn_return_types: Dict[str, int] = {}  # fn_name -> TYPE_*
        self.struct_defs: Dict[str, List[str]] = {}  # struct_name -> [field_names]

        # Scope and variable management
        self.current_fn: Optional[str] = None
        self.local_offsets: Dict[str, int] = {}  # var_name -> rbp_offset
        self.local_types: Dict[str, int] = {}    # var_name -> TYPE_*
        self.local_struct_types: Dict[str, str] = {}  # var_name -> struct_name
        self.current_frame_size = 0

        # Loop control stacks
        self.loop_starts: List[str] = []
        self.loop_ends: List[str] = []

        # Heap labels for Libc-less allocator
        self.heap_base_lbl = "_lipi_heap_base"
        self.heap_ptr_lbl  = "_lipi_heap_ptr"

    def get_or_add_string(self, text: str) -> str:
        if text in self.string_pool:
            return self.string_pool[text]
        lbl = self.asm.new_label("str_const")
        self.string_pool[text] = lbl
        return lbl

    def allocate_local(self, name: str, val_type: int = TYPE_INT) -> int:
        if name in self.local_offsets:
            self.local_types[name] = val_type
            return self.local_offsets[name]
        self.current_frame_size += 8
        offset = self.current_frame_size
        self.local_offsets[name] = offset
        self.local_types[name] = val_type
        return offset

    def _infer_fn_return_type(self, fn: FnDef) -> int:
        """
        Infers return type of function (TYPE_STR, TYPE_INT, or TYPE_DYNAMIC)
        by scanning all return statements across all branches.
        """
        return_types: Set[int] = set()

        def scan(node: Node):
            if isinstance(node, Return):
                if node.value is None:
                    return_types.add(TYPE_INT)
                elif isinstance(node.value, String):
                    return_types.add(TYPE_STR)
                elif isinstance(node.value, BinOp) and node.value.op == "+":
                    if isinstance(node.value.left, String) or isinstance(node.value.right, String):
                        return_types.add(TYPE_STR)
                    else:
                        return_types.add(TYPE_INT)
                elif isinstance(node.value, Number):
                    return_types.add(TYPE_INT)
                elif isinstance(node.value, Identifier):
                    # Identifier could hold int or string at runtime
                    return_types.add(TYPE_DYNAMIC)
                else:
                    return_types.add(TYPE_INT)
            elif isinstance(node, Block):
                for s in node.stmts:
                    scan(s)
            elif isinstance(node, If):
                scan(node.then_block)
                if node.else_block:
                    scan(node.else_block)
            elif isinstance(node, (While, Repeat, ForRange, ForEach)):
                scan(node.body)

        scan(fn.body)
        if not return_types:
            return TYPE_INT
        if len(return_types) == 1:
            return next(iter(return_types))
        if TYPE_STR in return_types or TYPE_DYNAMIC in return_types:
            return TYPE_DYNAMIC
        return TYPE_INT

    def compile(self, program: Program) -> bytes:
        """
        Full compilation pipeline:
        1. Pre-scan structs and function signatures.
        2. Emit _start bootstrap and Libc-less runtime stubs.
        3. Compile all function definitions.
        4. Compile main program body into lipi_main.
        5. Emit data section (string constants and heap tracking pointers).
        6. Backpatch relative offsets.
        7. Wrap in ELF64 file header and PT_LOAD program header.
        """
        # Pre-scan structs
        for s in program.stmts:
            if isinstance(s, StructDef):
                self.struct_defs[s.name] = s.fields

        # Pre-scan function return types
        for s in program.stmts:
            if isinstance(s, FnDef):
                self.fn_return_types[s.name] = self._infer_fn_return_type(s)

        # 1. Libc-less Runtime Engine
        self._emit_runtime_stubs()

        # 2. Compile user functions
        fn_nodes = [s for s in program.stmts if isinstance(s, FnDef)]
        main_nodes = [s for s in program.stmts if not isinstance(s, (FnDef, StructDef))]

        for fn in fn_nodes:
            self._compile_function(fn)

        # 3. Compile lipi_main
        self._compile_main(main_nodes)

        # 4. Data Section (String literals + heap state)
        self._emit_data_section()

        # 5. Backpatch all offsets
        self.asm.backpatch()

        # 6. Wrap in ELF64 binary format
        return self._wrap_elf(bytes(self.asm.code))

    def _emit_runtime_stubs(self):
        """
        Pure x86_64 Libc-less Baremetal Runtime:
        Zero C library functions! Direct Linux kernel syscalls:
        sys_write (1), sys_mmap (9), sys_munmap (11), sys_exit (60).
        """
        asm = self.asm

        # ── _start: Kernel Entry Point ──────────────────────────────────────
        asm.define_label("_start")
        # ── Multiboot 1 Specification Header (16 bytes aligned) ─────────────
        # WHY: Allows Lipi binaries to boot directly on bare metal (QEMU / GRUB).
        # We emit a short jump (0xEB, 0x0E) over the 14 bytes so Linux userland
        # execution jumps straight to stack alignment and heap init.
        # Magic: 0x1BADB002, Flags: 0x00000000, Checksum: 0xE4524FFE
        asm.emit(b"\xeb\x0e")                     # jmp short +14 bytes
        asm.emit(b"\x90\x90")                     # 2 nop padding to 4-byte align
        asm.emit(struct.pack("<III", 0x1BADB002, 0x00000000, 0xE4524FFE)) # Multiboot header (12 bytes)

        # Align stack to 16 bytes for System V ABI compliance
        asm.emit(b"\x48\x83\xe4\xf0")  # and rsp, -16
        asm.call("_lipi_init_heap")   # initialize 16MB bump allocator
        asm.call("lipi_main")
        # Exit with lipi_main return value
        asm.mov_reg_reg(RDI, RAX)
        asm.mov_reg_imm64(RAX, 60)    # sys_exit
        asm.syscall()
        asm.emit(b"\xf4")             # hlt (unreachable safety)

        # ── _lipi_init_heap: Allocates 16MB via sys_mmap ────────────────────
        asm.define_label("_lipi_init_heap")
        # sys_mmap(0, 16777216, 3 (PROT_READ|PROT_WRITE), 34 (MAP_PRIVATE|MAP_ANONYMOUS), -1, 0)
        asm.emit(b"\x48\x31\xff")     # xor rdi, rdi
        asm.mov_reg_imm64(RSI, 16777216) # 16MB
        asm.mov_reg_imm64(RDX, 3)     # PROT_READ | PROT_WRITE
        asm.mov_reg_imm64(R10, 34)    # MAP_PRIVATE | MAP_ANONYMOUS
        asm.mov_reg_imm64(R8, -1)     # fd = -1
        asm.emit(b"\x4d\x31\xc9")     # xor r9, r9
        asm.mov_reg_imm64(RAX, 9)     # sys_mmap
        asm.syscall()
        # Save base and current ptr
        asm.lea_reg_rip(RBX, self.heap_base_lbl)
        asm.emit(b"\x48\x89\x03")     # mov [rbx], rax
        asm.lea_reg_rip(RBX, self.heap_ptr_lbl)
        asm.emit(b"\x48\x89\x03")     # mov [rbx], rax
        asm.ret()

        # ── _lipi_alloc: O(1) Bump Allocator ─────────────────────────────────
        # in: rdi = size in bytes. out: rax = allocated pointer.
        # Length of allocation stored at [rax - 8]!
        asm.define_label("_lipi_alloc")
        asm.emit(b"\x53")             # push rbx
        asm.emit(b"\x41\x54")         # push r12
        asm.emit(b"\x49\x89\xfc")     # mov r12, rdi (orig size)
        asm.emit(b"\x48\x83\xc7\x07") # add rdi, 7
        asm.emit(b"\x48\x83\xe7\xf8") # and rdi, -8 (align to 8 bytes)
        asm.emit(b"\x48\x83\xc7\x08") # add rdi, 8 (add 8 bytes for length prefix)

        asm.lea_reg_rip(RBX, self.heap_ptr_lbl)
        asm.emit(b"\x48\x8b\x03")     # mov rax, [rbx] (current ptr)
        asm.emit(b"\x48\x01\xc7")     # add rdi, rax (new ptr)
        asm.emit(b"\x48\x89\x3b")     # mov [rbx], rdi (update heap ptr)

        asm.emit(b"\x4c\x89\x20")     # mov [rax], r12 (store length prefix)
        asm.emit(b"\x48\x83\xc0\x08") # add rax, 8 (return pointer right after length)
        asm.emit(b"\x41\x5c")         # pop r12
        asm.emit(b"\x5b")             # pop rbx
        asm.ret()

        # ── _lipi_str_concat: Concatenate two strings ────────────────────────
        # in: rdi = str1, rsi = str2. out: rax = new string pointer.
        asm.define_label("_lipi_str_concat")
        asm.push_rbp()
        asm.mov_rbp_rsp()
        asm.emit(b"\x41\x54")         # push r12
        asm.emit(b"\x41\x55")         # push r13
        asm.emit(b"\x41\x56")         # push r14
        asm.emit(b"\x41\x57")         # push r15

        asm.emit(b"\x49\x89\xfc")     # mov r12, rdi (str1)
        asm.emit(b"\x49\x89\xf5")     # mov r13, rsi (str2)
        asm.emit(b"\x4d\x8b\x74\x24\xf8") # mov r14, [r12 - 8] (len1)
        asm.emit(b"\x4d\x8b\x7d\xf8") # mov r15, [r13 - 8] (len2)

        asm.mov_reg_reg(RDI, R14)     # rdi = len1
        asm.emit(b"\x4c\x01\xff")     # add rdi, r15 (rdi = len1 + len2)
        asm.emit(b"\x48\xff\xc7")     # inc rdi (+1 for null byte)
        asm.call("_lipi_alloc")       # returns rax

        # Save allocated string pointer on stack
        asm.push_reg(RAX)

        # Copy str1: dst=rax, src=r12, count=r14
        asm.mov_reg_reg(RDI, RAX)
        asm.mov_reg_reg(RSI, R12)
        asm.mov_reg_reg(RCX, R14)
        asm.emit(b"\xf3\xa4")         # rep movsb

        # Copy str2: dst=rdi, src=r13, count=r15
        asm.mov_reg_reg(RSI, R13)
        asm.mov_reg_reg(RCX, R15)
        asm.emit(b"\xf3\xa4")         # rep movsb

        # Null terminate
        asm.emit(b"\xc6\x07\x00")     # mov byte [rdi], 0

        # Restore allocated string pointer
        asm.pop_reg(RAX)

        # Store total length at [rax - 8]
        asm.emit(b"\x4d\x01\xfe")     # add r14, r15 (total_len = len1 + len2)
        asm.emit(b"\x4c\x89\x70\xf8") # mov [rax - 8], r14

        asm.emit(b"\x41\x5f")         # pop r15
        asm.emit(b"\x41\x5e")         # pop r14
        asm.emit(b"\x41\x5d")         # pop r13
        asm.emit(b"\x41\x5c")         # pop r12
        asm.leave()
        asm.ret()

        # ── _lipi_int_to_str: Signed 64-bit int to string in heap ───────────
        # in: rdi = signed integer. out: rax = string pointer (with len at rax - 8).
        asm.define_label("_lipi_int_to_str")
        asm.push_rbp()
        asm.mov_rbp_rsp()
        asm.emit(b"\x41\x54")         # push r12
        asm.emit(b"\x41\x55")         # push r13
        asm.emit(b"\x41\x56")         # push r14

        asm.emit(b"\x49\x89\xfc")     # mov r12, rdi (orig val)
        asm.mov_reg_imm64(RDI, 48)    # alloc 48 bytes
        asm.call("_lipi_alloc")       # returns rax

        asm.emit(b"\x4c\x8d\x40\x28") # lea r8, [rax + 40] (end of buffer)
        asm.emit(b"\x41\xc6\x00\x00") # mov byte [r8], 0 (null terminator)
        asm.emit(b"\x4d\x89\xc5")     # mov r13, r8 (end pointer)

        asm.mov_reg_reg(RAX, R12)     # val in rax
        asm.emit(b"\x4d\x31\xf6")     # xor r14, r14 (is_neg = 0)

        lbl_its_chkneg = asm.new_label("its_chkneg")
        lbl_its_setup  = asm.new_label("its_setup")
        lbl_its_loop   = asm.new_label("its_loop")
        lbl_its_done   = asm.new_label("its_done")

        asm.emit(b"\x48\x85\xc0")      # test rax, rax
        asm.jnz(lbl_its_chkneg)

        # Zero case
        asm.emit(b"\x49\xff\xc8")      # dec r8
        asm.emit(b"\x41\xc6\x00\x30")  # mov byte [r8], '0'
        asm.jmp(lbl_its_done)

        asm.define_label(lbl_its_chkneg)
        asm.emit(b"\x48\x85\xc0")      # test rax, rax
        pos = len(asm.code)
        asm.emit(b"\x0f\x89\x00\x00\x00\x00") # jns (0f 89)
        asm.relocs.append((pos + 2, lbl_its_setup, 6))

        asm.neg_rax()
        asm.emit(b"\x49\xc7\xc6\x01\x00\x00\x00") # mov r14, 1

        asm.define_label(lbl_its_setup)
        asm.mov_reg_imm64(RBX, 10)

        asm.define_label(lbl_its_loop)
        asm.emit(b"\x48\x31\xd2")      # xor rdx, rdx
        asm.emit(b"\x48\xf7\xf3")      # div rbx
        asm.emit(b"\x80\xc2\x30")      # add dl, '0'
        asm.emit(b"\x49\xff\xc8")      # dec r8
        asm.emit(b"\x41\x88\x10")      # mov [r8], dl
        asm.emit(b"\x48\x85\xc0")      # test rax, rax
        asm.jnz(lbl_its_loop)

        # Negative sign
        asm.emit(b"\x4d\x85\xf6")      # test r14, r14
        asm.jz(lbl_its_done)
        asm.emit(b"\x49\xff\xc8")      # dec r8
        asm.emit(b"\x41\xc6\x00\x2d")  # mov byte [r8], '-'

        asm.define_label(lbl_its_done)
        # Length = r13 - r8
        asm.mov_reg_reg(RDX, R13)
        asm.emit(b"\x4c\x29\xc2")      # sub rdx, r8
        asm.emit(b"\x49\x89\x50\xf8")  # mov [r8 - 8], rdx
        asm.mov_reg_reg(RAX, R8)       # return pointer at r8

        asm.emit(b"\x41\x5e")         # pop r14
        asm.emit(b"\x41\x5d")         # pop r13
        asm.emit(b"\x41\x5c")         # pop r12
        asm.leave()
        asm.ret()

        # ── _lipi_print_nl: Print newline ('\n') to stdout ──────────────────
        asm.define_label("_lipi_print_nl")
        asm.emit(b"\x6a\x0a")         # push 10 ('\n')
        asm.mov_reg_reg(RSI, RSP)     # buffer = rsp
        asm.mov_reg_imm64(RDI, 1)     # fd = 1 (stdout)
        asm.mov_reg_imm64(RDX, 1)     # len = 1
        asm.mov_reg_imm64(RAX, 1)     # sys_write
        asm.syscall()
        asm.pop_reg(RAX)              # restore stack
        asm.ret()

        # ── _lipi_print_str: Print string (rdi = ptr) ───────────────────────
        # Length read from [rdi - 8]
        asm.define_label("_lipi_print_str")
        asm.emit(b"\x48\x8b\x57\xf8") # mov rdx, [rdi - 8] (len)
        asm.mov_reg_reg(RSI, RDI)     # rsi = buffer ptr
        asm.mov_reg_imm64(RDI, 1)     # rdi = 1 (stdout)
        asm.mov_reg_imm64(RAX, 1)     # sys_write
        asm.syscall()
        asm.ret()

        # ── _lipi_print_int: Print signed 64-bit integer ────────────────────
        # Converts signed integer in rdi into ASCII in stack buffer, then calls sys_write.
        asm.define_label("_lipi_print_int")
        asm.push_rbp()
        asm.mov_rbp_rsp()
        asm.sub_rsp(48)
        # r8 points to end of 48-byte buffer: rbp - 1
        asm.emit(b"\x4c\x8d\x45\xff")  # lea r8, [rbp - 1]
        asm.emit(b"\x41\xc6\x00\x00")  # mov byte [r8], 0
        asm.mov_reg_reg(RAX, RDI)
        asm.mov_reg_imm64(R9, 0)       # is_negative = false

        # Check if zero
        lbl_chkneg = asm.new_label("chkneg")
        lbl_doprint = asm.new_label("doprint")
        lbl_loop = asm.new_label("loop")
        lbl_loop_setup = asm.new_label("loop_setup")

        asm.emit(b"\x48\x85\xc0")      # test rax, rax
        asm.jnz(lbl_chkneg)

        # Zero case: write "0" and print
        asm.emit(b"\x49\xff\xc8")      # dec r8
        asm.emit(b"\x41\xc6\x00\x30")  # mov byte [r8], '0'
        asm.jmp(lbl_doprint)

        asm.define_label(lbl_chkneg)
        asm.emit(b"\x48\x85\xc0")      # test rax, rax
        pos = len(asm.code)
        asm.emit(b"\x0f\x89\x00\x00\x00\x00") # jns (0f 89)
        asm.relocs.append((pos + 2, lbl_loop_setup, 6))

        # Negative: negate and set is_negative = 1
        asm.neg_rax()
        asm.mov_reg_imm64(R9, 1)

        asm.define_label(lbl_loop_setup)
        asm.mov_reg_imm64(RBX, 10)     # divisor = 10

        asm.define_label(lbl_loop)
        asm.emit(b"\x48\x31\xd2")      # xor rdx, rdx
        asm.emit(b"\x48\xf7\xf3")      # div rbx (rax / 10, rem in rdx)
        asm.emit(b"\x80\xc2\x30")      # add dl, '0'
        asm.emit(b"\x49\xff\xc8")      # dec r8
        asm.emit(b"\x41\x88\x10")      # mov [r8], dl
        asm.emit(b"\x48\x85\xc0")      # test rax, rax
        asm.jnz(lbl_loop)

        # Check if negative sign needed
        asm.emit(b"\x4d\x85\xc9")      # test r9, r9
        asm.jz(lbl_doprint)
        asm.emit(b"\x49\xff\xc8")      # dec r8
        asm.emit(b"\x41\xc6\x00\x2d")  # mov byte [r8], '-'

        asm.define_label(lbl_doprint)
        # Length = (rbp - 1) - r8
        asm.emit(b"\x48\x8d\x55\xff")  # lea rdx, [rbp - 1]
        asm.emit(b"\x4c\x29\xc2")      # sub rdx, r8
        asm.mov_reg_reg(RSI, R8)       # buf = r8
        asm.mov_reg_imm64(RDI, 1)      # stdout
        asm.mov_reg_imm64(RAX, 1)      # sys_write
        asm.syscall()

        asm.leave()
        asm.ret()

        # ── _lipi_print_dynamic: Dynamic type dispatcher for say ────────────
        # in: rdi = val
        # If val is a string pointer (in data section or heap), call _lipi_print_str.
        # Otherwise, treat as 64-bit integer and call _lipi_print_int.
        asm.define_label("_lipi_print_dynamic")
        asm.push_rbp()
        asm.mov_rbp_rsp()
        lbl_dyn_is_int = asm.new_label("dyn_is_int")
        lbl_dyn_is_str = asm.new_label("dyn_is_str")
        lbl_dyn_chk_heap = asm.new_label("dyn_chk_heap")

        # If val == 0: it's int 0 (null is also printed as 0)
        asm.emit(b"\x48\x85\xff")  # test rdi, rdi
        asm.jz(lbl_dyn_is_int)

        # Check if rdi >= _lipi_data_start
        asm.lea_reg_rip(RAX, "_lipi_data_start")
        asm.emit(b"\x48\x39\xc7")  # cmp rdi, rax
        pos = len(asm.code)
        asm.emit(b"\x0f\x82\x00\x00\x00\x00")  # jb dyn_chk_heap
        asm.relocs.append((pos + 2, lbl_dyn_chk_heap, 6))

        # Check if rdi < _lipi_data_end
        asm.lea_reg_rip(RDX, "_lipi_data_end")
        asm.emit(b"\x48\x39\xd7")  # cmp rdi, rdx
        pos = len(asm.code)
        asm.emit(b"\x0f\x82\x00\x00\x00\x00")  # jb dyn_is_str
        asm.relocs.append((pos + 2, lbl_dyn_is_str, 6))

        # Check heap bounds: [_lipi_heap_base] <= rdi < [_lipi_heap_ptr]
        asm.define_label(lbl_dyn_chk_heap)
        asm.lea_reg_rip(RBX, self.heap_base_lbl)
        asm.emit(b"\x48\x8b\x03")  # mov rax, [rbx]
        asm.emit(b"\x48\x85\xc0")  # test rax, rax
        asm.jz(lbl_dyn_is_int)
        asm.emit(b"\x48\x39\xc7")  # cmp rdi, rax
        pos = len(asm.code)
        asm.emit(b"\x0f\x82\x00\x00\x00\x00")  # jb dyn_is_int
        asm.relocs.append((pos + 2, lbl_dyn_is_int, 6))

        asm.lea_reg_rip(RBX, self.heap_ptr_lbl)
        asm.emit(b"\x48\x8b\x13")  # mov rdx, [rbx]
        asm.emit(b"\x48\x39\xd7")  # cmp rdi, rdx
        pos = len(asm.code)
        asm.emit(b"\x0f\x83\x00\x00\x00\x00")  # jae dyn_is_int
        asm.relocs.append((pos + 2, lbl_dyn_is_int, 6))

        # Matches valid string pointer range!
        asm.define_label(lbl_dyn_is_str)
        asm.call("_lipi_print_str")
        asm.leave()
        asm.ret()

        # Matches integer value!
        asm.define_label(lbl_dyn_is_int)
        asm.call("_lipi_print_int")
        asm.leave()
        asm.ret()

        # ── _lipi_is_str: Check if rdi points to a valid Lipi string ────────
        # Returns rax = 1 (true) if rdi is within data section or heap, else 0.
        asm.define_label("_lipi_is_str")
        lbl_is_str_chk_heap = asm.new_label("iss_chk_heap")
        lbl_is_str_true     = asm.new_label("iss_true")
        lbl_is_str_false    = asm.new_label("iss_false")

        asm.emit(b"\x48\x85\xff")  # test rdi, rdi
        asm.jz(lbl_is_str_false)

        # Check data section: _lipi_data_start <= rdi < _lipi_data_end
        asm.lea_reg_rip(RAX, "_lipi_data_start")
        asm.emit(b"\x48\x39\xc7")  # cmp rdi, rax
        pos = len(asm.code)
        asm.emit(b"\x0f\x82\x00\x00\x00\x00")  # jb iss_chk_heap
        asm.relocs.append((pos + 2, lbl_is_str_chk_heap, 6))

        asm.lea_reg_rip(RDX, "_lipi_data_end")
        asm.emit(b"\x48\x39\xd7")  # cmp rdi, rdx
        pos = len(asm.code)
        asm.emit(b"\x0f\x82\x00\x00\x00\x00")  # jb iss_true
        asm.relocs.append((pos + 2, lbl_is_str_true, 6))

        # Check heap section: [_lipi_heap_base] <= rdi < [_lipi_heap_ptr]
        asm.define_label(lbl_is_str_chk_heap)
        asm.lea_reg_rip(RBX, self.heap_base_lbl)
        asm.emit(b"\x48\x8b\x03")  # mov rax, [rbx]
        asm.emit(b"\x48\x85\xc0")  # test rax, rax
        asm.jz(lbl_is_str_false)
        asm.emit(b"\x48\x39\xc7")  # cmp rdi, rax
        pos = len(asm.code)
        asm.emit(b"\x0f\x82\x00\x00\x00\x00")  # jb iss_false
        asm.relocs.append((pos + 2, lbl_is_str_false, 6))

        asm.lea_reg_rip(RBX, self.heap_ptr_lbl)
        asm.emit(b"\x48\x8b\x13")  # mov rdx, [rbx]
        asm.emit(b"\x48\x39\xd7")  # cmp rdi, rdx
        pos = len(asm.code)
        asm.emit(b"\x0f\x83\x00\x00\x00\x00")  # jae iss_false
        asm.relocs.append((pos + 2, lbl_is_str_false, 6))

        asm.define_label(lbl_is_str_true)
        asm.mov_reg_imm64(RAX, 1)
        asm.ret()

        asm.define_label(lbl_is_str_false)
        asm.mov_reg_imm64(RAX, 0)
        asm.ret()

        # ── _lipi_ensure_str: Ensure value in rdi is a string pointer ───────
        # in: rdi = val. out: rax = string pointer.
        asm.define_label("_lipi_ensure_str")
        asm.push_rbp()
        asm.mov_rbp_rsp()
        asm.push_reg(RBX)
        asm.push_reg(R12)
        asm.mov_reg_reg(R12, RDI)
        asm.call("_lipi_is_str")
        lbl_es_already = asm.new_label("es_already")
        asm.emit(b"\x48\x85\xc0")  # test rax, rax
        asm.jnz(lbl_es_already)
        # Not string -> convert int to str
        asm.mov_reg_reg(RDI, R12)
        asm.call("_lipi_int_to_str")
        asm.pop_reg(R12)
        asm.pop_reg(RBX)
        asm.leave()
        asm.ret()
        asm.define_label(lbl_es_already)
        asm.mov_reg_reg(RAX, R12)
        asm.pop_reg(R12)
        asm.pop_reg(RBX)
        asm.leave()
        asm.ret()

        # ── _lipi_add_dynamic: Dynamic addition / concatenation ──────────────
        # in: rdi = left, rsi = right. out: rax = sum (int) or concat (str).
        asm.define_label("_lipi_add_dynamic")
        asm.push_rbp()
        asm.mov_rbp_rsp()
        asm.push_reg(R12)
        asm.push_reg(R13)
        asm.push_reg(R14)
        asm.mov_reg_reg(R12, RDI)
        asm.mov_reg_reg(R13, RSI)

        lbl_ad_str = asm.new_label("ad_str")

        # Test left
        asm.mov_reg_reg(RDI, R12)
        asm.call("_lipi_is_str")
        asm.emit(b"\x48\x85\xc0")  # test rax, rax
        asm.jnz(lbl_ad_str)

        # Test right
        asm.mov_reg_reg(RDI, R13)
        asm.call("_lipi_is_str")
        asm.emit(b"\x48\x85\xc0")  # test rax, rax
        asm.jnz(lbl_ad_str)

        # Integer addition
        asm.mov_reg_reg(RAX, R12)
        asm.mov_reg_reg(RBX, R13)
        asm.add_rax_rbx()
        asm.pop_reg(R14)
        asm.pop_reg(R13)
        asm.pop_reg(R12)
        asm.leave()
        asm.ret()

        # String concatenation
        asm.define_label(lbl_ad_str)
        asm.mov_reg_reg(RDI, R12)
        asm.call("_lipi_ensure_str")
        asm.mov_reg_reg(R14, RAX)  # r14 = left str

        asm.mov_reg_reg(RDI, R13)
        asm.call("_lipi_ensure_str")
        asm.mov_reg_reg(RSI, RAX)  # rsi = right str
        asm.mov_reg_reg(RDI, R14)  # rdi = left str
        asm.call("_lipi_str_concat")
        asm.pop_reg(R14)
        asm.pop_reg(R13)
        asm.pop_reg(R12)
        asm.leave()
        asm.ret()

    def _compile_main(self, stmts: List[Node]):
        asm = self.asm
        asm.define_label("lipi_main")
        asm.push_rbp()
        asm.mov_rbp_rsp()

        # Reset locals for main
        self.current_fn = "lipi_main"
        self.local_offsets = {}
        self.local_types = {}
        self.local_struct_types = {}
        self.current_frame_size = 0

        # Pre-scan statements to allocate stack space
        for stmt in stmts:
            self._scan_locals(stmt)

        # Align frame size to 16 bytes with 32 bytes headroom
        frame_aligned = ((self.current_frame_size + 32) + 15) & ~15
        if frame_aligned > 0:
            asm.sub_rsp(frame_aligned)

        # Compile all main statements
        for stmt in stmts:
            self._compile_stmt(stmt)

        # Return 0 from lipi_main
        asm.mov_reg_imm64(RAX, 0)
        asm.leave()
        asm.ret()

    def _compile_function(self, fn: FnDef):
        asm = self.asm
        fn_label = f"fn_{fn.name}"
        self.functions.add(fn.name)
        asm.define_label(fn_label)
        asm.push_rbp()
        asm.mov_rbp_rsp()

        self.current_fn = fn.name
        self.local_offsets = {}
        self.local_types = {}
        self.local_struct_types = {}
        self.current_frame_size = 0

        # Map function parameters (first 6 in RDI, RSI, RDX, RCX, R8, R9)
        param_regs = [RDI, RSI, RDX, RCX, R8, R9]
        for i, param_name in enumerate(fn.params):
            off = self.allocate_local(param_name, TYPE_INT)
            if i < len(param_regs):
                asm.mov_stack_reg(off, param_regs[i])

        # Scan function body for additional local variables
        self._scan_locals(fn.body)

        frame_aligned = ((self.current_frame_size + 32) + 15) & ~15
        if frame_aligned > 0:
            asm.sub_rsp(frame_aligned)

        # Compile body
        self._compile_stmt(fn.body)

        # Default epilogue if no explicit return
        asm.mov_reg_imm64(RAX, 0)
        asm.leave()
        asm.ret()

    def _scan_locals(self, node: Node):
        if node is None:
            return
        if isinstance(node, Assign):
            self.allocate_local(node.name)
        elif isinstance(node, ForRange):
            self.allocate_local(node.var)
            self.allocate_local(f"__for_end_{node.var}")
            self._scan_locals(node.body)
        elif isinstance(node, Repeat):
            self.allocate_local(f"__rep_cnt_{id(node)}")
            self._scan_locals(node.body)
        elif isinstance(node, Block):
            for s in node.stmts:
                self._scan_locals(s)
        elif isinstance(node, If):
            self._scan_locals(node.then_block)
            if node.else_block:
                self._scan_locals(node.else_block)
        elif isinstance(node, (While,)):
            self._scan_locals(node.body)

    def _compile_stmt(self, stmt: Node):
        if stmt is None:
            return
        asm = self.asm

        if isinstance(stmt, Assign):
            # Check if constructor call: Point()
            if isinstance(stmt.value, FnCall) and isinstance(stmt.value.func, Identifier):
                cname = stmt.value.func.name
                if cname in self.struct_defs:
                    # Allocate struct on heap
                    num_fields = len(self.struct_defs[cname])
                    asm.mov_reg_imm64(RDI, num_fields * 8)
                    asm.call("_lipi_alloc")
                    off = self.allocate_local(stmt.name, TYPE_STRUCT)
                    self.local_struct_types[stmt.name] = cname
                    asm.mov_stack_rax(off)
                    return

            expr_type = self._compile_expr(stmt.value)
            off = self.allocate_local(stmt.name, expr_type)
            asm.mov_stack_rax(off)

        elif isinstance(stmt, FieldAssign):
            # p.x = val
            val_type = self._compile_expr(stmt.value)
            asm.push_reg(RAX)  # save value

            # Evaluate object pointer
            if isinstance(stmt.obj, Identifier):
                var_name = stmt.obj.name
                st_name = self.local_struct_types.get(var_name)
                f_idx = 0
                if st_name and st_name in self.struct_defs and stmt.field in self.struct_defs[st_name]:
                    f_idx = self.struct_defs[st_name].index(stmt.field)
                else:
                    for sname, sfields in self.struct_defs.items():
                        if stmt.field in sfields:
                            f_idx = sfields.index(stmt.field)
                            break

                if val_type == TYPE_STR:
                    self.local_types[f"{var_name}.{stmt.field}"] = TYPE_STR

                off = self.local_offsets.get(var_name, 0)
                asm.mov_rax_stack(off)  # rax = struct pointer
                asm.pop_reg(RBX)        # rbx = value
                # mov [rax + f_idx * 8], rbx
                field_disp = f_idx * 8
                if field_disp == 0:
                    asm.emit(b"\x48\x89\x18")  # mov [rax], rbx
                else:
                    asm.emit(b"\x48\x89\x58" + bytes([field_disp]))
            else:
                asm.pop_reg(RAX)

        elif isinstance(stmt, Return):
            if stmt.value:
                self._compile_expr(stmt.value)
            else:
                asm.mov_reg_imm64(RAX, 0)
            asm.leave()
            asm.ret()

        elif isinstance(stmt, If):
            lbl_else = asm.new_label("if_else")
            lbl_end = asm.new_label("if_end")

            self._compile_expr(stmt.condition)
            asm.emit(b"\x48\x85\xc0")  # test rax, rax
            asm.jz(lbl_else)

            self._compile_stmt(stmt.then_block)
            asm.jmp(lbl_end)

            asm.define_label(lbl_else)
            if stmt.else_block:
                self._compile_stmt(stmt.else_block)

            asm.define_label(lbl_end)

        elif isinstance(stmt, While):
            lbl_start = asm.new_label("while_start")
            lbl_end = asm.new_label("while_end")

            self.loop_starts.append(lbl_start)
            self.loop_ends.append(lbl_end)

            asm.define_label(lbl_start)
            self._compile_expr(stmt.condition)
            asm.emit(b"\x48\x85\xc0")  # test rax, rax
            asm.jz(lbl_end)

            self._compile_stmt(stmt.body)
            asm.jmp(lbl_start)

            asm.define_label(lbl_end)
            self.loop_starts.pop()
            self.loop_ends.pop()

        elif isinstance(stmt, Repeat):
            lbl_start = asm.new_label("repeat_start")
            lbl_end = asm.new_label("repeat_end")

            # Evaluate count -> store in temporary stack slot
            self._compile_expr(stmt.count)
            counter_off = self.allocate_local(f"__rep_cnt_{id(stmt)}", TYPE_INT)
            asm.mov_stack_rax(counter_off)

            self.loop_starts.append(lbl_start)
            self.loop_ends.append(lbl_end)

            asm.define_label(lbl_start)
            asm.mov_rax_stack(counter_off)
            asm.emit(b"\x48\x85\xc0")  # test rax, rax
            pos = len(asm.code)
            asm.emit(b"\x0f\x8e\x00\x00\x00\x00")  # jle (0f 8e)
            asm.relocs.append((pos + 2, lbl_end, 6))

            # Decrement counter
            asm.emit(b"\x48\xff\xc8")  # dec rax
            asm.mov_stack_rax(counter_off)

            self._compile_stmt(stmt.body)
            asm.jmp(lbl_start)

            asm.define_label(lbl_end)
            self.loop_starts.pop()
            self.loop_ends.pop()

        elif isinstance(stmt, ForRange):
            lbl_start = asm.new_label("for_start")
            lbl_step = asm.new_label("for_step")
            lbl_end = asm.new_label("for_end")

            var_off = self.allocate_local(stmt.var, TYPE_INT)
            end_off = self.allocate_local(f"__for_end_{stmt.var}", TYPE_INT)

            # Initialize start
            self._compile_expr(stmt.start)
            asm.mov_stack_rax(var_off)

            # Evaluate end
            self._compile_expr(stmt.end)
            asm.mov_stack_rax(end_off)

            self.loop_starts.append(lbl_step)
            self.loop_ends.append(lbl_end)

            asm.define_label(lbl_start)
            # Compare var with end: var <= end
            asm.mov_rax_stack(var_off)
            asm.mov_reg_stack(RBX, end_off)
            asm.cmp_rax_rbx()
            pos = len(asm.code)
            asm.emit(b"\x0f\x8f\x00\x00\x00\x00")  # jg (0f 8f)
            asm.relocs.append((pos + 2, lbl_end, 6))

            self._compile_stmt(stmt.body)

            asm.define_label(lbl_step)
            # Increment var
            step_val = 1
            if stmt.step:
                if isinstance(stmt.step, Number):
                    step_val = int(stmt.step.value)
            asm.mov_rax_stack(var_off)
            if step_val == 1:
                asm.emit(b"\x48\xff\xc0")  # inc rax
            else:
                asm.emit(b"\x48\x05" + struct.pack("<i", step_val))
            asm.mov_stack_rax(var_off)
            asm.jmp(lbl_start)

            asm.define_label(lbl_end)
            self.loop_starts.pop()
            self.loop_ends.pop()

        elif isinstance(stmt, Break):
            if self.loop_ends:
                asm.jmp(self.loop_ends[-1])

        elif isinstance(stmt, Continue):
            if self.loop_starts:
                asm.jmp(self.loop_starts[-1])

        elif isinstance(stmt, Block):
            for s in stmt.stmts:
                self._compile_stmt(s)

        elif isinstance(stmt, FnCall):
            # Check if this is say / print
            fn_name = stmt.func.name if isinstance(stmt.func, Identifier) else None
            if fn_name in ("say", "show", "print", "println", "বলো", "দেখাও"):
                self._compile_say(stmt.args)
            elif fn_name == "syscall":
                self._compile_syscall(stmt.args)
            else:
                self._compile_call(stmt)

        else:
            # Standalone expression
            self._compile_expr(stmt)

    def _compile_say(self, args: List[Node]):
        """
        say arg1 arg2 ...
        Prints arguments separated by spaces, followed by newline.
        """
        asm = self.asm
        for i, arg in enumerate(args):
            if i > 0:
                # Print single space " "
                sp_lbl = self.get_or_add_string(" ")
                asm.lea_reg_rip(RDI, sp_lbl)
                asm.call("_lipi_print_str")

            arg_type = self._compile_expr(arg)
            if arg_type == TYPE_STR:
                # Guaranteed string pointer in RAX
                asm.mov_reg_reg(RDI, RAX)
                asm.call("_lipi_print_str")
            elif isinstance(arg, Number):
                # Guaranteed integer literal
                asm.mov_reg_reg(RDI, RAX)
                asm.call("_lipi_print_int")
            else:
                # Dynamic check at runtime: handles function returns, variables, structs
                asm.mov_reg_reg(RDI, RAX)
                asm.call("_lipi_print_dynamic")

        asm.call("_lipi_print_nl")

    def _compile_syscall(self, args: List[Node]) -> int:
        """
        Direct Linux AMD64 Syscall invocation:
        syscall(number, arg1, arg2, arg3, arg4, arg5, arg6)
        Syscall register mapping:
          RAX: syscall number
          RDI: arg 1
          RSI: arg 2
          RDX: arg 3
          R10: arg 4  (NOTE: R10, not RCX!)
          R8:  arg 5
          R9:  arg 6
        """
        asm = self.asm
        # Evaluate all args and push to stack (evaluated left to right)
        for arg in args:
            self._compile_expr(arg)
            asm.push_reg(RAX)

        # Pop into syscall registers in reverse order
        # Number of args can be 1 to 7 (syscall_num + up to 6 args)
        n = len(args)
        regs_in_order = [RAX, RDI, RSI, RDX, R10, R8, R9]

        for i in range(n - 1, -1, -1):
            target_reg = regs_in_order[i]
            asm.pop_reg(target_reg)

        asm.syscall()
        # Return value is already in RAX
        return TYPE_INT

    def _compile_call(self, call: FnCall) -> int:
        asm = self.asm
        fn_name = call.func.name if isinstance(call.func, Identifier) else None

        # Builtin len / length / দৈর্ঘ্য (Direct machine code length lookup)
        # WHY: String allocations and constants always store 64-bit length at [ptr - 8]
        if fn_name in ("len", "length", "দৈর্ঘ্য"):
            if call.args:
                self._compile_expr(call.args[0])
                lbl_nz = asm.new_label("len_nz")
                lbl_done = asm.new_label("len_done")
                asm.emit(b"\x48\x85\xc0")  # test rax, rax
                asm.jnz(lbl_nz)
                asm.jmp(lbl_done)
                asm.define_label(lbl_nz)
                asm.emit(b"\x48\x8b\x40\xf8")  # mov rax, [rax - 8]
                asm.define_label(lbl_done)
            else:
                asm.mov_reg_imm64(RAX, 0)
            return TYPE_INT

        # Builtin abs (integer absolute value)
        if fn_name in ("abs",):
            if call.args:
                self._compile_expr(call.args[0])
                lbl_pos = asm.new_label("abs_pos")
                asm.emit(b"\x48\x85\xc0")  # test rax, rax
                pos = len(asm.code)
                asm.emit(b"\x0f\x89\x00\x00\x00\x00")  # jns
                asm.relocs.append((pos + 2, lbl_pos, 6))
                asm.neg_rax()
                asm.define_label(lbl_pos)
            return TYPE_INT

        # Pass arguments in System V AMD64 ABI: RDI, RSI, RDX, RCX, R8, R9
        param_regs = [RDI, RSI, RDX, RCX, R8, R9]
        for arg in call.args:
            self._compile_expr(arg)
            asm.push_reg(RAX)

        for i in range(len(call.args) - 1, -1, -1):
            if i < len(param_regs):
                asm.pop_reg(param_regs[i])
            else:
                asm.pop_reg(RAX)  # remaining args

        asm.call(f"fn_{fn_name}")
        return self.fn_return_types.get(fn_name, TYPE_INT)

    def _compile_expr(self, expr: Node) -> int:
        asm = self.asm

        if isinstance(expr, Number):
            val = int(expr.value)
            asm.mov_reg_imm64(RAX, val)
            return TYPE_INT

        elif isinstance(expr, String):
            # Check for string interpolation: "hello {name}!"
            val = expr.value
            if "{" in val and "}" in val:
                # Desugar interpolation to concatenation chain
                parts = []
                last_idx = 0
                for match in re.finditer(r"\{([^}]+)\}", val):
                    start, end = match.span()
                    if start > last_idx:
                        parts.append(String(val[last_idx:start]))
                    var_expr = match.group(1).strip()
                    try:
                        from src.runtime.lexer import Lexer
                        from src.runtime.parser import Parser
                        p = Parser(Lexer(var_expr + "\n").tokenize())
                        parts.append(p.parse_expr())
                    except Exception:
                        parts.append(Identifier(var_expr))
                    last_idx = end
                if last_idx < len(val):
                    parts.append(String(val[last_idx:]))

                if parts:
                    chain = parts[0]
                    for p in parts[1:]:
                        chain = BinOp("+", chain, p)
                    return self._compile_expr(chain)

            lbl = self.get_or_add_string(expr.value)
            asm.lea_reg_rip(RAX, lbl)
            return TYPE_STR

        elif isinstance(expr, Bool):
            val = 1 if expr.value else 0
            asm.mov_reg_imm64(RAX, val)
            return TYPE_BOOL

        elif isinstance(expr, Null):
            asm.mov_reg_imm64(RAX, 0)
            return TYPE_INT

        elif isinstance(expr, Identifier):
            if expr.name in self.local_offsets:
                off = self.local_offsets[expr.name]
                asm.mov_rax_stack(off)
                return self.local_types.get(expr.name, TYPE_INT)
            elif expr.name in self.fn_return_types:
                # WHY: Support 0-argument function invocation without parentheses (e.g. `kernel_main`)
                return self._compile_call(FnCall(expr, []))
            else:
                # Undefined variable -> return 0
                asm.mov_reg_imm64(RAX, 0)
                return TYPE_INT

        elif isinstance(expr, FieldAccess):
            if isinstance(expr.obj, Identifier):
                var_name = expr.obj.name
                st_name = self.local_struct_types.get(var_name)
                f_idx = 0
                if st_name and st_name in self.struct_defs and expr.field in self.struct_defs[st_name]:
                    f_idx = self.struct_defs[st_name].index(expr.field)
                else:
                    for sname, sfields in self.struct_defs.items():
                        if expr.field in sfields:
                            f_idx = sfields.index(expr.field)
                            break

                off = self.local_offsets.get(var_name, 0)
                asm.mov_rax_stack(off)  # rax = struct pointer
                field_disp = f_idx * 8
                if field_disp == 0:
                    asm.emit(b"\x48\x8b\x00")  # mov rax, [rax]
                else:
                    asm.emit(b"\x48\x8b\x40" + bytes([field_disp]))

                # Check if field holds string or dynamic
                return self.local_types.get(f"{var_name}.{expr.field}", TYPE_DYNAMIC)
            return TYPE_INT

        elif isinstance(expr, UnaryOp):
            t = self._compile_expr(expr.operand)
            if expr.op == "-":
                asm.neg_rax()
            elif expr.op == "not":
                asm.not_rax()
            elif expr.op == "~":
                asm.bit_not_rax()
            return TYPE_INT

        elif isinstance(expr, BinOp):
            op = expr.op

            # ── Dynamic Addition & String Concatenation ──────────────────────
            if op == "+":
                # Evaluate left
                t_left = self._compile_expr(expr.left)
                asm.push_reg(RAX)  # save left

                # Evaluate right
                t_right = self._compile_expr(expr.right)
                asm.mov_reg_reg(RSI, RAX)  # rsi = right
                asm.pop_reg(RDI)           # rdi = left

                if t_left == TYPE_INT and t_right == TYPE_INT:
                    # Pure integer addition fast path
                    asm.mov_reg_reg(RAX, RDI)
                    asm.mov_reg_reg(RBX, RSI)
                    asm.add_rax_rbx()
                    return TYPE_INT
                elif t_left == TYPE_STR and t_right == TYPE_STR:
                    # Pure string concatenation fast path
                    asm.call("_lipi_str_concat")
                    return TYPE_STR
                else:
                    # Dynamic addition / concatenation dispatch
                    asm.call("_lipi_add_dynamic")
                    if t_left == TYPE_STR or t_right == TYPE_STR:
                        return TYPE_STR
                    return TYPE_DYNAMIC

            # Evaluate left side
            self._compile_expr(expr.left)
            asm.push_reg(RAX)

            # Evaluate right side
            self._compile_expr(expr.right)
            asm.mov_reg_reg(RBX, RAX)  # rbx = right
            asm.pop_reg(RAX)           # rax = left

            if op == "-":
                asm.sub_rax_rbx()
            elif op == "*":
                asm.imul_rax_rbx()
            elif op == "/":
                asm.idiv_rbx()
            elif op == "%":
                asm.imod_rbx()
            elif op in ("==", "!=", "<", "<=", ">", ">="):
                asm.set_cmp(op)
            elif op == "and":
                asm.and_rax_rbx()
            elif op == "or":
                asm.or_rax_rbx()
            elif op == "^":
                asm.xor_rax_rbx()
            return TYPE_INT

        elif isinstance(expr, FnCall):
            fn_name = expr.func.name if isinstance(expr.func, Identifier) else None
            if fn_name == "syscall":
                return self._compile_syscall(expr.args)
            return self._compile_call(expr)

        return TYPE_INT

    def _peek_type(self, node: Node) -> int:
        """Lightweight type peek for binary operations."""
        if isinstance(node, String):
            return TYPE_STR
        if isinstance(node, Identifier):
            return self.local_types.get(node.name, TYPE_INT)
        if isinstance(node, FnCall) and isinstance(node.func, Identifier):
            return self.fn_return_types.get(node.func.name, TYPE_INT)
        return TYPE_INT

    def _emit_data_section(self):
        """
        Emits constant strings and heap tracking variables in Pascal/C hybrid format:
          [8 bytes: Little-endian uint64 length]
          [N bytes: UTF-8 string content]
          [1 byte: Null terminator \0]
        """
        asm = self.asm

        # Align to 8 bytes
        rem = len(asm.code) % 8
        if rem != 0:
            asm.emit(b"\x00" * (8 - rem))

        # WHY: Bounds markers for _lipi_print_dynamic to recognize valid string constants
        asm.define_label("_lipi_data_start")

        # Heap state variables
        asm.define_label(self.heap_base_lbl)
        asm.emit(b"\x00\x00\x00\x00\x00\x00\x00\x00")
        asm.define_label(self.heap_ptr_lbl)
        asm.emit(b"\x00\x00\x00\x00\x00\x00\x00\x00")

        # String Pool
        for text, lbl in self.string_pool.items():
            encoded = text.encode("utf-8")
            # 8-byte length prefix
            len_bytes = struct.pack("<Q", len(encoded))
            asm.emit(len_bytes)
            # String pointer starts here!
            asm.define_label(lbl)
            asm.emit(encoded + b"\x00")

        asm.define_label("_lipi_data_end")

    def _wrap_elf(self, code_bytes: bytes) -> bytes:
        """
        Builds the complete ELF64 executable image.
        Header: 64 bytes
        Program Header: 56 bytes (PT_LOAD)
        Code & Data: Starts at file offset 120 (0x78)
        Total binary: Exactly 120 + len(code_bytes).
        """
        ELF_BASE = 0x400000
        CODE_OFFSET = 120
        ENTRY_VADDR = ELF_BASE + CODE_OFFSET

        total_file_size = CODE_OFFSET + len(code_bytes)

        # 1. ELF Header (64 bytes)
        elf_header = struct.pack(
            "<16sHHIQQQIHHHHHH",
            b"\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00",
            2,            # ET_EXEC
            0x3E,         # EM_X86_64
            1,            # EV_CURRENT
            ENTRY_VADDR,  # e_entry
            64,           # e_phoff
            0,            # e_shoff (no section headers needed!)
            0,            # e_flags
            64,           # e_ehsize
            56,           # e_phentsize
            1,            # e_phnum (1 loadable segment)
            0,            # e_shentsize
            0,            # e_shnum
            0             # e_shstrndx
        )

        # 2. Program Header Table (56 bytes, PT_LOAD)
        # PF_R (4) | PF_W (2) | PF_X (1) = 7 (Read, Write, Execute)
        prog_header = struct.pack(
            "<IIQQQQQQ",
            1,                # p_type: PT_LOAD
            7,                # p_flags: PF_R | PF_W | PF_X
            0,                # p_offset: from start of file
            ELF_BASE,         # p_vaddr: 0x400000
            ELF_BASE,         # p_paddr
            total_file_size,  # p_filesz
            total_file_size,  # p_memsz
            0x1000            # p_align: 4KB page alignment
        )

        return elf_header + prog_header + code_bytes


def compile_file_to_elf(src_path: str, out_path: str) -> None:
    """
    Main driver: Reads a Lipi source file and generates a standalone
    x86_64 ELF binary on disk without calling GCC or any external tool.
    """
    from src.runtime.lexer import Lexer
    from src.runtime.parser import Parser

    with open(src_path, "r", encoding="utf-8") as f:
        source = f.read()

    lexer = Lexer(source, src_path)
    tokens = lexer.tokenize()
    parser = Parser(tokens)
    ast = parser.parse()

    compiler = LipiElfCompiler()
    elf_bytes = compiler.compile(ast)

    with open(out_path, "wb") as f:
        f.write(elf_bytes)

    os.chmod(out_path, 0o755)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 -m src.compiler.elf_emitter input.lp output_elf")
        sys.exit(1)
    compile_file_to_elf(sys.argv[1], sys.argv[2])
