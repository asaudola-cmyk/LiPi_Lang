.intel_syntax noprefix
.text

.global test_syscall0_abi
.type test_syscall0_abi, @function
test_syscall0_abi:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    
    # rdi has pointer to uint64_t reg_block[8]
    # reg_block[0]: ret
    # reg_block[1]: rbx
    # reg_block[2]: rbp
    # reg_block[3]: r12
    # reg_block[4]: r13
    # reg_block[5]: r14
    # reg_block[6]: r15
    push rdi
    
    mov rbx, [rdi + 8]
    mov rbp, [rdi + 16]
    mov r12, [rdi + 24]
    mov r13, [rdi + 32]
    mov r14, [rdi + 40]
    mov r15, [rdi + 48]
    
    mov rdi, 39 # SYS_getpid
    call syscall0
    
    pop rdi
    mov [rdi + 0], rax
    mov [rdi + 8], rbx
    mov [rdi + 16], rbp
    mov [rdi + 24], r12
    mov [rdi + 32], r13
    mov [rdi + 40], r14
    mov [rdi + 48], r15
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

.global test_syscall6_abi
.type test_syscall6_abi, @function
test_syscall6_abi:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    
    push rdi # save struct pointer
    
    mov rbx, [rdi + 8]
    mov rbp, [rdi + 16]
    mov r12, [rdi + 24]
    mov r13, [rdi + 32]
    mov r14, [rdi + 40]
    mov r15, [rdi + 48]
    
    mov rdi, 39 # SYS_getpid
    xor rsi, rsi
    xor rdx, rdx
    xor rcx, rcx
    xor r8, r8
    xor r9, r9
    push 0      # 7th arg on stack ([rsp+8] inside syscall6)
    call syscall6
    add rsp, 8
    
    pop rdi
    mov [rdi + 0], rax
    mov [rdi + 8], rbx
    mov [rdi + 16], rbp
    mov [rdi + 24], r12
    mov [rdi + 32], r13
    mov [rdi + 40], r14
    mov [rdi + 48], r15
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rbx
    ret

.section .note.GNU-stack,"",@progbits
