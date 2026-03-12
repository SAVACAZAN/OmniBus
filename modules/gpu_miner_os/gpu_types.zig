// gpu_types.zig — GPU Miner state and structures

pub const GPU_MINER_BASE: usize = 0x570000;
pub const MAX_GPUS: u32 = 8;

pub const GPUVendor = enum(u8) {
    nvidia = 0,
    amd = 1,
    intel = 2,
    unknown = 255,
};

pub const PoWAlgo = enum(u8) {
    sha256 = 0,
    scrypt = 1,
    ethash = 2,
    heavyhash = 3,
    blake3 = 4,
    keccak = 5,
};

pub const GPUDevice = extern struct {
    slot: u8 = 0,
    vendor: u8 = 0,
    model: [32]u8 = [_]u8{0} ** 32,
    memory_mb: u32 = 0,
    core_clock: u32 = 0,                // MHz
    memory_clock: u32 = 0,              // MHz

    bar0_addr: u64 = 0,                 // Register base
    bar1_addr: u64 = 0,                 // VRAM base

    hashes_computed: u64 = 0,
    hashes_found: u64 = 0,
    shares_submitted: u64 = 0,

    temperature: u8 = 0,
    power_draw: u16 = 0,               // Watts

    _pad: [22]u8 = [_]u8{0} ** 22,
};

pub const GPUMinerState = extern struct {
    magic: u32 = 0x474D494E,           // "GMIN"
    flags: u8 = 0,
    _pad1: [3]u8 = [_]u8{0} ** 3,

    cycle_count: u64 = 0,
    gpu_count: u8 = 0,
    active_gpus: u8 = 0,

    _pad2: [2]u8 = [_]u8{0} ** 2,

    current_algo: u8 = 0,              // PoWAlgo enum
    difficulty: u32 = 0,

    total_hashes: u64 = 0,
    total_shares: u64 = 0,
    total_valid_shares: u64 = 0,
    total_invalid_shares: u64 = 0,

    estimated_hashrate: u64 = 0,       // hashes/sec

    _pad3: [48]u8 = [_]u8{0} ** 48,
};

pub const GPU_DEVICES_BASE: usize = GPU_MINER_BASE + 0x100;
pub const GPU_DEVICE_SIZE: usize = 256;
