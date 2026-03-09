/* GNAT Runtime Stubs for Bare-Metal Ada Kernel
   =============================================

   These are minimal implementations of GNAT runtime functions
   that are needed for bare-metal compilation.
*/

#include <stdint.h>

/* Overflow check - panic if overflow detected */
void __gnat_rcheck_CE_Overflow_Check(void) {
    __asm__ volatile("cli; hlt");
}

/* Index check - panic if index out of bounds */
void __gnat_rcheck_CE_Index_Check(void) {
    __asm__ volatile("cli; hlt");
}

/* Invalid data check - panic if data invalid */
void __gnat_rcheck_CE_Invalid_Data(void) {
    __asm__ volatile("cli; hlt");
}

/* Divide by zero check */
void __gnat_rcheck_CE_Divide_By_Zero(void) {
    __asm__ volatile("cli; hlt");
}

/* Unsigned exponentiation - minimal implementation */
uint64_t __gnat_unsigned_mul_with_ovflo_check(uint64_t a, uint64_t b) {
    return a * b;
}

/* String concatenation - minimal stub */
void __gnat_concat_2_str_concat_2(char *result, const char *a, const char *b) {
    /* Not implemented - use separate UART_Write_String calls instead */
}
