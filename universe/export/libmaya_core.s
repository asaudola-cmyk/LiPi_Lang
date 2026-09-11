# ============================================================================
# MAYA SOVEREIGN C-ABI EXPORT ENGINE — FREESTANDING RUNTIME LIBRARY
# Target: x86_64 Linux (System V AMD64 ABI & Raw Kernel Syscalls)
# Zero external libc dependencies (100% Maya Native Memory & Math Engine)
# ============================================================================

.intel_syntax noprefix

.section .data
.align 8
g_total_allocated: .quad 0
g_total_freed:     .quad 0
g_live_bytes:      .quad 0
g_alloc_count:     .quad 0
g_free_count:      .quad 0
g_collect_count:   .quad 0
empty_string:      .byte 0
str_true:          .ascii "true\0"
str_false:         .ascii "false\0"
str_newline:       .ascii "\n\0"

.section .text

# ----------------------------------------------------------------------------
# 1. Maya Memory Engine (Pure GC & Allocator)
# ----------------------------------------------------------------------------

.global maya_init
.type maya_init, @function
maya_init:
    xor eax, eax
    ret

.global maya_gc_init
.type maya_gc_init, @function
maya_gc_init:
    xor eax, eax
    ret

.global maya_alloc
.type maya_alloc, @function
maya_alloc:
    jmp maya_gc_alloc

.global maya_gc_alloc
.type maya_gc_alloc, @function
maya_gc_alloc:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    # Check and sanitize size in RDI
    test rdi, rdi
    jg 1f
    mov rdi, 16
1:
    # 16-byte align size
    add rdi, 15
    and rdi, -16
    mov rbx, rdi       # rbx = user payload size

    # Total mmap size = payload + 16-byte header
    lea rsi, [rbx + 16] # rsi = total allocation length
    mov r12, rsi       # r12 = total length for bookkeeping

    # Syscall 9: sys_mmap(addr=0, len=rsi, prot=PROT_READ|PROT_WRITE(3), flags=MAP_PRIVATE|MAP_ANONYMOUS(34), fd=-1, offset=0)
    xor rdi, rdi       # addr = 0
    mov rdx, 3         # prot = PROT_READ (1) | PROT_WRITE (2)
    mov r10, 34        # flags = MAP_PRIVATE (2) | MAP_ANONYMOUS (32)
    mov r8, -1         # fd = -1
    xor r9, r9         # offset = 0
    mov eax, 9         # SYS_mmap
    syscall

    # Check return value in RAX
    cmp rax, -4095
    jae .Lalloc_fail

    # Setup 16-byte header:
    # [rax + 0] = Magic 0x4D415941 ("MAYA")
    # [rax + 8] = User requested payload size (rbx)
    mov qword ptr [rax], 0x4D415941
    mov qword ptr [rax + 8], rbx

    # Update GC global tracking counters
    lock add qword ptr [rip + g_total_allocated], rbx
    lock add qword ptr [rip + g_live_bytes], rbx
    lock inc qword ptr [rip + g_alloc_count]

    # Return user payload address (rax + 16)
    add rax, 16
    pop r12
    pop rbx
    pop rbp
    ret

.Lalloc_fail:
    xor eax, eax
    pop r12
    pop rbx
    pop rbp
    ret


.global maya_free
.type maya_free, @function
maya_free:
    jmp maya_gc_free

.global maya_gc_free
.type maya_gc_free, @function
maya_gc_free:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    test rdi, rdi
    jz .Lfree_done

    # Header is at user_ptr - 16
    lea r12, [rdi - 16]

    # Determine size
    mov rbx, rsi
    test rbx, rbx
    jnz 1f
    mov rbx, qword ptr [r12 + 8] # read size from header
1:
    test rbx, rbx
    jg 2f
    mov rbx, 16
2:
    add rbx, 15
    and rbx, -16       # 16-byte aligned

    lea rsi, [rbx + 16] # total mmap size to munmap

    # Syscall 11: sys_munmap(addr=r12, len=rsi)
    mov rdi, r12
    mov eax, 11        # SYS_munmap
    syscall

    # Update GC global tracking counters atomically
    lock add qword ptr [rip + g_total_freed], rbx
    lock sub qword ptr [rip + g_live_bytes], rbx
    lock inc qword ptr [rip + g_free_count]

.Lfree_done:
    pop r12
    pop rbx
    pop rbp
    ret


.global maya_collect
.type maya_collect, @function
maya_collect:
    jmp maya_gc_collect

.global maya_gc_collect
.type maya_gc_collect, @function
maya_gc_collect:
    lock inc qword ptr [rip + g_collect_count]
    xor eax, eax
    ret


.global maya_gc_stats
.type maya_gc_stats, @function
maya_gc_stats:
    test rdi, rdi
    jz .Lstats_done
    mov rax, qword ptr [rip + g_total_allocated]
    mov qword ptr [rdi], rax
    mov rax, qword ptr [rip + g_total_freed]
    mov qword ptr [rdi + 8], rax
    mov rax, qword ptr [rip + g_live_bytes]
    mov qword ptr [rdi + 16], rax
    mov rax, qword ptr [rip + g_alloc_count]
    mov qword ptr [rdi + 24], rax
    mov rax, qword ptr [rip + g_free_count]
    mov qword ptr [rdi + 32], rax
    mov rax, qword ptr [rip + g_collect_count]
    mov qword ptr [rdi + 40], rax
.Lstats_done:
    ret


.global maya_gc_total_allocated
.type maya_gc_total_allocated, @function
maya_gc_total_allocated:
    mov rax, qword ptr [rip + g_total_allocated]
    ret


.global maya_gc_live_bytes
.type maya_gc_live_bytes, @function
maya_gc_live_bytes:
    mov rax, qword ptr [rip + g_live_bytes]
    ret


.global maya_gc_alloc_count
.type maya_gc_alloc_count, @function
maya_gc_alloc_count:
    mov rax, qword ptr [rip + g_alloc_count]
    ret

.global gc_is_valid_pointer
.type gc_is_valid_pointer, @function
gc_is_valid_pointer:
    push rbp
    mov rbp, rsp
    push r12
    sub rsp, 16

    # 1. Non-null check
    test rdi, rdi
    jz .Lptr_invalid

    # 2. 16-byte alignment check
    test rdi, 15
    jnz .Lptr_invalid

    # 3. Minimum user space address threshold
    cmp rdi, 0x10000
    jb .Lptr_invalid

    # 4. Canonical user space upper bound
    mov rax, 0x00007fffffffffff
    cmp rdi, rax
    ja .Lptr_invalid

    mov r12, rdi       # r12 = user pointer

    # 5. Probe page mapping via sys_mincore (syscall 27)
    lea rdi, [r12 - 16]
    and rdi, -4096     # Page align (4KB)
    mov rsi, 4096      # Length = 1 page
    lea rdx, [rbp - 24]# 1 byte vec on stack
    mov eax, 27        # SYS_mincore
    syscall
    test eax, eax
    jnz .Lptr_invalid

    # 6. Safe to dereference [r12 - 16]
    cmp qword ptr [r12 - 16], 0x4D415941 # "MAYA"
    jne .Lptr_invalid

    mov eax, 1
    add rsp, 16
    pop r12
    pop rbp
    ret

.Lptr_invalid:
    xor eax, eax
    add rsp, 16
    pop r12
    pop rbp
    ret

.global gc_is_interior_pointer
.type gc_is_interior_pointer, @function
gc_is_interior_pointer:
    xor eax, eax
    ret

.global gc_get_size_class
.type gc_get_size_class, @function
gc_get_size_class:
    cmp rdi, 16
    jle .Lsc1
    cmp rdi, 32
    jle .Lsc2
    cmp rdi, 64
    jle .Lsc3
    cmp rdi, 128
    jle .Lsc4
    cmp rdi, 256
    jle .Lsc5
    cmp rdi, 512
    jle .Lsc6
    cmp rdi, 1024
    jle .Lsc7
    cmp rdi, 2048
    jle .Lsc8
    xor eax, eax
    ret
.Lsc1: mov eax, 1; ret
.Lsc2: mov eax, 2; ret
.Lsc3: mov eax, 3; ret
.Lsc4: mov eax, 4; ret
.Lsc5: mov eax, 5; ret
.Lsc6: mov eax, 6; ret
.Lsc7: mov eax, 7; ret
.Lsc8: mov eax, 8; ret

.global gc_get_class_payload_size
.type gc_get_class_payload_size, @function
gc_get_class_payload_size:
    cmp rdi, 1
    je .Lps1
    cmp rdi, 2
    je .Lps2
    cmp rdi, 3
    je .Lps3
    cmp rdi, 4
    je .Lps4
    cmp rdi, 5
    je .Lps5
    cmp rdi, 6
    je .Lps6
    cmp rdi, 7
    je .Lps7
    cmp rdi, 8
    je .Lps8
    xor eax, eax
    ret
.Lps1: mov eax, 16; ret
.Lps2: mov eax, 32; ret
.Lps3: mov eax, 64; ret
.Lps4: mov eax, 128; ret
.Lps5: mov eax, 256; ret
.Lps6: mov eax, 512; ret
.Lps7: mov eax, 1024; ret
.Lps8: mov eax, 2048; ret


# ----------------------------------------------------------------------------
# 2. Maya String Engine (C ABI)
# ----------------------------------------------------------------------------

.global maya_string_with_len
.type maya_string_with_len, @function
maya_string_with_len:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi       # r12 = cstr
    mov r13, rsi       # r13 = len
    test r13, r13
    jns 1f
    xor r13, r13
1:

    # Allocate MayaString struct (16 bytes)
    mov rdi, 16
    call maya_gc_alloc
    test rax, rax
    jz .Lstr_alloc_err
    mov r14, rax       # r14 = MayaString*

    # Allocate character buffer (len + 1 bytes)
    lea rdi, [r13 + 1]
    call maya_gc_alloc
    test rax, rax
    jz .Lstr_buf_err
    mov r15, rax       # r15 = buffer*

    # Copy characters if r12 != 0 and r13 > 0
    test r12, r12
    jz 3f
    xor rcx, rcx
2:
    cmp rcx, r13
    jae 3f
    mov dl, byte ptr [r12 + rcx]
    mov byte ptr [r15 + rcx], dl
    inc rcx
    jmp 2b
3:
    mov byte ptr [r15 + r13], 0 # null terminator

    # Set struct fields
    mov qword ptr [r14], r13     # struct->length
    mov qword ptr [r14 + 8], r15 # struct->buffer

    mov rax, r14
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.Lstr_buf_err:
    mov rdi, r14
    mov rsi, 16
    call maya_gc_free
.Lstr_alloc_err:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret


.global maya_string_new
.type maya_string_new, @function
maya_string_new:
    test rdi, rdi
    jnz 1f
    xor rsi, rsi
    jmp maya_string_with_len
1:
    # Compute strlen in RDI
    push rdi
    xor rsi, rsi
2:
    cmp byte ptr [rdi + rsi], 0
    je 3f
    inc rsi
    jmp 2b
3:
    pop rdi
    jmp maya_string_with_len


.global maya_string_len
.type maya_string_len, @function
maya_string_len:
    test rdi, rdi
    jz 1f
    mov rax, qword ptr [rdi]
    ret
1:
    xor eax, eax
    ret


.global maya_string_cstr
.type maya_string_cstr, @function
maya_string_cstr:
    test rdi, rdi
    jz 1f
    mov rax, qword ptr [rdi + 8]
    test rax, rax
    jz 1f
    ret
1:
    lea rax, [rip + empty_string]
    ret


.global maya_string_concat
.type maya_string_concat, @function
maya_string_concat:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    push rbx
    sub rsp, 8

    # Extract lengths and buffers
    xor r12, r12
    xor r13, r13
    xor r14, r14
    xor r15, r15

    test rdi, rdi
    jz 1f
    mov r12, qword ptr [rdi]      # len_a
    mov r13, qword ptr [rdi + 8]  # buf_a
1:
    test rsi, rsi
    jz 2f
    mov r14, qword ptr [rsi]      # len_b
    mov r15, qword ptr [rsi + 8]  # buf_b
2:
    lea rbx, [r12 + r14]          # total_len = len_a + len_b

    # Allocate new MayaString (16 bytes)
    mov rdi, 16
    call maya_gc_alloc
    mov [rsp], rax                # save struct pointer

    # Allocate new buffer (total_len + 1)
    lea rdi, [rbx + 1]
    call maya_gc_alloc
    mov r8, rax                   # r8 = new_buf

    # Copy buf_a (r12 bytes)
    test r13, r13
    jz 4f
    xor rcx, rcx
3:
    cmp rcx, r12
    jae 4f
    mov dl, byte ptr [r13 + rcx]
    mov byte ptr [r8 + rcx], dl
    inc rcx
    jmp 3b
4:
    # Copy buf_b (r14 bytes)
    test r15, r15
    jz 6f
    lea rdi, [r8 + r12]           # destination for buf_b
    xor rcx, rcx
5:
    cmp rcx, r14
    jae 6f
    mov dl, byte ptr [r15 + rcx]
    mov byte ptr [rdi + rcx], dl
    inc rcx
    jmp 5b
6:
    mov byte ptr [r8 + rbx], 0    # null terminator

    mov rax, [rsp]
    mov qword ptr [rax], rbx
    mov qword ptr [rax + 8], r8

    add rsp, 8
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret


.global maya_string_to_upper
.type maya_string_to_upper, @function
maya_string_to_upper:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .Lupper_null

    mov r12, qword ptr [rdi]     # len
    mov r13, qword ptr [rdi + 8] # buf

    # Allocate MayaString struct (16 bytes)
    mov rdi, 16
    call maya_gc_alloc
    mov r14, rax

    # Allocate new buffer (len + 1)
    lea rdi, [r12 + 1]
    call maya_gc_alloc
    mov r15, rax

    xor rcx, rcx
1:
    cmp rcx, r12
    jae 3f
    mov al, byte ptr [r13 + rcx]
    cmp al, 'a'
    jb 2f
    cmp al, 'z'
    ja 2f
    sub al, 32
2:
    mov byte ptr [r15 + rcx], al
    inc rcx
    jmp 1b
3:
    mov byte ptr [r15 + r12], 0
    mov qword ptr [r14], r12
    mov qword ptr [r14 + 8], r15
    mov rax, r14

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.Lupper_null:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret


.global maya_string_to_lower
.type maya_string_to_lower, @function
maya_string_to_lower:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    test rdi, rdi
    jz .Llower_null

    mov r12, qword ptr [rdi]     # len
    mov r13, qword ptr [rdi + 8] # buf

    mov rdi, 16
    call maya_gc_alloc
    mov r14, rax

    lea rdi, [r12 + 1]
    call maya_gc_alloc
    mov r15, rax

    xor rcx, rcx
1:
    cmp rcx, r12
    jae 3f
    mov al, byte ptr [r13 + rcx]
    cmp al, 'A'
    jb 2f
    cmp al, 'Z'
    ja 2f
    add al, 32
2:
    mov byte ptr [r15 + rcx], al
    inc rcx
    jmp 1b
3:
    mov byte ptr [r15 + r12], 0
    mov qword ptr [r14], r12
    mov qword ptr [r14 + 8], r15
    mov rax, r14

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.Llower_null:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret


.global maya_string_find
.type maya_string_find, @function
maya_string_find:
    test rdi, rdi
    jz .Lfind_fail
    test rsi, rsi
    jz .Lfind_fail

    mov r8, qword ptr [rdi]     # str_len
    mov r9, qword ptr [rdi + 8] # str_buf

    # Calculate sub_len of rsi
    xor r10, r10
1:
    cmp byte ptr [rsi + r10], 0
    je 2f
    inc r10
    jmp 1b
2:
    test r10, r10
    jz .Lfind_zero
    cmp r10, r8
    ja .Lfind_fail

    # Loop i from 0 to (r8 - r10)
    mov r11, r8
    sub r11, r10
    xor rax, rax        # i = 0
3:
    cmp rax, r11
    ja .Lfind_fail

    # Match inner loop: k = 0 to r10
    lea rdx, [r9 + rax] # rdx = str_buf + i
    xor rcx, rcx
4:
    cmp rcx, r10
    jae .Lfind_match
    movzx edi, byte ptr [rdx + rcx]
    cmp dil, byte ptr [rsi + rcx]
    jne 5f
    inc rcx
    jmp 4b
5:
    inc rax
    jmp 3b

.Lfind_match:
    ret

.Lfind_zero:
    xor eax, eax
    ret

.Lfind_fail:
    mov rax, -1
    ret


.global maya_string_compare
.type maya_string_compare, @function
maya_string_compare:
    test rdi, rdi
    jz .Lcmp_a_null
    test rsi, rsi
    jz .Lcmp_b_null

    mov r8, qword ptr [rdi]      # len_a
    mov r9, qword ptr [rdi + 8]  # buf_a
    mov r10, qword ptr [rsi]     # len_b
    mov r11, qword ptr [rsi + 8] # buf_b

    mov rcx, r8
    cmp rcx, r10
    cmova rcx, r10              # rcx = min(len_a, len_b)

    xor rdx, rdx
1:
    cmp rdx, rcx
    jae 2f
    movzx eax, byte ptr [r9 + rdx]
    movzx edi, byte ptr [r11 + rdx]
    cmp eax, edi
    jb .Lcmp_lt
    ja .Lcmp_gt
    inc rdx
    jmp 1b
2:
    cmp r8, r10
    jb .Lcmp_lt
    ja .Lcmp_gt
    xor rax, rax
    ret

.Lcmp_lt:
    mov rax, -1
    ret
.Lcmp_gt:
    mov rax, 1
    ret
.Lcmp_a_null:
    test rsi, rsi
    jz .Lcmp_eq
    mov rax, -1
    ret
.Lcmp_b_null:
    mov rax, 1
    ret
.Lcmp_eq:
    xor rax, rax
    ret


.global maya_string_free
.type maya_string_free, @function
maya_string_free:
    push rbp
    mov rbp, rsp
    push r12
    push r13

    test rdi, rdi
    jz 1f
    mov r12, rdi
    mov r13, qword ptr [r12 + 8] # buf
    mov rsi, qword ptr [r12]     # len
    inc rsi                      # len + 1
    test r13, r13
    jz 2f
    mov rdi, r13
    call maya_gc_free
2:
    mov rdi, r12
    mov rsi, 16
    call maya_gc_free
1:
    pop r13
    pop r12
    pop rbp
    ret


# ----------------------------------------------------------------------------
# 3. Maya Dynamic Array Engine (C ABI)
# ----------------------------------------------------------------------------

.global maya_array_new
.type maya_array_new, @function
maya_array_new:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rdi       # initial_cap
    mov r13, rsi       # elem_size

    cmp r12, 4
    jge 1f
    mov r12, 4
1:
    cmp r13, 8
    jge 2f
    mov r13, 8
2:

    # Allocate MayaArray struct (32 bytes)
    mov rdi, 32
    call maya_gc_alloc
    mov r14, rax

    # Allocate data buffer (capacity * elem_size)
    mov rax, r12
    imul rax, r13
    mov rdi, rax
    call maya_gc_alloc

    # Fill struct:
    # [r14 + 0] = length (0)
    # [r14 + 8] = capacity (r12)
    # [r14 + 16] = elem_size (r13)
    # [r14 + 24] = data buffer (rax)
    mov qword ptr [r14], 0
    mov qword ptr [r14 + 8], r12
    mov qword ptr [r14 + 16], r13
    mov qword ptr [r14 + 24], rax

    mov rax, r14
    pop r14
    pop r13
    pop r12
    pop rbp
    ret


.global maya_array_len
.type maya_array_len, @function
maya_array_len:
    test rdi, rdi
    jz 1f
    mov rax, qword ptr [rdi]
    ret
1:
    xor eax, eax
    ret


.global maya_array_cap
.type maya_array_cap, @function
maya_array_cap:
    test rdi, rdi
    jz 1f
    mov rax, qword ptr [rdi + 8]
    ret
1:
    xor eax, eax
    ret


.global maya_array_push
.type maya_array_push, @function
maya_array_push:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15
    push rbx
    sub rsp, 16

    test rdi, rdi
    jz .Lpush_err

    mov r12, rdi       # r12 = MayaArray*
    mov r13, rsi       # r13 = val to push

    mov r14, qword ptr [r12]      # len
    mov r15, qword ptr [r12 + 8]  # cap
    mov rbx, qword ptr [r12 + 16] # elem_size
    mov rdx, qword ptr [r12 + 24] # data

    cmp r14, r15
    jb .Lpush_store

    # Array full: double capacity
    lea rax, [r15 + r15]
    cmp rax, 4
    jge 1f
    mov rax, 4
1:
    mov [rsp + 0], rax # save new_cap at rsp + 0

    # Allocate new buffer (new_cap * elem_size)
    imul rax, rbx
    mov rdi, rax
    call maya_gc_alloc
    mov r8, rax        # r8 = new_data

    # Copy old data to new buffer (len * elem_size bytes)
    mov r9, qword ptr [r12 + 24] # old data
    mov rax, r14
    imul rax, rbx      # total bytes to copy
    xor rcx, rcx
2:
    cmp rcx, rax
    jae 3f
    mov dl, byte ptr [r9 + rcx]
    mov byte ptr [r8 + rcx], dl
    inc rcx
    jmp 2b
3:
    # Free old buffer
    mov rdi, r9
    mov rax, r15
    imul rax, rbx
    mov rsi, rax
    mov [rsp + 8], r8  # protect r8 at rsp + 8
    call maya_gc_free
    mov r8, [rsp + 8]

    mov rax, [rsp + 0] # reload new_cap from rsp + 0
    mov qword ptr [r12 + 8], rax
    mov qword ptr [r12 + 24], r8

.Lpush_store:
    mov r8, qword ptr [r12 + 24] # data buffer
    mov rax, r14
    imul rax, qword ptr [r12 + 16] # offset = len * elem_size
    mov qword ptr [r8 + rax], r13  # store val

    inc r14
    mov qword ptr [r12], r14       # length++
    mov rax, r14

    add rsp, 16
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.Lpush_err:
    xor eax, eax
    add rsp, 16
    pop rbx
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret


.global maya_array_get
.type maya_array_get, @function
maya_array_get:
    test rdi, rdi
    jz 1f
    cmp rsi, qword ptr [rdi] # cmp idx, length
    jae 1f

    mov rax, qword ptr [rdi + 24] # data
    imul rsi, qword ptr [rdi + 16] # idx * elem_size
    mov rax, qword ptr [rax + rsi]
    ret
1:
    xor eax, eax
    ret


.global maya_array_set
.type maya_array_set, @function
maya_array_set:
    test rdi, rdi
    jz 1f
    cmp rsi, qword ptr [rdi] # cmp idx, length
    jae 1f

    mov rax, qword ptr [rdi + 24]  # data
    imul rsi, qword ptr [rdi + 16] # idx * elem_size
    mov qword ptr [rax + rsi], rdx
    xor eax, eax
    ret
1:
    mov rax, -1
    ret


.global maya_array_free
.type maya_array_free, @function
maya_array_free:
    push rbp
    mov rbp, rsp
    push r12

    test rdi, rdi
    jz 1f
    mov r12, rdi

    # Free data buffer
    mov rdi, qword ptr [r12 + 24]
    mov rax, qword ptr [r12 + 8]  # cap
    imul rax, qword ptr [r12 + 16] # elem_size
    mov rsi, rax
    call maya_gc_free

    # Free struct
    mov rdi, r12
    mov rsi, 32
    call maya_gc_free
1:
    pop r12
    pop rbp
    ret


# ----------------------------------------------------------------------------
# 4. Maya Advanced Mathematics Engine (C ABI)
# ----------------------------------------------------------------------------

.global abs
.type abs, @function
abs:
.global math_abs
.type math_abs, @function
math_abs:
.global maya_math_abs
.type maya_math_abs, @function
maya_math_abs:
    mov rax, rdi
    test rax, rax
    jns 1f
    neg rax
1:
    ret

.global min
.type min, @function
min:
.global math_min
.type math_min, @function
math_min:
.global maya_math_min
.type maya_math_min, @function
maya_math_min:
    cmp rdi, rsi
    mov rax, rdi
    cmovg rax, rsi
    ret

.global max
.type max, @function
max:
.global math_max
.type math_max, @function
math_max:
.global maya_math_max
.type maya_math_max, @function
maya_math_max:
    cmp rdi, rsi
    mov rax, rdi
    cmovl rax, rsi
    ret

.global clamp
.type clamp, @function
clamp:
.global math_clamp
.type math_clamp, @function
math_clamp:
.global maya_math_clamp
.type maya_math_clamp, @function
maya_math_clamp:
    cmp rdi, rsi
    cmovl rdi, rsi
    cmp rdi, rdx
    cmovg rdi, rdx
    mov rax, rdi
    ret

.global pow_int
.type pow_int, @function
pow_int:
.global math_pow
.type math_pow, @function
math_pow:
.global maya_math_pow
.type maya_math_pow, @function
maya_math_pow:
    test rsi, rsi
    js .Lpow_zero
    mov rax, 1
    mov r8, rdi
    mov rcx, rsi
1:
    test rcx, rcx
    jle .Lpow_done
    test cl, 1
    jz 2f
    imul rax, r8
2:
    imul r8, r8
    sar rcx, 1
    jmp 1b
.Lpow_zero:
    xor eax, eax
.Lpow_done:
    ret

.global sqrt_int
.type sqrt_int, @function
sqrt_int:
.global math_sqrt
.type math_sqrt, @function
math_sqrt:
.global maya_math_sqrt
.type maya_math_sqrt, @function
maya_math_sqrt:
    test rdi, rdi
    jle .Lsqrt_zero
    cmp rdi, 1
    je .Lsqrt_one

    mov r8, 1          # lo = 1
    mov r9, rdi        # hi = n
    mov rax, 1         # ans = 1
1:
    cmp r8, r9
    jg .Lsqrt_done
    lea r10, [r8 + r9]
    sar r10, 1         # mid = (lo + hi) / 2

    mov r11, r10
    imul r11, r10      # mid * mid
    cmp r11, rdi
    ja 2f
    mov rax, r10       # ans = mid
    lea r8, [r10 + 1]  # lo = mid + 1
    jmp 1b
2:
    lea r9, [r10 - 1]  # hi = mid - 1
    jmp 1b

.Lsqrt_zero:
    xor eax, eax
    ret
.Lsqrt_one:
    mov eax, 1
.Lsqrt_done:
    ret

.global factorial
.type factorial, @function
factorial:
.global maya_math_factorial
.type maya_math_factorial, @function
maya_math_factorial:
    cmp rdi, 1
    jle 2f
    mov rax, 1
    mov rcx, 2
1:
    cmp rcx, rdi
    jg 3f
    imul rax, rcx
    inc rcx
    jmp 1b
2:
    mov eax, 1
3:
    ret

.global gcd
.type gcd, @function
gcd:
.global maya_math_gcd
.type maya_math_gcd, @function
maya_math_gcd:
    mov rax, rdi
    mov rcx, rsi
1:
    test rcx, rcx
    jz 2f
    cqo
    idiv rcx
    mov rax, rcx
    mov rcx, rdx
    jmp 1b
2:
    test rax, rax
    jns 3f
    neg rax
3:
    ret

.global lcm
.type lcm, @function
lcm:
.global maya_math_lcm
.type maya_math_lcm, @function
maya_math_lcm:
    push rbp
    mov rbp, rsp
    push rbx
    push r12

    test rdi, rdi
    jz 1f
    test rsi, rsi
    jz 1f

    mov rbx, rdi
    mov r12, rsi

    call maya_math_gcd
    mov rcx, rax
    mov rax, rbx
    cqo
    idiv rcx
    imul rax, r12
    test rax, rax
    jns 2f
    neg rax
    jmp 2f
1:
    xor eax, eax
2:
    pop r12
    pop rbx
    pop rbp
    ret

.global is_prime
.type is_prime, @function
is_prime:
.global maya_math_is_prime
.type maya_math_is_prime, @function
maya_math_is_prime:
    cmp rdi, 1
    jle .Lprime_no
    cmp rdi, 3
    jle .Lprime_yes

    # Check mod 2 == 0 or mod 3 == 0
    mov rax, rdi
    and rax, 1
    jz .Lprime_no

    mov rax, rdi
    xor edx, edx
    mov rcx, 3
    div rcx
    test rdx, rdx
    jz .Lprime_no

    # Loop i = 5; i*i <= n; i += 6
    mov r8, 5
1:
    mov rax, r8
    imul rax, r8
    cmp rax, rdi
    ja .Lprime_yes

    mov rax, rdi
    xor edx, edx
    div r8
    test rdx, rdx
    jz .Lprime_no

    lea rcx, [r8 + 2]
    mov rax, rdi
    xor edx, edx
    div rcx
    test rdx, rdx
    jz .Lprime_no

    add r8, 6
    jmp 1b

.Lprime_yes:
    mov eax, 1
    ret
.Lprime_no:
    xor eax, eax
    ret

.global fibonacci
.type fibonacci, @function
fibonacci:
.global maya_math_fibonacci
.type maya_math_fibonacci, @function
maya_math_fibonacci:
    test rdi, rdi
    jle .Lfib_zero
    cmp rdi, 1
    je .Lfib_one

    xor rax, rax       # a = 0
    mov rdx, 1         # b = 1
    mov rcx, 2
1:
    cmp rcx, rdi
    jg .Lfib_done
    lea r8, [rax + rdx] # c = a + b
    mov rax, rdx       # a = b
    mov rdx, r8        # b = c
    inc rcx
    jmp 1b
.Lfib_done:
    mov rax, rdx
    ret
.Lfib_zero:
    xor eax, eax
    ret
.Lfib_one:
    mov eax, 1
    ret

.global sin_fixed_deg
.type sin_fixed_deg, @function
sin_fixed_deg:
.global maya_math_sin_deg
.type maya_math_sin_deg, @function
maya_math_sin_deg:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13

    # d = deg % 360
    mov rax, rdi
    cqo
    mov rcx, 360
    idiv rcx
    mov rdi, rdx
    test rdi, rdi
    jns 1f
    add rdi, 360
1:
    mov r12, 1         # sign = 1
    cmp rdi, 180
    jle 2f
    neg r12            # sign = -1
    sub rdi, 180
2:
    cmp rdi, 90
    jle 3f
    mov rax, 180
    sub rax, rdi
    mov rdi, rax
3:
    # Approx: (4 * d * (180 - d) * scale) / (40500 - d * (180 - d))
    mov rax, 180
    sub rax, rdi
    imul rax, rdi      # rax = d * (180 - d)
    mov r13, rax       # r13 = term

    # num = 4 * term * scale
    lea rax, [r13 * 4]
    imul rax, rsi      # rax = num

    # den = 40500 - term
    mov rcx, 40500
    sub rcx, r13
    test rcx, rcx
    jnz 4f
    mov rax, rsi
    imul rax, r12
    jmp 5f
4:
    cqo
    idiv rcx
    imul rax, r12
5:
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret

.global cos_fixed_deg
.type cos_fixed_deg, @function
cos_fixed_deg:
.global maya_math_cos_deg
.type maya_math_cos_deg, @function
maya_math_cos_deg:
    add rdi, 90
    jmp maya_math_sin_deg

.global lerp
.type lerp, @function
lerp:
.global maya_math_lerp
.type maya_math_lerp, @function
maya_math_lerp:
    sub rsi, rdi       # (b - a)
    imul rsi, rdx      # (b - a) * t_pct
    mov rax, rsi
    cqo
    mov rcx, 100
    idiv rcx
    add rax, rdi
    ret

.global hypot
.type hypot, @function
hypot:
    imul rdi, rdi
    imul rsi, rsi
    add rdi, rsi
    jmp maya_math_sqrt

.global log2_int
.type log2_int, @function
log2_int:
    test rdi, rdi
    jle .Llog2_neg
    xor eax, eax
1:
    cmp rdi, 1
    jle .Llog2_done
    sar rdi, 1
    inc eax
    jmp 1b
.Llog2_done:
    ret
.Llog2_neg:
    mov rax, -1
    ret


# ----------------------------------------------------------------------------
# 5. Maya Cryptographic & Hash Routines (C ABI)
# ----------------------------------------------------------------------------

.global maya_hash_fnv1a
.type maya_hash_fnv1a, @function
maya_hash_fnv1a:
    test rdi, rdi
    jz .Lfnv_zero
    test rsi, rsi
    jle .Lfnv_zero

    # FNV offset basis: 14695981039346656037 (0xcbf29ce484222325)
    mov rax, 0xcbf29ce484222325
    # FNV prime: 1099511628211 (0x100000001b3)
    mov r8, 0x100000001b3
    xor rcx, rcx
1:
    cmp rcx, rsi
    jae .Lfnv_done
    movzx rdx, byte ptr [rdi + rcx]
    xor rax, rdx
    imul rax, r8
    inc rcx
    jmp 1b
.Lfnv_done:
    ret
.Lfnv_zero:
    xor eax, eax
    ret


.global maya_hash_string
.type maya_hash_string, @function
maya_hash_string:
    test rdi, rdi
    jz 2f
    xor rsi, rsi
1:
    cmp byte ptr [rdi + rsi], 0
    je maya_hash_fnv1a
    inc rsi
    jmp 1b
2:
    xor eax, eax
    ret


.global maya_hash_crc32
.type maya_hash_crc32, @function
maya_hash_crc32:
    test rdi, rdi
    jz .Lcrc_zero
    test rsi, rsi
    jle .Lcrc_zero

    mov eax, 0xFFFFFFFF
    xor rcx, rcx
1:
    cmp rcx, rsi
    jae .Lcrc_done
    movzx edx, byte ptr [rdi + rcx]
    xor eax, edx
    mov r8d, 8
2:
    test al, 1
    jz 3f
    shr eax, 1
    xor eax, 0xEDB88320
    jmp 4f
3:
    shr eax, 1
4:
    dec r8d
    jnz 2b
    inc rcx
    jmp 1b
.Lcrc_done:
    xor eax, 0xFFFFFFFF
    ret
.Lcrc_zero:
    xor eax, eax
    ret


.global maya_hash_murmur3
.type maya_hash_murmur3, @function
maya_hash_murmur3:
    test rdi, rdi
    jz .Lmur_zero
    test rsi, rsi
    jle .Lmur_zero

    mov r8, 0x100000001b3
    mov rax, rdx          # h = seed
    mov rcx, rsi
    imul rcx, r8
    xor rax, rcx          # h = seed ^ (len * prime)

    xor rcx, rcx
1:
    cmp rcx, rsi
    jae .Lmur_done
    movzx rdx, byte ptr [rdi + rcx]
    xor rax, rdx
    imul rax, r8
    mov r9, rax
    shr r9, 16
    xor rax, r9
    imul rax, r8
    inc rcx
    jmp 1b
.Lmur_done:
    ret
.Lmur_zero:
    mov rax, rdx
    ret


# ----------------------------------------------------------------------------
# 6. Maya Syscall I/O & System Routines (C ABI)
# ----------------------------------------------------------------------------

.global maya_print_str
.type maya_print_str, @function
maya_print_str:
    test rdi, rdi
    jz .Lpstr_done
    mov rsi, rdi       # rsi = buf
    xor rdx, rdx       # count = 0
1:
    cmp byte ptr [rsi + rdx], 0
    je 2f
    inc rdx
    jmp 1b
2:
    test rdx, rdx
    jz .Lpstr_done
    mov edi, 1         # fd = 1 (stdout)
    mov eax, 1         # SYS_write
    syscall
.Lpstr_done:
    xor eax, eax
    ret

.global maya_println_str
.type maya_println_str, @function
maya_println_str:
    call maya_print_str
    lea rsi, [rip + str_newline]
    mov edi, 1
    mov edx, 1
    mov eax, 1
    syscall
    xor eax, eax
    ret

.global maya_print_i64
.type maya_print_i64, @function
maya_print_i64:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov rax, rdi
    lea rsi, [rbp - 1]
    mov byte ptr [rsi], 0
    test rax, rax
    jns 1f
    neg rax
    mov r8, 1          # negative flag
    jmp 2f
1:
    xor r8, r8
2:
    mov rcx, 10
3:
    xor edx, edx
    div rcx
    add dl, '0'
    dec rsi
    mov byte ptr [rsi], dl
    test rax, rax
    jnz 3b
    test r8, r8
    jz 4f
    dec rsi
    mov byte ptr [rsi], '-'
4:
    mov rdi, rsi
    call maya_print_str
    add rsp, 32
    pop rbp
    ret

.global maya_println_i64
.type maya_println_i64, @function
maya_println_i64:
    call maya_print_i64
    lea rsi, [rip + str_newline]
    mov edi, 1
    mov edx, 1
    mov eax, 1
    syscall
    xor eax, eax
    ret

.global maya_print_bool
.type maya_print_bool, @function
maya_print_bool:
    test rdi, rdi
    jz 1f
    lea rdi, [rip + str_true]
    jmp maya_print_str
1:
    lea rdi, [rip + str_false]
    jmp maya_print_str

.global maya_println_bool
.type maya_println_bool, @function
maya_println_bool:
    call maya_print_bool
    lea rsi, [rip + str_newline]
    mov edi, 1
    mov edx, 1
    mov eax, 1
    syscall
    xor eax, eax
    ret

.global maya_clock_ms
.type maya_clock_ms, @function
maya_clock_ms:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov rdi, 0         # CLOCK_REALTIME
    mov rsi, rsp       # struct timespec*
    mov eax, 228       # SYS_clock_gettime
    syscall
    test eax, eax
    jnz .Lclock_err
    mov rax, qword ptr [rsp]     # tv_sec
    imul rax, 1000
    mov rdx, qword ptr [rsp + 8] # tv_nsec
    cqo
    mov rcx, 1000000
    idiv rcx
    add rax, qword ptr [rsp]     # sec * 1000 + nsec / 1M
.Lclock_err:
    add rsp, 16
    pop rbp
    ret

.global maya_exit
.type maya_exit, @function
maya_exit:
    mov eax, 60        # SYS_exit
    syscall
    ret

.global maya_file_exists
.type maya_file_exists, @function
maya_file_exists:
    mov rsi, 0         # F_OK
    mov eax, 21        # SYS_access
    syscall
    test eax, eax
    setz al
    movzx eax, al
    ret

.global maya_file_read
.type maya_file_read, @function
maya_file_read:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    # rdi = path, rsi = buffer, rdx = max_len
    test rdi, rdi
    jz .Lfr_err
    test rsi, rsi
    jz .Lfr_err
    test rdx, rdx
    jz .Lfr_zero

    mov r13, rsi       # r13 = buffer
    mov r14, rdx       # r14 = max_len

    # sys_open(path, O_RDONLY=0, 0)
    mov rsi, 0
    mov rdx, 0
    mov eax, 2         # SYS_open
    syscall
    test eax, eax
    js .Lfr_err
    mov r12d, eax      # r12d = fd

    # sys_read(fd, buffer, max_len)
    mov edi, r12d
    mov rsi, r13
    mov rdx, r14
    mov eax, 0         # SYS_read
    syscall
    mov r15, rax       # r15 = bytes read (or negative error)

    # sys_close(fd)
    mov edi, r12d
    mov eax, 3         # SYS_close
    syscall

    test r15, r15
    js .Lfr_err

    # Null-terminate if space permits (r15 < r14)
    cmp r15, r14
    jae .Lfr_done
    mov byte ptr [r13 + r15], 0

.Lfr_done:
    mov rax, r15
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.Lfr_zero:
    xor eax, eax
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.Lfr_err:
    mov rax, -1
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.global maya_file_write
.type maya_file_write, @function
maya_file_write:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rsi       # r12 = content

    # sys_open(path, O_WRONLY|O_CREAT|O_TRUNC=577, 0644=420)
    mov rsi, 577
    mov rdx, 420
    mov eax, 2
    syscall
    cmp eax, 0
    jl .Lfw_fail
    mov r13d, eax      # r13 = fd

    # Calculate content length
    xor r14, r14
1:
    cmp byte ptr [r12 + r14], 0
    je 2f
    inc r14
    jmp 1b
2:
    # sys_write(fd, content, len)
    mov edi, r13d
    mov rsi, r12
    mov rdx, r14
    mov eax, 1
    syscall

    # sys_close(fd)
    mov edi, r13d
    mov eax, 3
    syscall

    mov eax, 1
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.Lfw_fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.global maya_file_append
.type maya_file_append, @function
maya_file_append:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14

    mov r12, rsi       # r12 = content

    # sys_open(path, O_WRONLY|O_CREAT|O_APPEND=1089, 0644=420)
    mov rsi, 1089
    mov rdx, 420
    mov eax, 2
    syscall
    cmp eax, 0
    jl .Lfa_fail
    mov r13d, eax      # r13 = fd

    xor r14, r14
1:
    cmp byte ptr [r12 + r14], 0
    je 2f
    inc r14
    jmp 1b
2:
    mov edi, r13d
    mov rsi, r12
    mov rdx, r14
    mov eax, 1
    syscall

    mov edi, r13d
    mov eax, 3
    syscall

    mov eax, 1
    pop r14
    pop r13
    pop r12
    pop rbp
    ret
.Lfa_fail:
    xor eax, eax
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

.section .note.GNU-stack,"",@progbits
