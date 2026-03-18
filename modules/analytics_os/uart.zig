// uart.zig — UART debug output for bare-metal Analytics OS
// Writes to COM1 (port 0x3F8) at 115200 baud (already configured by kernel_stub.asm)

const std = @import("std");

// UART port for COM1
const UART_PORT: u16 = 0x3F8;

// Write a single byte to UART
pub fn writeByte(byte: u8) void {
    // Simple output - kernel_stub.asm already configured UART at 115200
    asm volatile ("out %al, %dx"
        :
        : [byte] "{al}" (byte),
          [port] "{dx}" (UART_PORT),
    );
}

// Write a null-terminated string
pub fn writeStr(str: [*:0]const u8) void {
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {
        writeByte(str[i]);
    }
}

// Write a u64 as 16 hex digits
pub fn writeHex64(value: u64) void {
    const hex_chars = "0123456789abcdef";
    var i: i32 = 56; // Start at bit 56
    while (i >= 0) : (i -= 4) {
        const nibble = @as(u4, @truncate(@as(u8, @truncate(value >> @as(u6, @intCast(i))))));
        writeByte(hex_chars[nibble]);
    }
}

// Write a 32-bit value as 8 hex digits
pub fn writeHex32(value: u32) void {
    const hex_chars = "0123456789abcdef";
    var i: i32 = 28;
    while (i >= 0) : (i -= 4) {
        const nibble = @as(u4, @truncate(@as(u8, @truncate(value >> @as(u5, @intCast(i))))));
        writeByte(hex_chars[nibble]);
    }
}

// Write a newline
pub fn nl() void {
    writeByte('\n');
    writeByte('\r');
}

// Format and write a debug frame: [magic][sys_id][opcode][payload_8B][newline]
pub fn debugFrame(sys_id: u8, opcode: u8, payload: u64) void {
    writeByte(0xDE); // Magic byte
    writeByte(sys_id);
    writeByte(opcode);
    writeByte(' ');
    writeHex64(payload);
    nl();
}

// Compact debug message: "[TAG] text"
pub fn debugMsg(comptime tag: []const u8, comptime text: []const u8) void {
    writeByte('[');
    writeStr(@as([*:0]const u8, @ptrCast(tag.ptr)));
    writeByte(']');
    writeByte(' ');
    writeStr(@as([*:0]const u8, @ptrCast(text.ptr)));
    nl();
}
