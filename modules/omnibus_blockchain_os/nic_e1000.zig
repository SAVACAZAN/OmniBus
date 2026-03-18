// nic_e1000.zig – Intel E1000 (82540EM) NIC Driver – bare-metal / QEMU
//
// Locație memorie:
//   0x610000  NicState (metadata, MMIO base, counters)
//   0x611000  TX descriptor ring  (16 × 16B = 256B)
//   0x611100  RX descriptor ring  (16 × 16B = 256B)
//   0x612000  TX packet buffers   (16 × 2048B = 32KB)
//   0x622000  RX packet buffers   (16 × 2048B = 32KB)
//
// QEMU: -nic model=e1000  →  PCI vendor=0x8086 device=0x100E  (82540EM)
//
// Flux:
//   init() → PCI scan → BAR0 MMIO → reset → TX/RX rings → link up
//   send()  → scrie TxDesc → bump TDT → aşteaptă DD bit
//   recv()  → verifică RxDesc → citeşte buffer → bump RDT

// ============================================================================
// Constante
// ============================================================================

const PCI_CONFIG_ADDR: u16 = 0xCF8;
const PCI_CONFIG_DATA: u16 = 0xCFC;

const E1000_VENDOR: u16  = 0x8086;
const E1000_DEV_540: u16 = 0x100E;  // 82540EM  – QEMU default "-nic e1000"
const E1000_DEV_545: u16 = 0x100F;  // 82545EM

const TX_RING_SIZE: usize = 16;
const RX_RING_SIZE: usize = 16;
const PKT_BUF_SIZE: usize = 2048;

const NIC_STATE_BASE: usize = 0x610000;
const TX_DESC_BASE:   usize = 0x611000;
const RX_DESC_BASE:   usize = 0x611100;
const TX_BUF_BASE:    usize = 0x612000;
const RX_BUF_BASE:    usize = 0x622000;

// ============================================================================
// E1000 Register Offsets (faţă de MMIO base)
// ============================================================================

const REG_CTRL:   u32 = 0x0000;
const REG_STATUS: u32 = 0x0008;
const REG_ICR:    u32 = 0x00C0;
const REG_IMC:    u32 = 0x00D8;
const REG_RCTL:   u32 = 0x0100;
const REG_TCTL:   u32 = 0x0400;
const REG_TIPG:   u32 = 0x0410;
const REG_RDBAL:  u32 = 0x2800;
const REG_RDBAH:  u32 = 0x2804;
const REG_RDLEN:  u32 = 0x2808;
const REG_RDH:    u32 = 0x2810;
const REG_RDT:    u32 = 0x2818;
const REG_TDBAL:  u32 = 0x3800;
const REG_TDBAH:  u32 = 0x3804;
const REG_TDLEN:  u32 = 0x3808;
const REG_TDH:    u32 = 0x3810;
const REG_TDT:    u32 = 0x3818;
const REG_RAL0:   u32 = 0x5400;
const REG_RAH0:   u32 = 0x5404;
const REG_MTA:    u32 = 0x5200;  // Multicast table array (128 intrări × 4B)

// CTRL bits
const CTRL_RST:  u32 = 1 << 26;
const CTRL_SLU:  u32 = 1 << 6;   // Set Link Up
const CTRL_ASDE: u32 = 1 << 5;   // Auto-Speed Detect Enable

// RCTL bits
const RCTL_EN:    u32 = 1 << 1;
const RCTL_UPE:   u32 = 1 << 3;   // Unicast Promiscuous
const RCTL_MPE:   u32 = 1 << 4;   // Multicast Promiscuous
const RCTL_BAM:   u32 = 1 << 15;  // Broadcast Accept Mode
const RCTL_SECRC: u32 = 1 << 26;  // Strip CRC

// TCTL bits
const TCTL_EN:   u32 = 1 << 1;
const TCTL_PSP:  u32 = 1 << 3;          // Pad Short Packets
const TCTL_CT:   u32 = 0x0F << 4;       // Collision Threshold = 15
const TCTL_COLD: u32 = 0x3F << 12;      // Collision Distance = 63

// TX descriptor CMD bits
const TDESC_CMD_EOP:  u8 = 1 << 0;  // End Of Packet
const TDESC_CMD_IFCS: u8 = 1 << 1;  // Insert FCS/CRC
const TDESC_CMD_RS:   u8 = 1 << 3;  // Report Status

// TX/RX descriptor STATUS bits
const DESC_STA_DD:  u8 = 1 << 0;  // Descriptor Done
const DESC_STA_EOP: u8 = 1 << 1;  // End Of Packet (RX)

// ============================================================================
// Structuri (extern = layout C, fără padding)
// ============================================================================

const TxDesc = extern struct {
    buf_addr: u64,
    length:   u16,
    cso:      u8,
    cmd:      u8,
    status:   u8,
    css:      u8,
    special:  u16,
};

const RxDesc = extern struct {
    buf_addr: u64,
    length:   u16,
    checksum: u16,
    status:   u8,
    errors:   u8,
    special:  u16,
};

pub const NicState = extern struct {
    initialized: u8,
    link_up:     u8,
    _pad:        [2]u8,
    mmio_base:   u32,     // adresa MMIO a E1000 (din BAR0)
    tx_tail:     u32,     // indice curent TDT
    rx_tail:     u32,     // indice curent RDT
    mac:         [6]u8,   // adresa MAC a acestui nod
    _pad2:       [2]u8,
    tx_count:    u64,     // pachete trimise
    rx_count:    u64,     // pachete primite
    tx_errors:   u32,     // timeout TX
    rx_drops:    u32,     // buffer plin RX
};

// ============================================================================
// Accesor state (volatile – bare-metal)
// ============================================================================

fn getNicState() *volatile NicState {
    return @as(*volatile NicState, @ptrFromInt(NIC_STATE_BASE));
}

fn getTxRing() *volatile [TX_RING_SIZE]TxDesc {
    return @as(*volatile [TX_RING_SIZE]TxDesc, @ptrFromInt(TX_DESC_BASE));
}

fn getRxRing() *volatile [RX_RING_SIZE]RxDesc {
    return @as(*volatile [RX_RING_SIZE]RxDesc, @ptrFromInt(RX_DESC_BASE));
}

fn getTxBuf(idx: usize) [*]volatile u8 {
    return @as([*]volatile u8, @ptrFromInt(TX_BUF_BASE + idx * PKT_BUF_SIZE));
}

fn getRxBuf(idx: usize) [*]volatile u8 {
    return @as([*]volatile u8, @ptrFromInt(RX_BUF_BASE + idx * PKT_BUF_SIZE));
}

// ============================================================================
// I/O Port helpers (PCI config + ioport)
// ============================================================================

fn outl(port: u16, value: u32) void {
    asm volatile ("outl %[val], %[port]"
        :
        : [val] "{eax}" (value),
          [port] "{dx}" (port),
    );
}

fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[val]"
        : [val] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

// ============================================================================
// PCI config space
// ============================================================================

fn pci_cfg_addr(bus: u8, dev: u8, func: u8, reg: u8) u32 {
    return (1 << 31) |
           (@as(u32, bus)  << 16) |
           (@as(u32, dev)  << 11) |
           (@as(u32, func) << 8)  |
           (@as(u32, reg)  & 0xFC);
}

fn pci_read32(bus: u8, dev: u8, func: u8, reg: u8) u32 {
    outl(PCI_CONFIG_ADDR, pci_cfg_addr(bus, dev, func, reg));
    return inl(PCI_CONFIG_DATA);
}

fn pci_write32(bus: u8, dev: u8, func: u8, reg: u8, val: u32) void {
    outl(PCI_CONFIG_ADDR, pci_cfg_addr(bus, dev, func, reg));
    outl(PCI_CONFIG_DATA, val);
}

// ============================================================================
// MMIO register R/W (via MMIO base din NicState)
// ============================================================================

fn e1000_read(reg: u32) u32 {
    const base = @as(usize, getNicState().mmio_base);
    return @as(*volatile u32, @ptrFromInt(base + reg)).*;
}

fn e1000_write(reg: u32, val: u32) void {
    const base = @as(usize, getNicState().mmio_base);
    @as(*volatile u32, @ptrFromInt(base + reg)).* = val;
}

// Delay simplu (spin loop) – fără timer hardware
fn delay(n: u32) void {
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        asm volatile ("pause");
    }
}

// ============================================================================
// PCI scan – găsim E1000 pe bus 0
// ============================================================================

fn pci_find_e1000() bool {
    const s = getNicState();
    var dev: u8 = 0;
    while (dev < 32) : (dev += 1) {
        const id = pci_read32(0, dev, 0, 0x00);
        const vendor: u16 = @as(u16, @truncate(id));
        const device: u16 = @as(u16, @truncate(id >> 16));

        if (vendor != E1000_VENDOR) continue;
        if (device != E1000_DEV_540 and device != E1000_DEV_545) continue;

        // Găsit! Citeşte BAR0 (MMIO base address)
        const bar0 = pci_read32(0, dev, 0, 0x10);
        // BAR0 bit 0 = 0 → memory mapped; bit 1 = 0 → 32-bit
        s.mmio_base = bar0 & 0xFFFFFFF0;

        // Activăm Bus Master + Memory Space în PCI Command register
        const cmd = pci_read32(0, dev, 0, 0x04);
        pci_write32(0, dev, 0, 0x04, cmd | 0x06);  // bit1=MemSpace, bit2=BusMaster

        return true;
    }
    return false;
}

// ============================================================================
// Citim MAC din RAL0/RAH0 (setat de QEMU din MAC adresă)
// ============================================================================

fn read_mac() void {
    const s = getNicState();
    const ral = e1000_read(REG_RAL0);
    const rah = e1000_read(REG_RAH0);
    s.mac[0] = @as(u8, @truncate(ral));
    s.mac[1] = @as(u8, @truncate(ral >> 8));
    s.mac[2] = @as(u8, @truncate(ral >> 16));
    s.mac[3] = @as(u8, @truncate(ral >> 24));
    s.mac[4] = @as(u8, @truncate(rah));
    s.mac[5] = @as(u8, @truncate(rah >> 8));
}

// ============================================================================
// Iniţializare TX ring
// ============================================================================

fn init_tx_ring() void {
    const ring = getTxRing();

    // Iniţializăm descriptorii + buffer-ele
    var i: usize = 0;
    while (i < TX_RING_SIZE) : (i += 1) {
        ring[i].buf_addr = @as(u64, TX_BUF_BASE + i * PKT_BUF_SIZE);
        ring[i].length   = 0;
        ring[i].cso      = 0;
        ring[i].cmd      = 0;
        ring[i].status   = DESC_STA_DD;  // Liber de la început
        ring[i].css      = 0;
        ring[i].special  = 0;
    }

    // Configurăm registrele TX
    const base = @as(u64, TX_DESC_BASE);
    e1000_write(REG_TDBAL, @as(u32, @truncate(base)));
    e1000_write(REG_TDBAH, @as(u32, @truncate(base >> 32)));
    e1000_write(REG_TDLEN, TX_RING_SIZE * @sizeOf(TxDesc));
    e1000_write(REG_TDH, 0);
    e1000_write(REG_TDT, 0);

    // TCTL: Enable | Pad Short Packets | CT=15 | COLD=63
    e1000_write(REG_TCTL, TCTL_EN | TCTL_PSP | TCTL_CT | TCTL_COLD);

    // TIPG: Inter-packet gap standard (Intel 802.3)
    e1000_write(REG_TIPG, 0x0060200A);

    getNicState().tx_tail = 0;
}

// ============================================================================
// Iniţializare RX ring
// ============================================================================

fn init_rx_ring() void {
    const ring = getRxRing();

    var i: usize = 0;
    while (i < RX_RING_SIZE) : (i += 1) {
        ring[i].buf_addr = @as(u64, RX_BUF_BASE + i * PKT_BUF_SIZE);
        ring[i].length   = 0;
        ring[i].checksum = 0;
        ring[i].status   = 0;  // Hardware va seta DD când primeşte pachet
        ring[i].errors   = 0;
        ring[i].special  = 0;
    }

    // Configurăm registrele RX
    const base = @as(u64, RX_DESC_BASE);
    e1000_write(REG_RDBAL, @as(u32, @truncate(base)));
    e1000_write(REG_RDBAH, @as(u32, @truncate(base >> 32)));
    e1000_write(REG_RDLEN, RX_RING_SIZE * @sizeOf(RxDesc));
    e1000_write(REG_RDH, 0);
    e1000_write(REG_RDT, RX_RING_SIZE - 1);  // Tail la ultimul descriptor (toate disponibile)

    // RCTL: Enable | Promiscuous | Broadcast | SECRC | 2048B buffers
    e1000_write(REG_RCTL, RCTL_EN | RCTL_UPE | RCTL_MPE | RCTL_BAM | RCTL_SECRC);

    getNicState().rx_tail = 0;
}

// ============================================================================
// INIT – entry point public
// Returnează true dacă E1000 găsit şi iniţializat
// ============================================================================

pub fn init() bool {
    const s = getNicState();
    s.initialized = 0;
    s.link_up     = 0;
    s.tx_count    = 0;
    s.rx_count    = 0;
    s.tx_errors   = 0;
    s.rx_drops    = 0;

    // 1. PCI scan
    if (!pci_find_e1000()) return false;

    // 2. Software reset
    e1000_write(REG_CTRL, CTRL_RST);
    delay(100_000);

    // Dezactivăm toate întreruperile (le gestionăm prin polling)
    e1000_write(REG_IMC, 0xFFFFFFFF);
    _ = e1000_read(REG_ICR);  // Clear pending interrupts

    // 3. Link up
    const ctrl = e1000_read(REG_CTRL);
    e1000_write(REG_CTRL, ctrl | CTRL_SLU | CTRL_ASDE);

    // 4. Curăţăm Multicast Table Array
    var mta_idx: u32 = 0;
    while (mta_idx < 128) : (mta_idx += 1) {
        e1000_write(REG_MTA + mta_idx * 4, 0);
    }

    // 5. Citim MAC
    read_mac();

    // 6. TX + RX rings
    init_tx_ring();
    init_rx_ring();

    // 7. Verificăm link status
    delay(50_000);
    const status = e1000_read(REG_STATUS);
    s.link_up = @as(u8, @intCast(status & 2));  // bit 1 = LU (Link Up)

    s.initialized = 1;
    return true;
}

// ============================================================================
// SEND – trimite un pachet (max 2048B)
// Returnează true la succes
// ============================================================================

pub fn send(data: []const u8) bool {
    const s = getNicState();
    if (s.initialized == 0) return false;
    if (data.len == 0 or data.len > PKT_BUF_SIZE) return false;

    const ring = getTxRing();
    const tail = s.tx_tail % TX_RING_SIZE;

    // Verificăm că descriptorul e liber (DD bit set de hardware)
    if (ring[tail].status & DESC_STA_DD == 0) {
        s.tx_errors +|= 1;
        return false;
    }

    // Copiem datele în TX buffer
    const buf = getTxBuf(tail);
    var i: usize = 0;
    while (i < data.len) : (i += 1) {
        buf[i] = data[i];
    }

    // Configurăm descriptorul
    ring[tail].length = @as(u16, @intCast(data.len));
    ring[tail].cmd    = TDESC_CMD_EOP | TDESC_CMD_IFCS | TDESC_CMD_RS;
    ring[tail].status = 0;  // Ştergem DD – hardware va seta când termină

    // Avansăm TDT → hardware începe transmisia
    s.tx_tail = @as(u32, @intCast((tail + 1) % TX_RING_SIZE));
    e1000_write(REG_TDT, s.tx_tail);

    s.tx_count +|= 1;
    return true;
}

// ============================================================================
// RECV – primeşte un pachet (dacă disponibil)
// Returnează numărul de bytes primiţi (0 = nimic disponibil)
// ============================================================================

pub fn recv(buf: []u8) u16 {
    const s = getNicState();
    if (s.initialized == 0) return 0;

    const ring  = getRxRing();
    const tail  = s.rx_tail % RX_RING_SIZE;
    const entry = @as(usize, (tail + 1) % RX_RING_SIZE);

    // Verificăm descriptorul următor (head + 1)
    if (ring[entry].status & DESC_STA_DD == 0) return 0;  // Nu e nimic

    const pkt_len = ring[entry].length;
    if (pkt_len == 0 or pkt_len > PKT_BUF_SIZE) {
        // Reset descriptor + avansăm
        ring[entry].status = 0;
        s.rx_tail = @as(u32, @intCast(entry));
        e1000_write(REG_RDT, s.rx_tail);
        return 0;
    }

    // Copiem în buffer-ul apelantului
    const copy_len = @min(@as(usize, pkt_len), buf.len);
    const rx_buf   = getRxBuf(entry);
    var i: usize = 0;
    while (i < copy_len) : (i += 1) {
        buf[i] = rx_buf[i];
    }

    // Reset descriptor şi avansăm RDT → hardware poate reutiliza slotul
    ring[entry].status = 0;
    ring[entry].length = 0;
    s.rx_tail = @as(u32, @intCast(entry));
    e1000_write(REG_RDT, s.rx_tail);

    if (pkt_len > 0) s.rx_count +|= 1;

    return @as(u16, @intCast(copy_len));
}

// ============================================================================
// Status helpers
// ============================================================================

pub fn is_ready() bool {
    return getNicState().initialized != 0;
}

pub fn is_link_up() bool {
    if (getNicState().initialized == 0) return false;
    // Re-citim STATUS live
    const status = e1000_read(REG_STATUS);
    return status & 2 != 0;
}

pub fn get_mac() [6]u8 {
    return getNicState().mac;
}
