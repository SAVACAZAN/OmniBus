/* UART I/O Implementation using GCC inline assembly */

#include <stdint.h>

/* Write a single byte to UART port 0x3F8 */
void uart_write_byte(uint8_t byte) {
    /* x86-64 OUT instruction: output AL to port in DX */
    /* mov $0x3f8, %dx  → load UART port address */
    /* outb %al, %dx    → output byte */
    asm volatile(
        "mov $0x3f8, %%edx\n\t"  /* load port address */
        "outb %%al, %%dx"        /* output byte to port */
        :                        /* no output operands */
        : "a" (byte)             /* input: byte in AL register */
        : "%edx"                 /* clobber: DX register */
    );
}

/* Alternative: More compact single instruction (requires port in DX) */
void uart_write_byte_dx(uint8_t byte, uint16_t port) {
    asm volatile("outb %%al, %%dx"
        :
        : "a" (byte), "d" (port)
        );
}
