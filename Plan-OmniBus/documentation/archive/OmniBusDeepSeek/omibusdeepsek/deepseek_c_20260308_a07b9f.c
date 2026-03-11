// Opcodes suportați (prioritate pentru trading)
enum Opcode {
    STOP = 0x00,
    ADD = 0x01,
    MUL = 0x02,
    SUB = 0x03,
    DIV = 0x04,
    LT = 0x10,
    GT = 0x11,
    EQ = 0x14,
    PUSH1 = 0x60,
    PUSH32 = 0x7F,
    POP = 0x50,
    MLOAD = 0x51,
    MSTORE = 0x52,
    SLOAD = 0x54,
    SSTORE = 0x55,
    JUMP = 0x56,
    JUMPI = 0x57,
    CALL = 0xF1,  // Pentru flash loans
    RETURN = 0xF3
}