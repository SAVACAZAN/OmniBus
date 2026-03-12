// pcie_types.zig — Bare-metal PCIe enumeration and device access
// Direct hardware access without kernel drivers

pub const PCIeBus = u8;
pub const PCIeFunc = u8;
pub const PCIeSlot = u16;

/// PCI configuration space I/O ports
pub const PCI_CONFIG_ADDR = 0xCF8;
pub const PCI_CONFIG_DATA = 0xCFC;

/// PCI Register offsets
pub const PCI_REG_DEVICE_ID = 0x00;
pub const PCI_REG_COMMAND = 0x04;
pub const PCI_REG_STATUS = 0x06;
pub const PCI_REG_REVISION = 0x08;
pub const PCI_REG_CLASS = 0x0B;
pub const PCI_REG_BAR0 = 0x10;
pub const PCI_REG_BAR1 = 0x14;
pub const PCI_REG_BAR2 = 0x18;
pub const PCI_REG_BAR3 = 0x1C;
pub const PCI_REG_BAR4 = 0x20;
pub const PCI_REG_BAR5 = 0x24;

/// PCI device classes (for enumeration)
pub const PCI_CLASS_GPU = 0x03;          // Display controller
pub const PCI_CLASS_CRYPTO = 0x10;       // Encryption/Decryption

pub const PCIeDevice = extern struct {
    bus: u8,
    dev: u8,
    func: u8,
    _pad: u8 = 0,

    vendor_id: u16 = 0,
    device_id: u16 = 0,
    class_code: u8 = 0,

    bar0: u64 = 0,                  // Memory BAR
    bar1: u64 = 0,                  // I/O or Memory BAR
    bar2: u64 = 0,
    bar3: u64 = 0,
    bar4: u64 = 0,
    bar5: u64 = 0,

    irq_line: u8 = 0,
    irq_pin: u8 = 0,
    _pad2: [6]u8 = [_]u8{0} ** 6,
};

pub const PCIeConfig = extern struct {
    devices_found: u32 = 0,
    gpus_found: u32 = 0,
    asics_found: u32 = 0,
    _pad: [52]u8 = [_]u8{0} ** 52,
};
