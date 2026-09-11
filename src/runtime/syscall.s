# ============================================================================
# Pure Maya Freestanding Linux x86-64 Kernel Syscall Gateway & Runtime Engine
# Architecture: x86_64 Linux Direct Kernel Gateway (Zero C/C++, Zero Libc)
# File: runtime/syscall.s
# ============================================================================

.intel_syntax noprefix
.text

# ----------------------------------------------------------------------------
# 1. Raw Linux Syscall Gateway (0 - 6 Args)
# ----------------------------------------------------------------------------
.global syscall0
.type syscall0, @function
syscall0:
    mov rax, rdi
    syscall
    ret

.global syscall1
.type syscall1, @function
syscall1:
    mov rax, rdi
    mov rdi, rsi
    syscall
    ret

.global syscall2
.type syscall2, @function
syscall2:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    syscall
    ret

.global syscall3
.type syscall3, @function
syscall3:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    syscall
    ret

.global syscall4
.type syscall4, @function
syscall4:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov r10, r8
    syscall
    ret

.global syscall5
.type syscall5, @function
syscall5:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov r10, r8
    mov r8, r9
    syscall
    ret

.global syscall6
.global raw_syscall
.global syscall
.global maya_syscall
.type syscall6, @function
.type raw_syscall, @function
.type syscall, @function
.type maya_syscall, @function
syscall6:
raw_syscall:
syscall:
maya_syscall:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov r10, r8
    mov r8, r9
    mov r9, [rsp + 8]

    cmp rax, 2
    je .Lsys_unbox_rdi
    cmp rax, 87
    je .Lsys_unbox_rdi
    cmp rax, 83
    je .Lsys_unbox_rdi
    cmp rax, 84
    je .Lsys_unbox_rdi
    cmp rax, 80
    je .Lsys_unbox_rdi
    cmp rax, 21
    je .Lsys_unbox_rdi
    cmp rax, 4
    je .Lsys_unbox_rdi
    cmp rax, 6
    je .Lsys_unbox_rdi
    cmp rax, 90
    je .Lsys_unbox_rdi
    cmp rax, 59
    je .Lsys_unbox_rdi
    cmp rax, 1
    je .Lsys_unbox_rsi
    jmp .Lsys_exec_raw

.Lsys_unbox_rdi:
    test rdi, rdi
    jz .Lsys_exec_raw
    test rdi, 7
    jnz .Lsys_exec_raw
    cmp qword ptr [rip + g_heap_start], 0
    je .Lsys_exec_raw
    cmp rdi, [rip + g_heap_start]
    jb .Lsys_exec_raw
    cmp rdi, [rip + g_heap_curr]
    jae .Lsys_exec_raw
    cmp qword ptr [rdi - 8], 1
    jne .Lsys_exec_raw
    mov rdi, [rdi + 8]
    jmp .Lsys_exec_raw

.Lsys_unbox_rsi:
    test rsi, rsi
    jz .Lsys_exec_raw
    test rsi, 7
    jnz .Lsys_exec_raw
    cmp qword ptr [rip + g_heap_start], 0
    je .Lsys_exec_raw
    cmp rsi, [rip + g_heap_start]
    jb .Lsys_exec_raw
    cmp rsi, [rip + g_heap_curr]
    jae .Lsys_exec_raw
    cmp qword ptr [rsi - 8], 1
    jne .Lsys_exec_raw
    mov rsi, [rsi + 8]

.Lsys_exec_raw:
    syscall
    ret

.global maya_clone_wrapper
.type maya_clone_wrapper, @function
maya_clone_wrapper:
    sub rsi, 16
    mov [rsi + 8], rcx
    mov [rsi + 0], rdx
    mov rdx, 0
    mov r10, 0
    mov r8, 0
    mov rax, 56
    syscall
    test rax, rax
    jnz .Lparent
    pop r8
    pop rdi
    call r8
    mov rdi, rax
    mov rax, 60
    syscall
.Lparent:
    ret

.global maya_atomic_add
.type maya_atomic_add, @function
maya_atomic_add:
    lock add [rdi], rsi
    mov rax, [rdi]
    ret

.global maya_get_rsp
.type maya_get_rsp, @function
maya_get_rsp:
    mov rax, rsp
    ret

.global maya_get_rbp
.type maya_get_rbp, @function
maya_get_rbp:
    mov rax, rbp
    ret

.global maya_flush_regs_and_get_rsp
.type maya_flush_regs_and_get_rsp, @function
maya_flush_regs_and_get_rsp:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov rax, rsp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

.global maya_stack_scan_helper
.type maya_stack_scan_helper, @function
maya_stack_scan_helper:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    mov r12, rdi
    and r12, -8
    mov r13, rsi
    mov r14, rdx
    xor r15, r15
.Lscan_loop:
    cmp r12, r13
    jae .Lscan_done
    mov rdi, [r12]
    test rdi, rdi
    jz .Lscan_next
    test r14, r14
    jz .Lscan_count
    sub rsp, 8
    call r14
    add rsp, 8
.Lscan_count:
    inc r15
.Lscan_next:
    add r12, 8
    jmp .Lscan_loop
.Lscan_done:
    mov rax, r15
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

# ----------------------------------------------------------------------------
# 2. Memory & Allocator Subsystem
# ----------------------------------------------------------------------------
.section .data,"aw",@progbits
.align 8
g_heap_start: .quad 0
g_heap_curr:  .quad 0
g_heap_end:   .quad 0
g_free_list:  .quad 0
g_argc:       .quad 0
g_argv:       .quad 0
g_envp:       .quad 0


.text
.global maya_runtime_init
.global maya_init_gc
.type maya_runtime_init, @function
.type maya_init_gc, @function
maya_runtime_init:
maya_init_gc:
    cmp qword ptr [rip + g_heap_start], 0
    jne .Lgc_init_done
    mov rax, 9 # sys_mmap
    xor rdi, rdi
    mov rsi, 134217728 # 128MB
    mov rdx, 3         # PROT_READ|PROT_WRITE
    mov r10, 34        # MAP_PRIVATE|MAP_ANONYMOUS
    mov r8, -1
    xor r9, r9
    syscall
    mov [rip + g_heap_start], rax
    mov [rip + g_heap_curr], rax
    add rax, 134217728
    mov [rip + g_heap_end], rax
.Lgc_init_done:
    ret

.global maya_alloc
.weak maya_gc_alloc
.type maya_alloc, @function
.type maya_gc_alloc, @function
maya_alloc:
maya_gc_alloc:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8 # align stack
    mov r12, rdi
    call maya_runtime_init
    test r12, r12
    jg .Lalloc_pos
    mov r12, 1
.Lalloc_pos:
    add r12, 31
    and r12, -16
    # 1. Check free list for reusable block
    mov rax, [rip + g_free_list]
    test rax, rax
    jz .Lalloc_from_bump
    mov rcx, [rax - 16] # block size
    cmp rcx, r12
    jb .Lalloc_from_bump
    # Pop head of free list
    mov rdx, [rax]
    mov [rip + g_free_list], rdx
    mov qword ptr [rax - 8], 0 # clear freed marker
    add rsp, 8
    pop r12
    pop rbp
    ret
.Lalloc_from_bump:
    mov rax, [rip + g_heap_curr]
    mov rdx, rax
    add rdx, r12
    cmp rdx, [rip + g_heap_end]
    ja .Lalloc_new_chunk
    mov [rip + g_heap_curr], rdx
    mov [rax], r12
    mov qword ptr [rax + 8], 0
    add rax, 16
    add rsp, 8
    pop r12
    pop rbp
    ret
.Lalloc_new_chunk:
    mov rax, 9
    xor rdi, rdi
    mov rsi, 67108864
    mov rdx, 3
    mov r10, 34
    mov r8, -1
    xor r9, r9
    syscall
    mov [rip + g_heap_start], rax
    mov [rip + g_heap_curr], rax
    add rax, 67108864
    mov [rip + g_heap_end], rax
    mov rax, [rip + g_heap_curr]
    mov rdx, rax
    add rdx, r12
    mov [rip + g_heap_curr], rdx
    mov [rax], r12
    mov qword ptr [rax + 8], 0
    add rax, 16
    add rsp, 8
    pop r12
    pop rbp
    ret

.global maya_alloc_typed
.type maya_alloc_typed, @function
maya_alloc_typed:
    push rbp
    mov rbp, rsp
    push rsi
    sub rsp, 8
    call maya_alloc
    add rsp, 8
    pop rsi
    mov [rax - 8], rsi
    pop rbp
    ret

.global maya_free
.type maya_free, @function
maya_free:
    test rdi, rdi
    jz .Lfree_ret
    # Check if pointer is within heap range
    cmp rdi, [rip + g_heap_start]
    jb .Lfree_ret
    cmp rdi, [rip + g_heap_end]
    jae .Lfree_ret
    # Mark header with freed signature
    mov qword ptr [rdi - 8], 0xDEADBEEF
    # Push onto g_free_list
    mov rax, [rip + g_free_list]
    mov [rdi], rax
    mov [rip + g_free_list], rdi
.Lfree_ret:
    ret

.global maya_realloc
.type maya_realloc, @function
maya_realloc:
    test rdi, rdi
    jnz .Lrealloc_do
    mov rdi, rsi
    jmp maya_alloc
.Lrealloc_do:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov rdi, r13
    call maya_alloc
    mov rbx, rax
    mov rcx, [r12 - 16]
    sub rcx, 16
    cmp rcx, r13
    jle .Lrealloc_copy
    mov rcx, r13
.Lrealloc_copy:
    mov rsi, r12
    mov rdi, rbx
    rep movsb
    mov rax, rbx
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

# ----------------------------------------------------------------------------
# 3. Type Introspection & GC Bridges
# ----------------------------------------------------------------------------
.global is_maya_string_ptr
.type is_maya_string_ptr, @function
is_maya_string_ptr:
    test rdi, rdi
    jz .Lisp_no
    test rdi, 7
    jnz .Lisp_no
    cmp qword ptr [rip + g_heap_start], 0
    je .Lisp_no
    cmp rdi, [rip + g_heap_start]
    jb .Lisp_no
    cmp rdi, [rip + g_heap_curr]
    jae .Lisp_no
    cmp qword ptr [rdi - 8], 1
    je .Lisp_yes
    mov rax, [rdi]
    cmp rax, 0
    jl .Lisp_no
    cmp rax, 100000000
    jge .Lisp_no
    mov rdx, [rdi + 8]
    cmp rdx, 4096
    jb .Lisp_no
.Lisp_yes:
    mov rax, 1
    ret
.Lisp_no:
    xor rax, rax
    ret

.global is_maya_array_ptr
.type is_maya_array_ptr, @function
is_maya_array_ptr:
    test rdi, rdi
    jz .Lipa_no
    test rdi, 7
    jnz .Lipa_no
    cmp qword ptr [rip + g_heap_start], 0
    je .Lipa_no
    cmp rdi, [rip + g_heap_start]
    jb .Lipa_no
    cmp rdi, [rip + g_heap_curr]
    jae .Lipa_no
    cmp qword ptr [rdi - 8], 2
    je .Lipa_yes
.Lipa_no:
    xor rax, rax
    ret
.Lipa_yes:
    mov rax, 1
    ret

.global is_maya_map_ptr
.type is_maya_map_ptr, @function
is_maya_map_ptr:
    test rdi, rdi
    jz .Lipm_no
    test rdi, 7
    jnz .Lipm_no
    cmp qword ptr [rip + g_heap_start], 0
    je .Lipm_no
    cmp rdi, [rip + g_heap_start]
    jb .Lipm_no
    cmp rdi, [rip + g_heap_curr]
    jae .Lipm_no
    cmp qword ptr [rdi - 8], 3
    je .Lipm_yes
.Lipm_no:
    xor rax, rax
    ret
.Lipm_yes:
    mov rax, 1
    ret

.weak gc_alloc
.weak gc_free
.weak gc_realloc
.weak gc_init
.weak gc_base
.weak gc_get_type_id
.weak gc_alloc_typed
.type gc_alloc, @function
.type gc_free, @function
.type gc_realloc, @function
.type gc_init, @function
.type gc_base, @function
.type gc_get_type_id, @function
.type gc_alloc_typed, @function
gc_alloc:
    jmp maya_alloc
gc_free:
    jmp maya_free
gc_realloc:
    jmp maya_realloc
gc_init:
    jmp maya_init_gc
gc_base:
    mov rax, rdi
    ret
gc_get_type_id:
    test rdi, rdi
    jz .Ltid_zero
    mov rax, [rdi - 8]
    ret
.Ltid_zero:
    xor rax, rax
    ret
gc_alloc_typed:
    jmp maya_alloc_typed
.weak gc_collect
.type gc_collect, @function
gc_collect:
    xor rax, rax
    ret

.global maya_str_ptr
.global str_ptr
.type maya_str_ptr, @function
.type str_ptr, @function
maya_str_ptr:
str_ptr:
    test rdi, rdi
    jz .Lstrp_done
    test rdi, 7
    jnz .Lstrp_raw
    mov rax, [rdi]
    cmp rax, 0
    jl .Lstrp_raw
    cmp rax, 100000000
    jge .Lstrp_raw
    mov rdx, [rdi + 8]
    cmp rdx, 4096
    jb .Lstrp_raw
    mov rax, rdx
    ret
.Lstrp_raw:
    mov rax, rdi
    ret
.Lstrp_done:
    xor rax, rax
    ret


# ----------------------------------------------------------------------------
# 4. String Operations
# ----------------------------------------------------------------------------

.global maya_str_new
.type maya_str_new, @function
maya_str_new:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    xor r13, r13
    test r12, r12
    jz .Lstr_alloc
.Lstr_scan:
    cmp byte ptr [r12 + r13], 0
    je .Lstr_alloc
    inc r13
    cmp r13, 1048576
    ja .Lstr_alloc
    jmp .Lstr_scan
.Lstr_alloc:
    mov rdi, r13
    add rdi, 17
    mov rsi, 1
    call maya_alloc_typed
    mov [rax], r13
    mov rdx, rax
    add rdx, 16
    mov [rax + 8], rdx
    test r13, r13
    jz .Lstr_term
    mov rdi, rdx
    mov rsi, r12
    mov rcx, r13
    rep movsb
.Lstr_term:
    mov rdx, [rax + 8]
    mov byte ptr [rdx + r13], 0
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_str_from_raw
.type maya_str_from_raw, @function
maya_str_from_raw:
    mov rsi, -1
    jmp maya_str_new

.global maya_str_len
.type maya_str_len, @function
maya_str_len:
    test rdi, rdi
    jz .Lstr_len_zero
    mov rax, [rdi]
    ret
.Lstr_len_zero:
    xor rax, rax
    ret

.global maya_str_len_ms
.type maya_str_len_ms, @function
maya_str_len_ms:
    jmp maya_str_len


.global maya_str_concat
.type maya_str_concat, @function
maya_str_concat:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi

    # Ensure r12 is a MayaString
    test r12, r12
    jz .Lsc_make1_empty
    mov rdi, r12
    call is_maya_string_ptr
    test rax, rax
    jnz .Lsc_check2
    mov rdi, r12
    call maya_str_new
    mov r12, rax
    jmp .Lsc_check2
.Lsc_make1_empty:
    xor rdi, rdi
    call maya_str_new
    mov r12, rax

.Lsc_check2:
    # Ensure r13 is a MayaString
    test r13, r13
    jz .Lsc_make2_empty
    mov rdi, r13
    call is_maya_string_ptr
    test rax, rax
    jnz .Lsc_ready
    mov rdi, r13
    call maya_str_new
    mov r13, rax
    jmp .Lsc_ready
.Lsc_make2_empty:
    xor rdi, rdi
    call maya_str_new
    mov r13, rax

.Lsc_ready:
    mov r14, [r12] # len1
    mov r15, [r13] # len2
    mov rdi, r14
    add rdi, r15
    add rdi, 17
    mov rsi, 1 # TYPE_MAYA_STRING
    call maya_alloc_typed
    mov rbx, rax # result

    mov rdx, r14
    add rdx, r15
    mov [rbx], rdx
    mov rdx, rbx
    add rdx, 16
    mov [rbx + 8], rdx

    test r14, r14
    jz .Lsc_copy2
    mov rdi, rdx
    mov rsi, [r12 + 8]
    mov rcx, r14
    rep movsb

.Lsc_copy2:
    test r15, r15
    jz .Lsc_done
    mov rdi, [rbx + 8]
    add rdi, r14
    mov rsi, [r13 + 8]
    mov rcx, r15
    rep movsb

.Lsc_done:
    mov rdx, [rbx + 8]
    mov rcx, [rbx]
    mov byte ptr [rdx + rcx], 0
    mov rax, rbx
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_str_eq
.type maya_str_eq, @function
maya_str_eq:
    cmp rdi, rsi
    je .Lseq_true
    test rdi, rdi
    jz .Lseq_false
    test rsi, rsi
    jz .Lseq_false
    mov rcx, [rdi]
    cmp rcx, [rsi]
    jne .Lseq_false
    test rcx, rcx
    jz .Lseq_true
    mov rdi, [rdi + 8]
    mov rsi, [rsi + 8]
.Lseq_loop:
    mov al, [rdi]
    mov dl, [rsi]
    cmp al, dl
    jne .Lseq_false
    inc rdi
    inc rsi
    dec rcx
    jnz .Lseq_loop
.Lseq_true:
    mov rax, 1
    ret
.Lseq_false:
    xor rax, rax
    ret

.global maya_str_char_at
.type maya_str_char_at, @function
maya_str_char_at:
    test rdi, rdi
    jz .Lsca_zero
    cmp rsi, 0
    jl .Lsca_zero
    cmp rsi, [rdi]
    jge .Lsca_zero
    mov rax, [rdi + 8]
    movzx rax, byte ptr [rax + rsi]
    ret
.Lsca_zero:
    xor rax, rax
    ret

.global maya_str_substr
.type maya_str_substr, @function
maya_str_substr:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    test r12, r12
    jz .Lsub_empty
    mov rcx, [r12]
    cmp r13, rcx
    jge .Lsub_empty
    cmp r13, 0
    jge .Lsub_start_ok
    xor r13, r13
.Lsub_start_ok:
    mov rax, r13
    add rax, r14
    cmp rax, rcx
    jle .Lsub_len_ok
    mov r14, rcx
    sub r14, r13
.Lsub_len_ok:
    cmp r14, 0
    jle .Lsub_empty
    mov rdi, [r12 + 8]
    add rdi, r13
    mov rsi, r14
    call maya_str_new
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.Lsub_empty:
    xor rdi, rdi
    xor rsi, rsi
    call maya_str_new
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.global maya_str_from_char_code
.type maya_str_from_char_code, @function
maya_str_from_char_code:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov byte ptr [rsp], dil
    mov byte ptr [rsp + 1], 0
    mov rdi, rsp
    mov rsi, 1
    call maya_str_new
    leave
    ret

.global maya_str_to_upper
.type maya_str_to_upper, @function
maya_str_to_upper:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    mov r12, rdi
    test r12, r12
    jz .Lupper_null
    mov rdi, [r12 + 8]
    mov rsi, [r12]
    call maya_str_new
    mov r13, rax
    mov rcx, [r13]
    mov rdx, [r13 + 8]
.Lupper_loop:
    test rcx, rcx
    jz .Lupper_done
    mov al, [rdx]
    cmp al, 97
    jb .Lupper_next
    cmp al, 122
    ja .Lupper_next
    sub al, 32
    mov [rdx], al
.Lupper_next:
    inc rdx
    dec rcx
    jmp .Lupper_loop
.Lupper_done:
    mov rax, r13
    pop r13
    pop r12
    pop rbp
    ret
.Lupper_null:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret

.global maya_str_to_lower
.type maya_str_to_lower, @function
maya_str_to_lower:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    mov r12, rdi
    test r12, r12
    jz .Llower_null
    mov rdi, [r12 + 8]
    mov rsi, [r12]
    call maya_str_new
    mov r13, rax
    mov rcx, [r13]
    mov rdx, [r13 + 8]
.Llower_loop:
    test rcx, rcx
    jz .Llower_done
    mov al, [rdx]
    cmp al, 65
    jb .Llower_next
    cmp al, 90
    ja .Llower_next
    add al, 32
    mov [rdx], al
.Llower_next:
    inc rdx
    dec rcx
    jmp .Llower_loop
.Llower_done:
    mov rax, r13
    pop r13
    pop r12
    pop rbp
    ret
.Llower_null:
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret

.global maya_str_trim
.type maya_str_trim, @function
maya_str_trim:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    sub rsp, 8
    mov r12, rdi
    test r12, r12
    jz .Ltrim_null
    mov rcx, [r12]
    test rcx, rcx
    jz .Ltrim_null
    mov rsi, [r12 + 8]
    xor r13, r13
.Ltrim_start_loop:
    cmp r13, rcx
    jge .Ltrim_empty
    mov al, [rsi + r13]
    cmp al, 32
    je .Ltrim_start_inc
    cmp al, 9
    je .Ltrim_start_inc
    cmp al, 10
    je .Ltrim_start_inc
    cmp al, 13
    je .Ltrim_start_inc
    jmp .Ltrim_start_done
.Ltrim_start_inc:
    inc r13
    jmp .Ltrim_start_loop
.Ltrim_start_done:
    mov r14, rcx
.Ltrim_end_loop:
    cmp r14, r13
    jle .Ltrim_empty
    mov al, [rsi + r14 - 1]
    cmp al, 32
    je .Ltrim_end_dec
    cmp al, 9
    je .Ltrim_end_dec
    cmp al, 10
    je .Ltrim_end_dec
    cmp al, 13
    je .Ltrim_end_dec
    jmp .Ltrim_end_done
.Ltrim_end_dec:
    dec r14
    jmp .Ltrim_end_loop
.Ltrim_end_done:
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    sub rdx, r13
    call maya_str_substr
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.Ltrim_empty:
.Ltrim_null:
    xor rdi, rdi
    xor rsi, rsi
    call maya_str_new
    add rsp, 8
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.global maya_str_replace
.type maya_str_replace, @function
maya_str_replace:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    test r12, r12
    jz .Lrep_ret_empty
    test r13, r13
    jz .Lrep_ret_s
    cmp qword ptr [r13], 0
    je .Lrep_ret_s
    mov rdi, [r12]
    shl rdi, 2
    add rdi, 4096
    mov rsi, 1
    call maya_alloc_typed
    mov r15, rax
    mov rbx, rax
    add rbx, 16
    mov [r15 + 8], rbx
    xor r8, r8
    xor r9, r9
    mov r10, [r12]
    mov r11, [r13]
.Lrep_scan:
    cmp r9, r10
    jge .Lrep_finish
    mov rax, r10
    sub rax, r9
    cmp rax, r11
    jl .Lrep_copy_one
    mov rsi, [r12 + 8]
    add rsi, r9
    mov rdi, [r13 + 8]
    mov rcx, r11
    push rsi
    push rdi
    repe cmpsb
    pop rdi
    pop rsi
    jne .Lrep_copy_one
    test r14, r14
    jz .Lrep_skip_tgt
    mov rdx, [r14]
    test rdx, rdx
    jz .Lrep_skip_tgt
    mov rsi, [r14 + 8]
    mov rdi, rbx
    add rdi, r8
    mov rcx, rdx
    rep movsb
    add r8, rdx
.Lrep_skip_tgt:
    add r9, r11
    jmp .Lrep_scan
.Lrep_copy_one:
    mov rsi, [r12 + 8]
    mov al, [rsi + r9]
    mov [rbx + r8], al
    inc r8
    inc r9
    jmp .Lrep_scan
.Lrep_finish:
    mov [r15], r8
    mov byte ptr [rbx + r8], 0
    mov rax, r15
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.Lrep_ret_s:
    mov rax, r12
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.Lrep_ret_empty:
    xor rdi, rdi
    xor rsi, rsi
    call maya_str_new
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_str_starts_with
.type maya_str_starts_with, @function
maya_str_starts_with:
    test rdi, rdi
    jz .Lsw_no
    test rsi, rsi
    jz .Lsw_yes
    mov rcx, [rsi]
    cmp rcx, [rdi]
    ja .Lsw_no
    mov rdi, [rdi + 8]
    mov rsi, [rsi + 8]
    repe cmpsb
    je .Lsw_yes
.Lsw_no:
    xor rax, rax
    ret
.Lsw_yes:
    mov rax, 1
    ret

.global maya_str_ends_with
.type maya_str_ends_with, @function
maya_str_ends_with:
    test rdi, rdi
    jz .Lew_no
    test rsi, rsi
    jz .Lew_yes
    mov rdx, [rsi]
    mov rcx, [rdi]
    cmp rdx, rcx
    ja .Lew_no
    mov rdi, [rdi + 8]
    add rdi, rcx
    sub rdi, rdx
    mov rsi, [rsi + 8]
    mov rcx, rdx
    repe cmpsb
    je .Lew_yes
.Lew_no:
    xor rax, rax
    ret
.Lew_yes:
    mov rax, 1
    ret


.global maya_str_contains
.type maya_str_contains, @function
maya_str_contains:
    push rbp
    mov rbp, rsp
    call maya_str_index_of
    cmp rax, 0
    jge .Lsc_found
    xor rax, rax
    pop rbp
    ret
.Lsc_found:
    mov rax, 1
    pop rbp
    ret

.global maya_str_index_of
.type maya_str_index_of, @function
maya_str_index_of:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi

    test r12, r12
    jz .Lio_not_found
    mov rdi, r12
    call is_maya_string_ptr
    test rax, rax
    jnz .Lio_have1
    mov rdi, r12
    call maya_str_new
    mov r12, rax
.Lio_have1:

    test r13, r13
    jz .Lio_found_0
    mov rdi, r13
    call is_maya_string_ptr
    test rax, rax
    jnz .Lio_have2
    mov rdi, r13
    call maya_str_new
    mov r13, rax
.Lio_have2:

    mov r14, [r12]
    mov r15, [r13]
    test r15, r15
    jz .Lio_found_0
    cmp r15, r14
    ja .Lio_not_found

    mov rbx, r14
    sub rbx, r15
    xor r11, r11

.Lio_loop:
    cmp r11, rbx
    jg .Lio_not_found
    mov rsi, [r12 + 8]
    add rsi, r11
    mov rdi, [r13 + 8]
    mov rcx, r15
    push r11
    push rsi
    push rdi
    repe cmpsb
    pop rdi
    pop rsi
    pop r11
    je .Lio_found
    inc r11
    jmp .Lio_loop

.Lio_found:
    mov rax, r11
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.Lio_found_0:
    xor rax, rax
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.Lio_not_found:
    mov rax, -1
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_int_to_str
.type maya_int_to_str, @function
maya_int_to_str:
    push rbp
    mov rbp, rsp
    sub rsp, 48
    mov rax, rdi
    lea rsi, [rsp + 40]
    mov byte ptr [rsi + 1], 0
    mov r8, 0
    test rax, rax
    jns .Lits_pos
    neg rax
    mov r8, 1
.Lits_pos:
    mov r9, 10
.Lits_loop:
    xor rdx, rdx
    div r9
    add dl, 48
    mov [rsi], dl
    dec rsi
    test rax, rax
    jnz .Lits_loop
    test r8, r8
    jz .Lits_done
    mov byte ptr [rsi], 45
    dec rsi
.Lits_done:
    inc rsi
    lea rdx, [rsp + 41]
    sub rdx, rsi
    mov rdi, rsi
    mov rsi, rdx
    call maya_str_new
    leave
    ret

.global maya_bool_to_str
.type maya_bool_to_str, @function
maya_bool_to_str:
    test rdi, rdi
    jnz .Lbts_true
    lea rdi, [rip + str_false]
    mov rsi, 5
    jmp maya_str_new
.Lbts_true:
    lea rdi, [rip + str_true]
    mov rsi, 4
    jmp maya_str_new

.global maya_float_to_str
.type maya_float_to_str, @function
maya_float_to_str:
    jmp maya_int_to_str

.global maya_str_to_int
.type maya_str_to_int, @function
maya_str_to_int:
    test rdi, rdi
    jz .Lsti_zero
    mov rcx, [rdi]
    test rcx, rcx
    jz .Lsti_zero
    mov rsi, [rdi + 8]
    xor rax, rax
    xor r8, r8
    xor rdx, rdx
    mov dl, [rsi]
    cmp dl, 45
    jne .Lsti_loop
    mov r8, 1
    inc rsi
    dec rcx
.Lsti_loop:
    test rcx, rcx
    jz .Lsti_done
    movzx rdx, byte ptr [rsi]
    cmp rdx, 48
    jb .Lsti_done
    cmp rdx, 57
    ja .Lsti_done
    sub rdx, 48
    imul rax, 10
    add rax, rdx
    inc rsi
    dec rcx
    jmp .Lsti_loop
.Lsti_done:
    test r8, r8
    jz .Lsti_ret
    neg rax
.Lsti_ret:
    ret
.Lsti_zero:
    xor rax, rax
    ret

.global maya_str_to_float
.type maya_str_to_float, @function
maya_str_to_float:
    jmp maya_str_to_int

# ----------------------------------------------------------------------------
# 5. Dynamic Operations Dispatcher
# ----------------------------------------------------------------------------
.global maya_dynamic_to_str
.type maya_dynamic_to_str, @function
maya_dynamic_to_str:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8
    mov r12, rdi
    mov rdi, r12
    call is_maya_string_ptr
    test rax, rax
    jnz .Ldts_is_str
    mov rdi, r12
    call maya_int_to_str
    add rsp, 8
    pop r12
    pop rbp
    ret
.Ldts_is_str:
    mov rax, r12
    add rsp, 8
    pop r12
    pop rbp
    ret

.global maya_dynamic_add
.type maya_dynamic_add, @function
maya_dynamic_add:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    mov rdi, r12
    call is_maya_string_ptr
    test rax, rax
    jnz .Ldadd_str
    mov rdi, r13
    call is_maya_string_ptr
    test rax, rax
    jnz .Ldadd_str
    mov rax, r12
    add rax, r13
    pop r13
    pop r12
    pop rbp
    ret
.Ldadd_str:
    mov rdi, r12
    call maya_dynamic_to_str
    mov r12, rax
    mov rdi, r13
    call maya_dynamic_to_str
    mov r13, rax
    mov rdi, r12
    mov rsi, r13
    call maya_str_concat
    pop r13
    pop r12
    pop rbp
    ret

.global maya_dynamic_eq
.type maya_dynamic_eq, @function
maya_dynamic_eq:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    cmp r12, r13
    je .Ldeq_true
    mov rdi, r12
    call is_maya_string_ptr
    test rax, rax
    jz .Ldeq_int
    mov rdi, r13
    call is_maya_string_ptr
    test rax, rax
    jz .Ldeq_int
    mov rdi, r12
    mov rsi, r13
    call maya_str_eq
    pop r13
    pop r12
    pop rbp
    ret
.Ldeq_int:
    cmp r12, r13
    je .Ldeq_true
    xor rax, rax
    pop r13
    pop r12
    pop rbp
    ret
.Ldeq_true:
    mov rax, 1
    pop r13
    pop r12
    pop rbp
    ret

.global maya_dynamic_ne
.type maya_dynamic_ne, @function
maya_dynamic_ne:
    push rbp
    mov rbp, rsp
    call maya_dynamic_eq
    xor rax, 1
    pop rbp
    ret

# ----------------------------------------------------------------------------
# 6. Standard I/O via Linux Raw Syscalls
# ----------------------------------------------------------------------------
.global maya_print_str
.type maya_print_str, @function
maya_print_str:
    test rdi, rdi
    jz .Lpstr_done
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8
    mov r12, rdi
    xor rdx, rdx
.Lpstr_len:
    cmp byte ptr [r12 + rdx], 0
    je .Lpstr_write
    inc rdx
    cmp rdx, 1048576
    ja .Lpstr_write
    jmp .Lpstr_len
.Lpstr_write:
    test rdx, rdx
    jz .Lpstr_epilogue
    mov rax, 1
    mov rsi, r12
    mov rdi, 1
    syscall
.Lpstr_epilogue:
    add rsp, 8
    pop r12
    pop rbp
.Lpstr_done:
    xor rax, rax
    ret

.global maya_println_str
.type maya_println_str, @function
maya_println_str:
    push rbp
    mov rbp, rsp
    call maya_print_str
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + str_newline]
    mov rdx, 1
    syscall
    leave
    xor rax, rax
    ret

.global maya_print_mayastr
.type maya_print_mayastr, @function
maya_print_mayastr:
    test rdi, rdi
    jz .Lpms_done
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8
    mov r12, rdi
    call is_maya_string_ptr
    test rax, rax
    jz .Lpms_fallback
    mov rdx, [r12]
    test rdx, rdx
    jz .Lpms_epilogue
    mov rsi, [r12 + 8]
    mov rax, 1
    mov rdi, 1
    syscall
    jmp .Lpms_epilogue
.Lpms_fallback:
    mov rdi, r12
    call maya_print_str
.Lpms_epilogue:
    add rsp, 8
    pop r12
    pop rbp
.Lpms_done:
    xor rax, rax
    ret

.global maya_println_mayastr
.type maya_println_mayastr, @function
maya_println_mayastr:
    push rbp
    mov rbp, rsp
    call maya_print_mayastr
    mov rax, 1
    mov rdi, 1
    lea rsi, [rip + str_newline]
    mov rdx, 1
    syscall
    leave
    xor rax, rax
    ret

.global maya_print_i64
.type maya_print_i64, @function
maya_print_i64:
    push rbp
    mov rbp, rsp
    call maya_int_to_str
    mov rdi, rax
    call maya_print_mayastr
    pop rbp
    ret

.global maya_println_i64
.type maya_println_i64, @function
maya_println_i64:
    push rbp
    mov rbp, rsp
    call maya_int_to_str
    mov rdi, rax
    call maya_println_mayastr
    pop rbp
    ret

.global maya_print_bool
.type maya_print_bool, @function
maya_print_bool:
    push rbp
    mov rbp, rsp
    call maya_bool_to_str
    mov rdi, rax
    call maya_print_mayastr
    pop rbp
    ret

.global maya_println_bool
.type maya_println_bool, @function
maya_println_bool:
    push rbp
    mov rbp, rsp
    call maya_bool_to_str
    mov rdi, rax
    call maya_println_mayastr
    pop rbp
    ret

.global maya_print_err
.type maya_print_err, @function
maya_print_err:
    test rdi, rdi
    jz .Lpe_ret
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 8
    mov r12, rdi
    call is_maya_string_ptr
    test rax, rax
    jz .Lpe_raw
    mov rdx, [r12]
    mov rsi, [r12 + 8]
    jmp .Lpe_write
.Lpe_raw:
    xor rdx, rdx
.Lpe_len:
    cmp byte ptr [r12 + rdx], 0
    je .Lpe_write
    inc rdx
    jmp .Lpe_len
.Lpe_write:
    test rdx, rdx
    jz .Lpe_done
    mov rax, 1
    mov rdi, 2
    syscall
.Lpe_done:
    add rsp, 8
    pop r12
    pop rbp
.Lpe_ret:
    xor rax, rax
    ret

.global maya_println_err
.type maya_println_err, @function
maya_println_err:
    push rbp
    mov rbp, rsp
    call maya_print_err
    mov rax, 1
    mov rdi, 2
    lea rsi, [rip + str_newline]
    mov rdx, 1
    syscall
    leave
    xor rax, rax
    ret

.global maya_print_f64
.type maya_print_f64, @function
maya_print_f64:
    jmp maya_print_i64

.global maya_println_f64
.type maya_println_f64, @function
maya_println_f64:
    jmp maya_println_i64

.global maya_println_array
.type maya_println_array, @function
maya_println_array:
    ret

.global maya_print_no_newline
.type maya_print_no_newline, @function
maya_print_no_newline:
    jmp maya_print_mayastr

.global maya_exit
.type maya_exit, @function
maya_exit:
    mov rax, 60
    syscall
    ret

.global maya_clock_ms
.type maya_clock_ms, @function
maya_clock_ms:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov rax, 228
    xor rdi, rdi
    mov rsi, rsp
    syscall
    mov rax, [rsp]
    imul rax, 1000
    mov rdx, [rsp + 8]
    mov r9, 1000000
    push rax
    mov rax, rdx
    xor rdx, rdx
    div r9
    pop rdx
    add rax, rdx
    leave
    ret

.global maya_file_read
.type maya_file_read, @function
maya_file_read:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    test rdi, rdi
    jz .Lfr_empty
    mov rsi, [rdi + 8]
    mov rax, 2
    mov rdi, rsi
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp rax, 0
    jl .Lfr_empty
    mov r12, rax
    mov rax, 8
    mov rdi, r12
    xor rsi, rsi
    mov rdx, 2
    syscall
    mov r13, rax
    mov rax, 8
    mov rdi, r12
    xor rsi, rsi
    xor rdx, rdx
    syscall
    cmp r13, 0
    jle .Lfr_close_empty
    mov rdi, r13
    add rdi, 17
    mov rsi, 1
    call maya_alloc_typed
    mov r14, rax
    mov [r14], r13
    mov rdx, r14
    add rdx, 16
    mov [r14 + 8], rdx
    mov rax, 0
    mov rdi, r12
    mov rsi, rdx
    mov rdx, r13
    syscall
    mov rax, 3
    mov rdi, r12
    syscall
    mov rdx, [r14 + 8]
    mov byte ptr [rdx + r13], 0
    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.Lfr_close_empty:
    mov rax, 3
    mov rdi, r12
    syscall
.Lfr_empty:
    xor rdi, rdi
    xor rsi, rsi
    call maya_str_new
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_file_write
.type maya_file_write, @function
maya_file_write:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .Lfw_err
    mov rdi, [r12 + 8]
    mov rax, 2
    mov rsi, 577
    mov rdx, 420
    syscall
    cmp rax, 0
    jl .Lfw_err
    mov rbx, rax
    test r13, r13
    jz .Lfw_close_ok
    mov rdx, [r13]
    test rdx, rdx
    jz .Lfw_close_ok
    mov rax, 1
    mov rdi, rbx
    mov rsi, [r13 + 8]
    syscall
.Lfw_close_ok:
    mov rax, 3
    mov rdi, rbx
    syscall
    mov rax, 1
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.Lfw_err:
    xor rax, rax
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_file_append
.type maya_file_append, @function
maya_file_append:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .Lfa_err
    mov rdi, [r12 + 8]
    mov rax, 2
    mov rsi, 1089
    mov rdx, 420
    syscall
    cmp rax, 0
    jl .Lfa_err
    mov rbx, rax
    test r13, r13
    jz .Lfa_close_ok
    mov rdx, [r13]
    test rdx, rdx
    jz .Lfa_close_ok
    mov rax, 1
    mov rdi, rbx
    mov rsi, [r13 + 8]
    syscall
.Lfa_close_ok:
    mov rax, 3
    mov rdi, rbx
    syscall
    mov rax, 1
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.Lfa_err:
    xor rax, rax
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_file_exists
.type maya_file_exists, @function
maya_file_exists:
    test rdi, rdi
    jz .Lfe_no
    mov rdi, [rdi + 8]
    mov rax, 21
    xor rsi, rsi
    syscall
    cmp rax, 0
    je .Lfe_yes
.Lfe_no:
    xor rax, rax
    ret
.Lfe_yes:
    mov rax, 1
    ret

.global maya_system
.type maya_system, @function
maya_system:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56

    test rdi, rdi
    mov r12, rdi
    test rdi, 7
    jnz .Lsys_raw_cmd
    mov rax, [rdi]
    cmp rax, 0
    jl .Lsys_raw_cmd
    cmp rax, 100000000
    jge .Lsys_raw_cmd
    mov rdx, [rdi + 8]
    cmp rdx, 4096
    jb .Lsys_raw_cmd
    mov r12, rdx
.Lsys_raw_cmd:
    mov rax, 57
    syscall
    test rax, rax
    js .Lsys_err
    jz .Lsys_child

    mov rdi, rax
    lea rsi, [rsp + 16]
    xor rdx, rdx
    xor r10, r10
    mov rax, 61
    syscall

    mov eax, [rsp + 16]
    shr eax, 8
    and eax, 0xff
    jmp .Lsys_done

.Lsys_child:
    # Direct sovereign execution: argv = [r12, NULL]
    mov [rsp + 16], r12
    mov qword ptr [rsp + 24], 0

    mov rdi, r12        # path
    lea rsi, [rsp + 16] # argv
    mov rdx, [rip + g_envp]
    test rdx, rdx
    jnz .Lsys_do_exec
    lea rdx, [rsp + 24] # empty envp [NULL]
.Lsys_do_exec:
    mov rax, 59         # sys_execve
    syscall

    # If execve returns, it failed
    mov rdi, 127
    mov rax, 60         # sys_exit
    syscall

.Lsys_err:
    mov rax, -1
.Lsys_done:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret


.global maya_process_argc
.type maya_process_argc, @function
maya_process_argc:
    mov rax, [rip + g_argc]
    ret

.global maya_process_argv
.type maya_process_argv, @function
maya_process_argv:
    mov rcx, [rip + g_argv]
    test rcx, rcx
    jz .Largv_empty
    mov rax, rdi
    imul rax, 8
    add rcx, rax
    mov rdi, [rcx]
    mov rsi, -1
    jmp maya_str_new
.Largv_empty:
    xor rdi, rdi
    xor rsi, rsi
    jmp maya_str_new

.global maya_set_args
.type maya_set_args, @function
maya_set_args:
    mov [rip + g_argc], rdi
    mov [rip + g_argv], rsi
    ret

.global maya_read_line
.global maya_read_stdin
.type maya_read_line, @function
.type maya_read_stdin, @function
maya_read_line:
maya_read_stdin:
    xor rdi, rdi
    xor rsi, rsi
    jmp maya_str_new

# ----------------------------------------------------------------------------
# 7. Array Operations
# ----------------------------------------------------------------------------
.global maya_array_new
.type maya_array_new, @function
maya_array_new:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    cmp r12, 0
    jg .Lan_cap_ok
    mov r12, 4
.Lan_cap_ok:
    cmp r13, 0
    jg .Lan_es_ok
    mov r13, 8
.Lan_es_ok:
    mov rdi, 32
    mov rsi, 2
    call maya_alloc_typed
    mov rbx, rax
    mov qword ptr [rbx], 0
    mov [rbx + 8], r12
    mov [rbx + 16], r13
    mov rdi, r12
    imul rdi, r13
    mov rsi, 0
    call maya_alloc_typed
    mov [rbx + 24], rax
    mov rax, rbx
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_array_len
.type maya_array_len, @function
maya_array_len:
    test rdi, rdi
    jz .Lal_zero
    mov rax, [rdi]
    ret
.Lal_zero:
    xor rax, rax
    ret

.global maya_array_push
.type maya_array_push, @function
maya_array_push:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .Lap_ret
    mov rcx, [r12]
    mov rdx, [r12 + 8]
    cmp rcx, rdx
    jl .Lap_store
    imul rdx, 2
    mov [r12 + 8], rdx
    mov rdi, [r12 + 24]
    mov rsi, rdx
    imul rsi, [r12 + 16]
    call maya_realloc
    mov [r12 + 24], rax
.Lap_store:
    mov rcx, [r12]
    mov r8, [r12 + 16]
    imul rcx, r8
    mov rdx, [r12 + 24]
    mov [rdx + rcx], r13
    inc qword ptr [r12]
.Lap_ret:
    mov rax, r12
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_array_get
.type maya_array_get, @function
maya_array_get:
    test rdi, rdi
    jz .Lag_zero
    cmp rsi, 0
    jl .Lag_zero
    cmp rsi, [rdi]
    jge .Lag_zero
    mov rcx, rsi
    imul rcx, [rdi + 16]
    mov rdx, [rdi + 24]
    mov rax, [rdx + rcx]
    ret
.Lag_zero:
    xor rax, rax
    ret

.global maya_array_set
.type maya_array_set, @function
maya_array_set:
    test rdi, rdi
    jz .Las_ret
    cmp rsi, 0
    jl .Las_ret
    cmp rsi, [rdi]
    jge .Las_ret
    mov rcx, rsi
    imul rcx, [rdi + 16]
    mov r8, [rdi + 24]
    mov [r8 + rcx], rdx
.Las_ret:
    mov rax, rdx
    ret

.global maya_array_concat
.global maya_array_contains
.global maya_array_find
.global maya_array_slice
.type maya_array_concat, @function
.type maya_array_contains, @function
.type maya_array_find, @function
.type maya_array_slice, @function
maya_array_concat:
    mov rax, rdi
    ret
maya_array_contains:
    xor rax, rax
    ret
maya_array_find:
    mov rax, -1
    ret
maya_array_slice:
    mov rax, rdi
    ret

# ----------------------------------------------------------------------------
# 8. Map Operations
# ----------------------------------------------------------------------------
.global maya_map_new
.type maya_map_new, @function
maya_map_new:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rdi, 32
    mov rsi, 3
    call maya_alloc_typed
    mov rbx, rax
    mov qword ptr [rbx], 16
    mov qword ptr [rbx + 8], 0
    mov rdi, 16 * 24
    mov rsi, 0
    call maya_alloc_typed
    mov [rbx + 16], rax
    mov rax, rbx
    add rsp, 8
    pop rbx
    pop rbp
    ret

.global maya_map_set
.type maya_map_set, @function
maya_map_set:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    test r12, r12
    jz .Lms_ret
    mov r8, [r12 + 16]
    mov rcx, [r12]
    xor rbx, rbx
.Lms_find:
    cmp rbx, rcx
    jge .Lms_insert
    mov rax, rbx
    imul rax, 24
    cmp qword ptr [r8 + rax + 16], 1
    jne .Lms_next
    push rcx
    push r8
    mov rdi, [r8 + rax]
    mov rsi, r13
    call maya_dynamic_eq
    pop r8
    pop rcx
    test rax, rax
    jnz .Lms_update
.Lms_next:
    inc rbx
    jmp .Lms_find
.Lms_update:
    mov rax, rbx
    imul rax, 24
    mov [r8 + rax + 8], r14
    jmp .Lms_ret
.Lms_insert:
    xor rbx, rbx
.Lms_unocc:
    cmp rbx, rcx
    jge .Lms_ret
    mov rax, rbx
    imul rax, 24
    cmp qword ptr [r8 + rax + 16], 0
    je .Lms_do_ins
    inc rbx
    jmp .Lms_unocc
.Lms_do_ins:
    mov [r8 + rax], r13
    mov [r8 + rax + 8], r14
    mov qword ptr [r8 + rax + 16], 1
    inc qword ptr [r12 + 8]
.Lms_ret:
    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_map_get
.type maya_map_get, @function
maya_map_get:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .Lmg_zero
    mov r8, [r12 + 16]
    mov rcx, [r12]
    xor rbx, rbx
.Lmg_loop:
    cmp rbx, rcx
    jge .Lmg_zero
    mov rax, rbx
    imul rax, 24
    cmp qword ptr [r8 + rax + 16], 1
    jne .Lmg_next
    push rcx
    push r8
    mov rdi, [r8 + rax]
    mov rsi, r13
    call maya_dynamic_eq
    pop r8
    pop rcx
    test rax, rax
    jnz .Lmg_found
.Lmg_next:
    inc rbx
    jmp .Lmg_loop
.Lmg_found:
    mov rax, rbx
    imul rax, 24
    mov rax, [r8 + rax + 8]
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret
.Lmg_zero:
    xor rax, rax
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global maya_map_has
.type maya_map_has, @function
maya_map_has:
    push rbp
    mov rbp, rsp
    call maya_map_get
    test rax, rax
    setne al
    movzx rax, al
    pop rbp
    ret

.global maya_map_delete
.type maya_map_delete, @function
maya_map_delete:
    xor rax, rax
    ret

.global maya_map_size
.type maya_map_size, @function
maya_map_size:
    test rdi, rdi
    jz .Lmsz_zero
    mov rax, [rdi + 8]
    ret
.Lmsz_zero:
    xor rax, rax
    ret

.global maya_map_keys
.type maya_map_keys, @function
maya_map_keys:
    push rbp
    mov rbp, rsp
    mov rdi, 4
    mov rsi, 8
    call maya_array_new
    pop rbp
    ret

# ----------------------------------------------------------------------------
# 9. Networking & JIT & Memory Access
# ----------------------------------------------------------------------------
.global maya_tcp_socket
.global maya_tcp_bind
.global maya_tcp_listen
.global maya_tcp_accept
.global maya_tcp_connect
.global maya_tcp_send
.global maya_tcp_recv
.global maya_tcp_close
.global maya_tcp_set_nonblocking
.type maya_tcp_socket, @function
.type maya_tcp_bind, @function
.type maya_tcp_listen, @function
.type maya_tcp_accept, @function
.type maya_tcp_connect, @function
.type maya_tcp_send, @function
.type maya_tcp_recv, @function
.type maya_tcp_close, @function
.type maya_tcp_set_nonblocking, @function
maya_tcp_socket:
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    xor rdx, rdx
    syscall
    ret
maya_tcp_bind:
    mov rax, 49
    syscall
    ret
maya_tcp_listen:
    mov rax, 50
    syscall
    ret
maya_tcp_accept:
    mov rax, 43
    syscall
    ret
maya_tcp_connect:
    mov rax, 42
    syscall
    ret
maya_tcp_send:
    mov r10, rcx
    mov rax, 44
    syscall
    ret
maya_tcp_recv:
    mov r10, rcx
    mov rax, 45
    syscall
    ret
maya_tcp_close:
    mov rax, 3
    syscall
    ret
maya_tcp_set_nonblocking:
    xor rax, rax
    ret

.global maya_jit_call
.global maya_jit_call0
.global maya_jit_call1
.global maya_jit_call2
.global maya_jit_call3
.global maya_jit_call4
.type maya_jit_call, @function
.type maya_jit_call0, @function
.type maya_jit_call1, @function
.type maya_jit_call2, @function
.type maya_jit_call3, @function
.type maya_jit_call4, @function
maya_jit_call:
maya_jit_call0:
    jmp rdi
maya_jit_call1:
    mov rax, rdi
    mov rdi, rsi
    jmp rax
maya_jit_call2:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    jmp rax
maya_jit_call3:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    jmp rax
maya_jit_call4:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov rcx, r8
    jmp rax

# ----------------------------------------------------------------------------
# 10. Sovereign Memory Accessors
# ----------------------------------------------------------------------------
.global sys_mem_read_u8
.global maya_mem_read_u8
.type sys_mem_read_u8, @function
.type maya_mem_read_u8, @function
sys_mem_read_u8:
maya_mem_read_u8:
    movzx rax, byte ptr [rdi]
    ret

.global sys_mem_write_u8
.global maya_mem_write_u8
.type sys_mem_write_u8, @function
.type maya_mem_write_u8, @function
sys_mem_write_u8:
maya_mem_write_u8:
    mov [rdi], sil
    xor rax, rax
    ret

.global sys_mem_read_u16
.global maya_mem_read_u16
.type sys_mem_read_u16, @function
.type maya_mem_read_u16, @function
sys_mem_read_u16:
maya_mem_read_u16:
    movzx rax, word ptr [rdi]
    ret

.global sys_mem_write_u16
.global maya_mem_write_u16
.type sys_mem_write_u16, @function
.type maya_mem_write_u16, @function
sys_mem_write_u16:
maya_mem_write_u16:
    mov [rdi], si
    xor rax, rax
    ret

.global sys_mem_read_u32
.global maya_mem_read_u32
.type sys_mem_read_u32, @function
.type maya_mem_read_u32, @function
sys_mem_read_u32:
maya_mem_read_u32:
    mov eax, dword ptr [rdi]
    ret

.global sys_mem_write_u32
.global maya_mem_write_u32
.type sys_mem_write_u32, @function
.type maya_mem_write_u32, @function
sys_mem_write_u32:
maya_mem_write_u32:
    mov [rdi], esi
    xor rax, rax
    ret

.global sys_mem_read_u64
.global maya_mem_read_u64
.type sys_mem_read_u64, @function
.type maya_mem_read_u64, @function
sys_mem_read_u64:
maya_mem_read_u64:
    mov rax, [rdi]
    ret

.global sys_mem_write_u64
.global maya_mem_write_u64
.type sys_mem_write_u64, @function
.type maya_mem_write_u64, @function
sys_mem_write_u64:
maya_mem_write_u64:
    mov [rdi], rsi
    xor rax, rax
    ret

.global maya_mem_write_bytes
.type maya_mem_write_bytes, @function
maya_mem_write_bytes:
    mov rcx, rdx
    rep movsb
    xor rax, rax
    ret

.global maya_gc_arenas_head
.type maya_gc_arenas_head, @function
maya_gc_arenas_head:
    lea rax, [rip + g_arenas_head]
    ret

.global maya_gc_large_chunks_head
.type maya_gc_large_chunks_head, @function
maya_gc_large_chunks_head:
    lea rax, [rip + g_large_chunks_head]
    ret

.global maya_gc_get_stack_top
.type maya_gc_get_stack_top, @function
maya_gc_get_stack_top:
    mov rax, [rip + g_stack_top]
    ret

.global maya_get_reg_dump
.type maya_get_reg_dump, @function
maya_get_reg_dump:
    lea rax, [rip + maya_reg_dump]
    ret

.section .data,"aw",@progbits
str_true:    .asciz "true"
str_false:   .asciz "false"
str_newline: .byte 10

.section .note.GNU-stack,"",@progbits
