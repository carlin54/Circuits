.section .text
.globl _start
_start:
    la sp, _stack_top       # set stack pointer
    # zero BSS
    la t0, __bss_start
    la t1, __bss_end
1:  bge t0, t1, 2f
    sd zero, 0(t0)
    addi t0, t0, 8
    j 1b
2:  call main               # call C main()
    # a0 holds return value (0 = pass)
    ecall                   # halt — testbench reads a0
