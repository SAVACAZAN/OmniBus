// pcie_driver.zig — Direct PCIe enumeration without kernel drivers
// x86-64 I/O port access via inline assembly

const types = @import("pcie_types.zig");

/// Write to I/O port (32-bit)
fn io_out32(port: u16, value: u32) void {
    asm volatile (
        "outl %[value], %[port]"
        :
        : [port] "Nd" (port),
          [value] "a" (value)
    );
}

/// Read from I/O port (32-bit)
fn io_in32(port: u16) u32 {
    var result: u32 = undefined;
    asm volatile (
        "inl %[port], %[result]"
        : [result] "=a" (result)
        : [port] "Nd" (port)
    );
    return result;
}

/// Create PCI address for config space access
/// Format: 1 << 31 | bus << 16 | dev << 11 | func << 8 | reg
fn pci_config_addr(bus: u8, dev: u8, func: u8, reg: u8) u32 {
    return (0x80000000) |
        (@as(u32, bus) << 16) |
        (@as(u32, dev) << 11) |
        (@as(u32, func) << 8) |
        @as(u32, reg);
}

/// Read 32-bit PCI config register
pub fn pci_read_register(bus: u8, dev: u8, func: u8, reg: u8) u32 {
    const addr = pci_config_addr(bus, dev, func, reg);
    io_out32(types.PCI_CONFIG_ADDR, addr);
    return io_in32(types.PCI_CONFIG_DATA);
}

/// Write 32-bit PCI config register
pub fn pci_write_register(bus: u8, dev: u8, func: u8, reg: u8, value: u32) void {
    const addr = pci_config_addr(bus, dev, func, reg);
    io_out32(types.PCI_CONFIG_ADDR, addr);
    io_out32(types.PCI_CONFIG_DATA, value);
}

/// Read BAR (Base Address Register)
pub fn pci_read_bar(bus: u8, dev: u8, func: u8, bar_index: u8) u64 {
    const reg_offset = types.PCI_REG_BAR0 + (bar_index * 4);
    const bar_low = pci_read_register(bus, dev, func, reg_offset);

    // Check if 64-bit BAR
    if ((bar_low & 0x04) != 0) {
        const bar_high = pci_read_register(bus, dev, func, reg_offset + 4);
        return (@as(u64, bar_high) << 32) | @as(u64, bar_low & 0xFFFFFFF0);
    }

    return bar_low & 0xFFFFFFF0;
}

/// Enumerate all PCI devices (bus 0 only for now)
pub fn pci_enumerate(devices: [*]types.PCIeDevice, max_devices: u32) u32 {
    var count: u32 = 0;

    var bus: u16 = 0;
    while (bus < 256 and count < max_devices) : (bus += 1) {
        var dev: u8 = 0;
        while (dev < 32 and count < max_devices) : (dev += 1) {
            var func: u8 = 0;
            while (func < 8 and count < max_devices) : (func += 1) {
                const vendor_id = pci_read_register(@as(u8, @intCast(bus)), dev, func, types.PCI_REG_DEVICE_ID) & 0xFFFF;

                // 0xFFFF = no device
                if (vendor_id == 0xFFFF) continue;

                const device = &devices[count];
                device.bus = @as(u8, @intCast(bus));
                device.dev = dev;
                device.func = func;

                device.vendor_id = vendor_id;
                device.device_id = (pci_read_register(@as(u8, @intCast(bus)), dev, func, types.PCI_REG_DEVICE_ID) >> 16) & 0xFFFF;
                device.class_code = (pci_read_register(@as(u8, @intCast(bus)), dev, func, types.PCI_REG_CLASS) >> 16) & 0xFF;

                // Read BARs
                device.bar0 = pci_read_bar(@as(u8, @intCast(bus)), dev, func, 0);
                device.bar1 = pci_read_bar(@as(u8, @intCast(bus)), dev, func, 1);
                device.bar2 = pci_read_bar(@as(u8, @intCast(bus)), dev, func, 2);
                device.bar3 = pci_read_bar(@as(u8, @intCast(bus)), dev, func, 3);
                device.bar4 = pci_read_bar(@as(u8, @intCast(bus)), dev, func, 4);
                device.bar5 = pci_read_bar(@as(u8, @intCast(bus)), dev, func, 5);

                // Read IRQ
                device.irq_line = @as(u8, @intCast(pci_read_register(@as(u8, @intCast(bus)), dev, func, 0x3C) & 0xFF));

                count += 1;
            }
        }
    }

    return count;
}

/// Enable memory and bus mastering on device
pub fn pci_enable_device(bus: u8, dev: u8, func: u8) void {
    const cmd = pci_read_register(bus, dev, func, types.PCI_REG_COMMAND);
    const new_cmd = cmd | 0x06;  // Bit 1 (Memory), Bit 2 (Bus Master)
    pci_write_register(bus, dev, func, types.PCI_REG_COMMAND, new_cmd);
}

/// Memory-mapped I/O write (32-bit)
pub fn mmio_write32(addr: u64, value: u32) void {
    const ptr = @as(*volatile u32, @ptrFromInt(addr));
    ptr.* = value;
}

/// Memory-mapped I/O read (32-bit)
pub fn mmio_read32(addr: u64) u32 {
    const ptr = @as(*volatile u32, @ptrFromInt(addr));
    return ptr.*;
}

/// Memory-mapped I/O write (64-bit)
pub fn mmio_write64(addr: u64, value: u64) void {
    const ptr = @as(*volatile u64, @ptrFromInt(addr));
    ptr.* = value;
}

/// Memory-mapped I/O read (64-bit)
pub fn mmio_read64(addr: u64) u64 {
    const ptr = @as(*volatile u64, @ptrFromInt(addr));
    return ptr.*;
}

/// Bulk memory copy from MMIO region
pub fn mmio_read_bulk(addr: u64, buf: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        buf[i] = @as(*volatile u8, @ptrFromInt(addr + i)).*;
    }
}

/// Bulk memory write to MMIO region
pub fn mmio_write_bulk(addr: u64, data: [*]const u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        @as(*volatile u8, @ptrFromInt(addr + i)).* = data[i];
    }
}
