%define sys_exit 60
%define sys_open 2
%define sys_close 3
%define sys_read 0
%define sys_write 1
%define sys_seek 8
%define sys_stat 4

%define stdout 1

%define success 0
%define failure 1

%define stat_st_size 48

extern str_len
extern str_to_int
extern byte_to_hex

section .bss

    %define filename_max_len 255
    filename: resq 1
    filename_len: resq 1

    file: resq 1

    arg_offset: resq 1
    arg_size: resq 1

    %define buffer_max_len 26
    buffer: resb buffer_max_len

    %define stat_len 512
    stat: resb stat_len

    %define output_buffer_max_len 80
    output_buffer: resb output_buffer_max_len

section .data

    msg_usage: db "Usage: hextract filename <-o offset> <-s size>", 10
    msg_usage_len: equ $-msg_usage

    msg_open_fail: db "Unable to open file", 10
    msg_open_fail_len: equ $-msg_open_fail

    msg_size_too_high: db "Size is too high: exceeds file size", 10
    msg_size_too_high_len: equ $-msg_size_too_high

    msg_offset_too_high: db "Offset is too high: exceeds file size", 10
    msg_offset_too_high_len: equ $-msg_offset_too_high

    outfile: db "outfile", 0

    newline: db 10

section .text

global _start
_start:
    mov rbp, rsp

    call parse_args

    ; Validate filename
    cmp qword [filename_len], 0
    je err_print_usage

    ; Look up file info
    mov rax, sys_stat
    mov rdi, [filename]
    mov rsi, stat
    syscall
    cmp rax, 0
    jl err_open

    ; Validate offset argument
    mov eax, [stat + stat_st_size]
    cmp qword [arg_offset], rax
    jge err_offset_too_high

    ; Validate size argument
    cmp qword [arg_size], 0
    je arg_size_default

        ; Fail if (size + offset) > file size
        mov eax, [stat + stat_st_size]
        sub rax, [arg_offset]
        cmp qword [arg_size], rax
        jg err_size_too_high

        jmp arg_size_done

    arg_size_default:

        ; Set size argument to (file size - offset) if not present
        mov eax, [stat + stat_st_size]
        sub rax, [arg_offset]
        mov qword [arg_size], rax

    arg_size_done:

    ; Open the file
    mov rax, sys_open
    mov rdi, [filename]
    mov rsi, 0
    mov rdx, 0
    syscall
    cmp rax, 0
    jl err_open
    mov [file], rax

    ; Apply the offset
    mov rax, sys_seek
    mov rdi, [file]
    mov rsi, [arg_offset]
    mov rdx, 0
    syscall

    mov rbx, [arg_size]

    read_loop:
        cmp rbx, 0
        jle read_loop_done

        ; Read up to buffer_max_len bytes
        cmp rbx, buffer_max_len
        jge read_full_buffer

            mov rdx, rbx
            jmp read_full_buffer_done

        read_full_buffer:

            mov rdx, buffer_max_len

        read_full_buffer_done:

        ; Perform the read
        mov rax, sys_read
        mov rdi, [file]
        mov rsi, buffer
        syscall
        cmp rax, 0
        jle err_open
        sub rbx, rax
        mov r12, rax

        mov r13, buffer
        mov r14, output_buffer

        convert_loop:
            cmp r12, 0
            jle convert_loop_done

            ; Convert a byte to hex
            xor rax, rax
            mov al, [r13]
            mov rdi, rax
            mov rsi, r14
            call byte_to_hex

            ; Add space for padding
            add r14, 2
            mov byte [r14], ' '

            dec r12
            inc r13
            inc r14
            jmp convert_loop

        convert_loop_done:

        ; Add newline
        mov byte [r14 - 1], 10

        ; Write a line of hex
        mov rax, sys_write
        mov rdi, stdout
        mov rsi, output_buffer
        mov rdx, r14
        sub rdx, output_buffer
        syscall

        sub rbx, r12
        jmp read_loop

    read_loop_done:

    mov rax, sys_close
    mov rdi, [file]
    syscall

    mov rax, sys_exit
    mov rdi, success
    syscall


parse_args:
    mov rbx, 2

    arg_loop:
        cmp rbx, [rbp]
        jg arg_loop_end

        mov rdi, [rbp + 8 * rbx]
        mov rsi, 255
        call str_len
        mov r12, rax

        ; See if the argument starts with a dash (whether it's a flag)
        cmp byte [rdi], '-'
        je arg_loop_flag

            ; This is a filename argument
            mov rax, [rbp + 8 * rbx]
            mov [filename], rax
            mov [filename_len], r12
            jmp arg_loop_continue

        arg_loop_flag:

            ; This is a flag. Make sure it's only 2 chars (dash + letter)
            cmp r12, 2
            jne err_print_usage

            cmp byte [rdi + 1], 'o'
            je arg_flag_offset

            cmp byte [rdi + 1], 's'
            je arg_flag_size

            jmp err_print_usage

            arg_flag_offset:
                mov r13, arg_offset
                jmp arg_parse

            arg_flag_size:
                mov r13, arg_size

            arg_parse:
                ; Advance to next parameter
                inc rbx
                cmp rbx, [rbp]
                jg err_print_usage

                ; Get length of next parameter
                mov rdi, [rbp + 8 * rbx]
                mov rsi, 255
                call str_len

                ; Convert to integer
                mov rsi, rax
                mov rdi, [rbp + 8 * rbx]
                call str_to_int

                ; Error check
                cmp rax, 0
                jne err_print_usage

                mov [r13], rcx
                jmp arg_loop_continue

    arg_loop_continue:
        inc rbx
        jmp arg_loop

    arg_loop_end:
        ret


err_print_usage:
    mov rsi, msg_usage
    mov rdx, msg_usage_len
    jmp exit_fail


err_open:
    mov rsi, msg_open_fail
    mov rdi, msg_open_fail_len
    jmp exit_fail


err_size_too_high:
    mov rsi, msg_size_too_high
    mov rdx, msg_size_too_high_len
    jmp exit_fail


err_offset_too_high:
    mov rsi, msg_offset_too_high
    mov rdx, msg_offset_too_high_len
    jmp exit_fail


exit_fail:
    mov rax, sys_write
    mov rdi, stdout
    syscall

    mov rax, sys_exit
    mov rdi, failure
    syscall
