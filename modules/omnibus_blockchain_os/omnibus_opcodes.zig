// omnibus_opcodes.zig – Opcode Dispatcher for OmniBus Smart Contracts
// Implements 256-entry opcode execution system (0x00–0xFF)
// Inspired by Bitcoin Script, extended for tokens + governance + PQC

const std = @import("std");

// Forward declarations to other OS modules
const pqc_bridge = @import("pqc_wallet_bridge.zig"); // PQ signing/keygen
// const token_os = @import("token_os.zig");    // Token operations
// const wallet_os = @import("wallet_os.zig");  // Wallet operations
// const dao_os = @import("dao_os.zig");        // DAO operations

// ============================================================================
// OPCODE DEFINITIONS (0x00–0xFF)
// ============================================================================

pub const Opcode = enum(u8) {
    // Stack Operations (0x00–0x0F)
    OP_PUSH0 = 0x00,
    OP_PUSH1 = 0x01,
    OP_PUSH2 = 0x02,
    OP_PUSH3 = 0x03,
    OP_PUSH4 = 0x04,
    OP_PUSH5 = 0x05,
    OP_PUSH6 = 0x06,
    OP_PUSH7 = 0x07,
    OP_PUSH8 = 0x08,
    OP_PUSH9 = 0x09,
    OP_PUSH10 = 0x0A,
    OP_PUSH11 = 0x0B,
    OP_PUSH12 = 0x0C,
    OP_PUSH13 = 0x0D,
    OP_PUSH14 = 0x0E,
    OP_PUSH15 = 0x0F,

    // Token Operations (0x10–0x1F)
    OP_TRANSFER = 0x10,
    OP_TOKEN_BALANCE = 0x11,
    OP_MINT = 0x12,
    OP_BURN = 0x13,
    OP_STAKE = 0x14,
    OP_UNSTAKE = 0x15,
    OP_CLAIM_REWARDS = 0x16,
    OP_AIRDROP_CLAIM = 0x17,
    OP_FAUCET = 0x18,
    OP_APPROVE = 0x19,
    OP_ALLOWANCE = 0x1A,

    // Wallet Operations (0x20–0x2F)
    OP_DERIVE_KEY = 0x20,
    OP_GET_ADDRESS = 0x21,
    OP_SIGN_TX = 0x22,
    OP_VERIFY_SIG = 0x23,
    OP_CREATE_WALLET = 0x24,
    OP_GET_BALANCE = 0x25,
    OP_RECOVER_KEY = 0x26,

    // Smart Contract Operations (0x30–0x3F)
    OP_CALL = 0x30,
    OP_STORE = 0x31,
    OP_LOAD = 0x32,
    OP_DELETE = 0x33,
    OP_GETSTATE = 0x34,
    OP_SETCODE = 0x35,
    OP_SELFDESTRUCT = 0x36,
    OP_GAS_REMAINING = 0x37,

    // DAO Governance Operations (0x40–0x4F)
    OP_PROPOSE = 0x40,
    OP_VOTE = 0x41,
    OP_EXECUTE = 0x42,
    OP_GET_PROPOSAL = 0x43,
    OP_TREASURY_SEND = 0x44,
    OP_TREASURY_BALANCE = 0x45,
    OP_GET_VOTING_POWER = 0x46,
    OP_DELEGATE = 0x47,

    // Network & Bridge Operations (0x50–0x5F)
    OP_BRIDGE_INIT = 0x50,
    OP_BRIDGE_CONFIRM = 0x51,
    OP_ADD_PEER = 0x52,
    OP_REMOVE_PEER = 0x53,
    OP_GET_PEER_COUNT = 0x54,
    OP_BROADCAST_BLOCK = 0x55,
    OP_ROUTE_TX = 0x56,
    OP_SYNC_BLOCKS = 0x57,

    // RPC State Operations (0x60–0x6F)
    OP_REGISTER_CLIENT = 0x60,
    OP_RECOGNIZE_CLIENT = 0x61,
    OP_AUTHENTICATE = 0x62,
    OP_CREATE_SESSION = 0x63,
    OP_VERIFY_SESSION = 0x64,
    OP_CHECK_RATE_LIMIT = 0x65,
    OP_RECORD_CALL = 0x66,
    OP_BAN_CLIENT = 0x67,

    // Cryptography Operations (0x70–0x7F)
    OP_SHA256 = 0x70,
    OP_KECCAK256 = 0x71,
    OP_RIPEMD160 = 0x72,
    OP_HMAC_SHA256 = 0x73,
    OP_VERIFY_SIGNATURE = 0x74,
    OP_KYBER_ENCAP = 0x75,
    OP_KYBER_DECAP = 0x76,
    OP_RECOVER_PUBKEY = 0x77,

    // Flow Control Operations (0x80–0x8F)
    OP_IF = 0x80,
    OP_ELSE = 0x81,
    OP_ENDIF = 0x82,
    OP_LOOP = 0x83,
    OP_BREAK = 0x84,
    OP_CONTINUE = 0x85,
    OP_VERIFY = 0x86,
    OP_JUMP = 0x87,
    OP_JUMPI = 0x88,
    OP_RETURN = 0x89,
    OP_REVERT = 0x8A,

    // Arithmetic Operations (0x90–0xAF)
    OP_ADD = 0x90,
    OP_SUB = 0x91,
    OP_MUL = 0x92,
    OP_DIV = 0x93,
    OP_MOD = 0x94,
    OP_POW = 0x95,
    OP_SQRT = 0x96,
    OP_ABS = 0x97,
    OP_NEG = 0x98,
    OP_INC = 0x99,
    OP_DEC = 0x9A,
    OP_MAX = 0x9B,
    OP_MIN = 0x9C,

    // Bitwise Operations (0xB0–0xCF)
    OP_AND = 0xB0,
    OP_OR = 0xB1,
    OP_XOR = 0xB2,
    OP_NOT = 0xB3,
    OP_SHL = 0xB4,
    OP_SHR = 0xB5,
    OP_ROTL = 0xB6,
    OP_ROTR = 0xB7,
    OP_POPCNT = 0xB8,
    OP_CLZ = 0xB9,

    // Comparison Operations (0xD0–0xDF)
    OP_EQ = 0xD0,
    OP_NE = 0xD1,
    OP_LT = 0xD2,
    OP_LE = 0xD3,
    OP_GT = 0xD4,
    OP_GE = 0xD5,
    OP_ISNEG = 0xD6,
    OP_ISZERO = 0xD7,

    // System Operations (0xF0–0xFF)
    OP_NOP = 0xF0,
    OP_HALT = 0xF1,
    OP_DEBUG = 0xF2,
    OP_TIMESTAMP = 0xF3,
    OP_BLOCKNUMBER = 0xF4,
    OP_BLOCKHASH = 0xF5,
    OP_GASLEFT = 0xF6,
    OP_CALLER = 0xF7,
    OP_ADDRESS = 0xF8,
    OP_BALANCE = 0xF9,
    OP_CODESIZE = 0xFA,
    OP_CODECOPY = 0xFB,
    OP_STATICCALL = 0xFC,
    OP_DELEGATECALL = 0xFD,
    OP_CREATE = 0xFE,
    OP_SELFDESTRUCT_IMPL = 0xFF,

    _,  // Allow other values
};

// ============================================================================
// EXECUTION CONTEXT
// ============================================================================

pub const ExecutionContext = struct {
    contract_address: u64,
    caller_client_id: u32,

    block_number: u64,
    block_timestamp: u64,

    gas_used: u64,
    gas_limit: u64,

    stack: [4096]u64 = undefined,  // 32KB stack
    stack_depth: u32 = 0,

    is_halted: u8 = 0,
    error_code: u32 = 0,
};

// ============================================================================
// OPCODE DISPATCHER
// ============================================================================

pub export fn execute_opcode(
    opcode: u8,
    context_ptr: u64,
    arg0: u64,
    arg1: u64,
    arg2: u64,
) u64 {
    const ctx = @as(*volatile ExecutionContext, @ptrFromInt(context_ptr));

    // Route to appropriate handler based on opcode
    return switch (opcode) {
        // Stack operations (0x00–0x0F)
        0x00 => op_push0(ctx),
        0x01...0x0F => op_push(ctx, opcode),

        // Token operations
        0x10 => op_transfer(ctx, arg0, arg1, arg2),
        0x11 => op_token_balance(ctx, arg0, arg1),
        0x12 => op_mint(ctx, arg0, arg1),
        0x13 => op_burn(ctx, arg0, arg1),
        0x14 => op_stake(ctx, arg0, arg1, arg2),
        0x15 => op_unstake(ctx, arg0, arg1),
        0x16 => op_claim_rewards(ctx, arg0),

        // Wallet + PQC operations (via pqc_wallet_bridge)
        // OP_DERIVE_KEY 0x20: arg0=PqWalletSlot ptr, arg1=domain(u8)
        // OP_SIGN_TX    0x22: arg0=tx_hash ptr (32B + domain byte), arg1=PqSignedTx out ptr
        // OP_VERIFY_SIG 0x23: arg0=PqSignedTx ptr
        0x20, 0x22, 0x23 => pqc_bridge.opcode_dispatch(opcode, arg0, arg1),

        // Arithmetic
        0x90 => op_add(ctx),
        0x91 => op_sub(ctx),
        0x92 => op_mul(ctx),
        0x93 => op_div(ctx),
        0x94 => op_mod(ctx),

        // Comparison
        0xD0 => op_eq(ctx),
        0xD1 => op_ne(ctx),
        0xD2 => op_lt(ctx),
        0xD3 => op_le(ctx),
        0xD4 => op_gt(ctx),
        0xD5 => op_ge(ctx),

        // System
        0xF0 => op_nop(ctx),
        0xF1 => op_halt(ctx),
        0xF3 => op_timestamp(ctx),
        0xF4 => op_blocknumber(ctx),
        0xF7 => op_caller(ctx),

        else => 0xFFFFFFFFFFFFFFFF,  // Invalid opcode
    };
}

// ============================================================================
// STACK OPERATIONS
// ============================================================================

fn op_push0(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = 0;
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_push(ctx: *volatile ExecutionContext, opcode: u8) u64 {
    if (ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = opcode;  // Push literal 1–15
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_dup(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth >= 4096 or ctx.stack_depth == 0) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_drop(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth == 0) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack_depth -= 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_swap(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const tmp = ctx.stack[ctx.stack_depth - 1];
    ctx.stack[ctx.stack_depth - 1] = ctx.stack[ctx.stack_depth - 2];
    ctx.stack[ctx.stack_depth - 2] = tmp;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_over(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2 or ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = ctx.stack[ctx.stack_depth - 2];
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_rot(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 3 or ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    const tmp = ctx.stack[ctx.stack_depth - 3];
    ctx.stack[ctx.stack_depth - 3] = ctx.stack[ctx.stack_depth - 2];
    ctx.stack[ctx.stack_depth - 2] = ctx.stack[ctx.stack_depth - 1];
    ctx.stack[ctx.stack_depth - 1] = tmp;
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

// ============================================================================
// TOKEN OPERATIONS (STUB IMPLEMENTATIONS)
// ============================================================================

fn op_transfer(ctx: *volatile ExecutionContext, from: u64, to: u64, amount: u64) u64 {
    _ = from;
    _ = to;
    _ = amount;
    ctx.gas_used +|= 3;
    // TODO: Call token system to perform transfer
    return 1;  // success
}

fn op_token_balance(ctx: *volatile ExecutionContext, address: u64, token_type: u64) u64 {
    _ = address;
    _ = token_type;
    ctx.gas_used +|= 2;
    // TODO: Call token system to get balance
    return 0;  // stub
}

fn op_mint(ctx: *volatile ExecutionContext, token_type: u64, amount: u64) u64 {
    _ = token_type;
    _ = amount;
    ctx.gas_used +|= 3;
    // TODO: Call token system to mint
    return 1;  // success
}

fn op_burn(ctx: *volatile ExecutionContext, token_type: u64, amount: u64) u64 {
    _ = token_type;
    _ = amount;
    ctx.gas_used +|= 3;
    // TODO: Call token system to burn
    return 1;  // success
}

fn op_stake(ctx: *volatile ExecutionContext, address: u64, amount: u64, days: u64) u64 {
    _ = address;
    _ = amount;
    _ = days;
    ctx.gas_used +|= 5;
    // TODO: Call distribution system to stake
    return 1;  // success
}

fn op_unstake(ctx: *volatile ExecutionContext, address: u64, stake_id: u64) u64 {
    _ = address;
    _ = stake_id;
    ctx.gas_used +|= 5;
    // TODO: Call distribution system to unstake
    return 0;  // amount
}

fn op_claim_rewards(ctx: *volatile ExecutionContext, address: u64) u64 {
    _ = address;
    ctx.gas_used +|= 5;
    // TODO: Call distribution system to claim
    return 0;  // amount
}

// ============================================================================
// ARITHMETIC OPERATIONS
// ============================================================================

fn op_add(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = a +| b;
    ctx.gas_used +|= 3;
    return 1;
}

fn op_sub(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = a -| b;
    ctx.gas_used +|= 3;
    return 1;
}

fn op_mul(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = a *| b;
    ctx.gas_used +|= 3;
    return 1;
}

fn op_div(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    if (b == 0) return 0xFFFFFFFFFFFFFFFF;  // Division by zero
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = a / b;
    ctx.gas_used +|= 3;
    return 1;
}

fn op_mod(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    if (b == 0) return 0xFFFFFFFFFFFFFFFF;  // Division by zero
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = a % b;
    ctx.gas_used +|= 3;
    return 1;
}

// ============================================================================
// COMPARISON OPERATIONS
// ============================================================================

fn op_eq(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = if (a == b) 1 else 0;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_ne(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = if (a != b) 1 else 0;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_lt(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = if (a < b) 1 else 0;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_le(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = if (a <= b) 1 else 0;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_gt(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = if (a > b) 1 else 0;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_ge(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth < 2) return 0xFFFFFFFFFFFFFFFF;
    const a = ctx.stack[ctx.stack_depth - 2];
    const b = ctx.stack[ctx.stack_depth - 1];
    ctx.stack_depth -= 1;
    ctx.stack[ctx.stack_depth - 1] = if (a >= b) 1 else 0;
    ctx.gas_used +|= 1;
    return 1;
}

// ============================================================================
// SYSTEM OPERATIONS
// ============================================================================

fn op_nop(ctx: *volatile ExecutionContext) u64 {
    ctx.gas_used +|= 1;
    return 1;
}

fn op_halt(ctx: *volatile ExecutionContext) u64 {
    ctx.is_halted = 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_timestamp(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = ctx.block_timestamp;
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_blocknumber(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = ctx.block_number;
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

fn op_caller(ctx: *volatile ExecutionContext) u64 {
    if (ctx.stack_depth >= 4096) return 0xFFFFFFFFFFFFFFFF;
    ctx.stack[ctx.stack_depth] = ctx.caller_client_id;
    ctx.stack_depth += 1;
    ctx.gas_used +|= 1;
    return 1;
}

// ============================================================================
// QUERY FUNCTIONS
// ============================================================================

pub export fn get_execution_context() u64 {
    // Return pointer to execution context (to be filled by caller)
    return 0;  // TODO: implement
}

pub export fn is_halted(ctx_ptr: u64) u8 {
    const ctx = @as(*volatile ExecutionContext, @ptrFromInt(ctx_ptr));
    return ctx.is_halted;
}

pub export fn get_stack_top(ctx_ptr: u64) u64 {
    const ctx = @as(*volatile ExecutionContext, @ptrFromInt(ctx_ptr));
    if (ctx.stack_depth == 0) return 0;
    return ctx.stack[ctx.stack_depth - 1];
}

pub export fn get_gas_used(ctx_ptr: u64) u64 {
    const ctx = @as(*volatile ExecutionContext, @ptrFromInt(ctx_ptr));
    return ctx.gas_used;
}
