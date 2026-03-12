// asic_types.zig — ASIC Miner (Antminer, Whatsminer, etc.)

pub const ASIC_MINER_BASE: usize = 0x580000;
pub const MAX_ASICS: u32 = 4;

pub const ASICVendor = enum(u8) {
    bitmain = 0,           // Antminer
    microbt = 1,           // Whatsminer
    canaan = 2,            // Avalon
    ebang = 3,             // EBang
    unknown = 255,
};

pub const ASICModel = enum(u16) {
    antminer_s19_pro = 0x0001,
    antminer_s19j = 0x0002,
    whatsminer_m30s = 0x1001,
    whatsminer_m32 = 0x1002,
    avalon_a1166 = 0x2001,
    unknown = 0xFFFF,
};

pub const ASICDevice = extern struct {
    slot: u8 = 0,
    vendor: u8 = 0,
    model: u16 = 0,
    serial: [32]u8 = [_]u8{0} ** 32,

    uart_port: u16 = 0,                // UART I/O port
    i2c_bus: u8 = 0,

    core_count: u16 = 0,
    core_freq: u32 = 0,                // MHz

    hashes_computed: u64 = 0,
    hashes_found: u64 = 0,
    shares_submitted: u64 = 0,

    temperature: u8 = 0,
    power_draw: u16 = 0,               // Watts
    chip_status: u8 = 0,               // Healthy/Degraded

    _pad: [22]u8 = [_]u8{0} ** 22,
};

pub const ASICMinerState = extern struct {
    magic: u32 = 0x4153494D,           // "ASIM"
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    asic_count: u8 = 0,
    active_asics: u8 = 0,

    _pad2: [2]u8 = [_]u8{0} ** 2,

    difficulty: u32 = 0,

    total_hashes: u64 = 0,
    total_shares: u64 = 0,
    total_valid_shares: u64 = 0,
    total_invalid_shares: u64 = 0,

    estimated_hashrate: u64 = 0,

    _pad3: [48]u8 = [_]u8{0} ** 48,
};

pub const ASIC_DEVICES_BASE: usize = ASIC_MINER_BASE + 0x100;
pub const ASIC_DEVICE_SIZE: usize = 256;
