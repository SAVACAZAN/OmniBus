# OmniBus Blockchain – Document Complet
**Versiune**: 3.0.0 (Phase 66)
**Data**: 2026-03-14
**Status**: Active Development – Core chain functional în bare-metal

---

## CUPRINS

1. [Ce Este OmniBus Blockchain](#1-ce-este-omnibus-blockchain)
2. [Arhitectura Generală](#2-arhitectura-generală)
3. [Module Implementate](#3-module-implementate--ce-am-construit)
4. [Ce Lipsește / TODO](#4-ce-lipseste--todo)
5. [Statistici & Parametri](#5-statistici--parametri)
6. [Tokenomics](#6-tokenomics)
7. [Adresare & Criptografie PQ](#7-adresare--criptografie-pq)
8. [Flux de Date End-to-End](#8-flux-de-date-end-to-end)
9. [Interconexiuni cu OmniBus Application](#9-interconexiuni-cu-omibus-application)
10. [Interconexiuni cu Alte Module](#10-interconexiuni-cu-alte-module)
11. [Harta Memoriei Bare-Metal](#11-harta-memoriei-bare-metal)
12. [Roadmap Viitor](#12-roadmap-viitor)

---

## 1. Ce Este OmniBus Blockchain

OmniBus Blockchain este **Layer 5** din arhitectura OmniBus – un blockchain propriu bare-metal, post-quantum, multi-domain, ancorat simultan pe Bitcoin/Ethereum/Solana/EGLD/Optimism/Base.

**Nu este un blockchain tradițional.** Rulează **fără OS**, direct pe hardware x86-64, controlând registrele CPU și memoria direct. Este integrat organic în sistemul de trading de înaltă frecvență al OmniBus, servind trei scopuri simultane:

1. **Settlement Layer** – confirmare finală pentru tranzacțiile de arbitraj
2. **Oracle Layer** – prețuri de piață agregate din 8 exchange-uri, PQ-semnate
3. **Identity Layer** – identitate permanentă a nodului bazată pe cheie post-quantum

**Viziunea pe termen lung**: Primul blockchain bare-metal cu latență sub-microsecundă, securitate post-quantum nativă și adresare la scara 1.46 octilioane de adrese, complet integrat cu un sistem de trading de înaltă frecvență.

---

## 2. Arhitectura Generală

```
┌─────────────────────────────────────────────────────────────────┐
│                    OmniBus Application (7 Layers)               │
├─────────────┬──────────────┬──────────────┬────────────────────┤
│  Layer 7    │  Layer 6     │  Layer 5     │  Layer 4           │
│  Neuro OS   │  Bank OS     │ BlockchainOS │  Execution OS      │
│  0x2D0000   │  0x280000    │  0x250000    │  0x130000          │
├─────────────┴──────────────┴──────┬───────┴────────────────────┤
│               Layer 3             │         Layer 2            │
│          Analytics OS             │         Grid OS            │
│            0x150000               │         0x110000           │
├───────────────────────────────────┴────────────────────────────┤
│                     Layer 1: Mother OS (Ada)                   │
│                          0x100000                              │
└─────────────────────────────────────────────────────────────────┘

OmniBus Blockchain (Layer 5) intern:
┌────────────────────────────────────────────────────────────────┐
│  ws_collector      → price pipeline 0.1s → 1s blocks           │
│  oracle_consensus  → Byzantine 4-of-6 quorum                   │
│  pqc_wallet_bridge → PQ semnături IPC @ 0x100110               │
│  omnibus_wallet    → HD wallet BIP-44, 5 domenii, 7 chain-uri  │
│  vid_shard_grid    → V-ID + 65,536 shard-uri + BHG gossip      │
│  node_identity     → identitate PQ permanentă (Fibonacci hash) │
│  p2p_node          → P2P UDP + BHG routing + broadcast         │
│  vault_storage     → persistență bare-metal (RAM-mapped disk)  │
│  omnibus_opcodes   → VM bytecode executor                      │
│  omnibus_blockchain_os → main loop + IPC coordination          │
└────────────────────────────────────────────────────────────────┘
```

---

## 3. Module Implementate – Ce Am Construit

### 3.1 `omnibus_blockchain_os.zig` – Main Loop & IPC Hub
**Stare**: ✅ Implementat complet

Fișierul principal care coordonează toate celelalte module. Expune interfața plugin pentru Mother OS (Layer 1).

**Funcții cheie**:
- `init_plugin()` – inițializează toate sub-modulele (wallet, ws_collector, oracle, vid_shard_grid)
- `run_blockchain_cycle()` – ciclu principal: verifică TSC, face tick 100ms, procesează blocuri, actualizează starea
- `inject_oracle_prices()` – primește prețuri de la Analytics OS și le injectează în ws_collector
- `execute_transaction()` – dispatcher pentru toate tipurile de tranzacții
- `get_state()` – returnează starea curentă a blockchain-ului

**TSC tick logic** (fără timer hardware):
```
TSC_PER_100MS = 300,000,000 (@ 3GHz)
Fiecare ~300M cicli → ws_collector.tick_100ms()
```

**Memorie**: 0x250000–0x27FFFF (192KB)

---

### 3.2 `pqc_wallet_bridge.zig` – Punte PQC ↔ Wallet
**Stare**: ✅ Implementat complet

Conectează wallet-ul HD cu `pqc_gate_os` prin IPC pe memorie partajată. Aceasta este inima securității post-quantum.

**Algoritmi suportați**:
| Algoritm | Standard NIST | Securitate | Utilizare |
|----------|---------------|------------|-----------|
| ML-DSA-44 (Dilithium-44) | FIPS 204 | Level 2 | OMNI/LOVE domains |
| ML-DSA-65 (Dilithium-65) | FIPS 204 | Level 3 | OMNI/LOVE domains |
| ML-DSA-87 (Dilithium-87) | FIPS 204 | Level 5 | RENT domain |
| FN-DSA-512 (Falcon-512) | FIPS 206 | Level 1 | FOOD domain (compact) |
| FN-DSA-1024 (Falcon-1024) | FIPS 206 | Level 5 | - |
| SLH-DSA-SHA2-128S (SPHINCS+) | FIPS 205 | Level 1 | VACATION domain (stateless) |
| SLH-DSA-256F (SPHINCS+) | FIPS 205 | Level 5 | - |

**Mapare domenii → algoritmi**:
```
OMNI    → ML_DSA_65
LOVE    → ML_DSA_65
FOOD    → FN_DSA_512
RENT    → ML_DSA_87  (cel mai puternic)
VACA    → SLH_DSA_SHA2_128S  (stateless)
```

**IPC Addresses**:
```
0x100110 = Opcode gate
0x100111 = Status
0x100120 = Result length
0x100200 = Signature output (max 4096B)
0x100300 = Public key output (max 2592B)
0x100400 = TX hash input (32B)
```

**Funcții cheie**: `keygen_for_domain()`, `sign_tx()`, `verify_tx()`, `opcode_dispatch()`, `keygen_all_domains()`

---

### 3.3 `omnibus_wallet.zig` – HD Wallet Multi-Chain Multi-Domain
**Stare**: ✅ Implementat + extins cu PQ

Wallet HD conform BIP-32/39/44, cu suport pentru 7 chain-uri și 5 domenii.

**Chain-uri suportate**: OMNIBUS, ETHEREUM, SOLANA, EGLD, BITCOIN, OPTIMISM, BASE

**Domenii**: OMNI, LOVE, FOOD, RENT, VACATION

**Path-uri BIP-44** (Coin Type 506 = OmniBus):
```
m/44'/506'/0'/0/0  → OMNI domain
m/44'/506'/1'/0/0  → LOVE domain
m/44'/506'/2'/0/0  → FOOD domain
m/44'/506'/3'/0/0  → RENT domain
m/44'/506'/4'/0/0  → VACATION domain
```

**Funcții cheie**: `init_wallet()`, `derive_key()`, `sign_transaction()`, `sign_transaction_pq()` (returnează PqSignedTx complet)

---

### 3.4 `ws_collector.zig` – Price Pipeline 0.1s → 1s
**Stare**: ✅ Implementat complet

Pipeline bare-metal de colectare prețuri din 8 exchange-uri, 50 token-uri.

**Arhitectura pipeline**:
```
NIC → price_feed_push() → Ring Buffer (0x5D9100)
                          ↓ fiecare 100ms
                     tick_100ms() → SubBlock
                          ↓ la 10 sub-blocuri
                     assemble_main_block() → MainBlock (1s)
                          ↓
                     oracle_consensus.commit_price_snapshot()
                          ↓
                     pqc_bridge.sign_tx(.RENT, merkle_root)
```

**Memoria**:
```
0x5D9000 = WsCollectorState (metadate)
0x5D9100 = Ring Buffer (256 intrări × ~80B = ~20KB)
0x5DB100 = MainBlock curent (10 × SubBlock)
```

**Algoritm median**:
- Colectează toate prețurile unui token pe durata unui sub-bloc (100ms)
- Sortare insertion sort (fără allocare)
- Median cu respingere outlieri ±1%
- Sub-bloc = 50 prețuri mediane per token (un preț per token per 100ms)

**Structuri**: `PriceFeedEntry`, `FeedRingHeader`, `SubBlock` (50 tokeni × median), `MainBlock` (10 sub-blocuri), `WsCollectorState`

---

### 3.5 `oracle_consensus.zig` – Byzantine Oracle Consensus
**Stare**: ✅ Implementat

Consensul 4-of-6 pentru prețuri Oracle. Validatorii semnează snapshot-urile de prețuri. Slashing pentru validatori care trimit date false.

**Parametri**:
- 6 validatori activi
- 4-of-6 quorum necesar
- Respingere abatere >1% față de median

---

### 3.6 `vid_shard_grid.zig` – V-ID + Grid + Gossip
**Stare**: ✅ Implementat complet

Sistemul de adresare scalabilă și rutare P2P.

**Variable-Length ID (V-ID)**:
| Prefix | Tip | Dimensiune | Capacitate |
|--------|-----|------------|------------|
| `00` | Short ID | 48 biți | 281 trilioane adrese |
| `01` | Full ID | 160 biți | 1.46 octilioane adrese |
| `10` | Extended | 96 biți | 79 sextilioane adrese |
| `11` | System | 16 biți | 16,384 adrese de sistem |

**Grid Sharding (din Full ID 160-bit)**:
```
Shard ID    = biți 0–15   (16b) → 65,536 shard-uri
Sector      = biți 16–79  (64b) → sectorizare internă
Local Addr  = biți 80–159 (80b) → adresă locală în shard
```

**Sparse Merkle Grid** (3 niveluri):
- Level 0: Bitmap 8KB @ 0x5E1000 (65,536 shard-uri, 1 bit/shard)
- Level 1: Hot Cache 64 shard-uri × 256 sectoare @ 0x5E3000
- Level 2: Cold Disk (via vault_storage)

**Binary Hyper-Gossip (BHG)**:
- Rutare XOR-metric (Kademlia-style)
- 16 hop-uri acoperă toți cei 65,536 shard-uri
- Header 64-bit: `[2b route_flag][16b origin][16b dest][6b TTL][24b payload_hash]`
- Pachete multi-slot: Single (256-bit, Short IDs) / Double (512-bit, Full IDs)

**Funcții cheie**: `make_short_id()`, `make_full_id()`, `gossip_next_hop()`, `gossip_route()`, `grid_init()`, `grid_register_address()`, `compute_sparse_merkle_root()`

---

### 3.7 `node_identity.zig` – Identitate Permanentă Nod
**Stare**: ✅ Implementat complet

Fiecare nod are o identitate permanentă derivată din cheia PQ.

**Derivare Shard ID** (Fibonacci hashing):
```
h = 0x6A09E667F3BCC908 (seed SHA-512)
Pentru fiecare byte din pubkey:
  h ^= byte × 0x9E3779B97F4A7C15  (Fibonacci constant)
  h = rotate_left(h, 13)
Shard ID = h & 0xFFFF
```

**Format fișier `identity.omni`** (stocat pe Sectorul 0):
```
[magic u32 = "OMNI"][version u16][shard_id u16]
[node_id u64 – Short ID 48-bit][pq_algo u8][flags u8][pad 2B]
[pubkey_len u32][pubkey 2592B – max Dilithium-5]
[created_tsc u64][last_seen u64]
[checksum u32 – CRC32]
```

**Tipuri de nod** (flags): VALIDATOR (0x01), LIGHT (0x02), MINER (0x04), ORACLE (0x08)

**Format adresă nativă**: `ob_d5_<14 hex chars>` (ex: `ob_d5_a3f2e1d4c5b6a7`)

**Memorie**: 0x602000 (4KB)

---

### 3.8 `p2p_node.zig` – P2P Network + Block Broadcast
**Stare**: ✅ Implementat complet

Nodul P2P cu rutare BHG, broadcast blocuri, heartbeat și deduplicare pachete.

**Structuri**:
- `PacketHeader` – magic (0x4F4D), type, shard_id, seq_num, checksum (FNV-1a)
- `P2PPacket` – header + payload (1024B)
- `PeerEntry` – shard_id, node_id, last_seen, tx/rx counters, latency
- `P2PNodeState` – max 64 peer-uri, ring buffer dedup 512 intrări

**Tipuri pachete**:
```
PKT_HEARTBEAT    = 0x01
PKT_BLOCK        = 0x02
PKT_TX           = 0x03
PKT_GOSSIP_ROUTE = 0x04
PKT_PRICE_UPDATE = 0x05
PKT_PEER_DISC    = 0x06
```

**Funcții cheie**: `init()`, `add_peer()`, `connect_seed_nodes()`, `broadcast_block()`, `receive_packet()`, `heartbeat()`, `run_cycle()`

**Memorie**: 0x603000 (P2PNodeState)

---

### 3.9 `vault_storage.zig` – Persistență Bare-Metal
**Stare**: ✅ Implementat complet

Scriere/citire directă pe sectoare NVMe/SATA fără filesystem. Emulat în RAM @ 0x700000 pentru QEMU.

**Layout disc** (sectoare de 512B):
```
Sector 0–5:   NodeIdentity (2592B + header = 6 sectoare)
Sector 6:     VaultHeader (bitmap sloturi wallet)
Sector 7–14:  WalletSlot 0 (8 sectoare × 512B = 4KB)
Sector 15–22: WalletSlot 1
...
Sector 7+N×8: WalletSlot N (max 16 sloturi)
Sector 135:   BlockRingHeader
Sector 136+:  BlockRing data (256 blocuri × 32 sectoare = 16KB/bloc)
```

**Ring buffer blocuri**: ultimele 256 blocuri stocate circular.

**Funcții cheie**: `save_identity()`, `load_identity()`, `save_wallet_slot()`, `load_wallet_slot()`, `save_pq_wallet()`, `load_pq_wallet()`, `save_block()`, `load_last_block()`

---

### 3.10 `omnibus_opcodes.zig` – VM Bytecode Executor
**Stare**: ✅ Implementat + bug-fix aplicat

Execută opcode-urile blockchain-ului OmniBus. Integrat cu PQC bridge.

**Opcode-uri implementate** (subset):
```
0x01: OP_TRANSFER          – transfer de tokeni
0x02: OP_DEPLOY_CONTRACT   – deploy smart contract
0x03: OP_CALL_CONTRACT     – apel contract
0x04: OP_STAKE             – staking
0x10: OP_CROSS_CHAIN_INIT  – inițiere bridge cross-chain
0x11: OP_TOKEN_BALANCE     – balanță token (fix: era duplicat cu 0xF9)
0x20: OP_FLASH_LOAN        – flash loan atomic
0x21: OP_ATOMIC_SWAP       – swap atomic
0x22: OP_DATA_COMMITMENT   – commit oracle data
0x23: OP_BATCH_TRANSFER    – batch transfer
0x20/22/23: → pqc_bridge.opcode_dispatch()  (PQ signing)
0xF9: OP_BALANCE           – balanță cont
0xFA: OP_KEYGEN            – generare cheie PQ
0xFB: OP_SIGN              – semnătură PQ
0xFC: OP_VERIFY            – verificare PQ
0xFE: OP_PANIC             – panic handler
0xFF: OP_HALT              – oprire VM
```

**Bug-uri fixate**:
- Eliminat import mort `rpc_state_types.zig` (fișier inexistent)
- Redenumit `OP_BALANCE=0x11` → `OP_TOKEN_BALANCE=0x11` (duplicat cu 0xF9)
- Eliminat bloc switch duplicat 0x11–0x15 care shadowa opcode-urile de token

---

### 3.11 Module Auxiliare în Director

| Fișier | Stare | Descriere |
|--------|-------|-----------|
| `binary_dictionary.zig` | ✅ Compilat | Short ID allocation dictionary |
| `genesis_block.zig` | ✅ Implementat | Genesis block generator |
| `omni_token.zig` | ✅ Implementat | Token OMNI + domain tokens |
| `omni_token_os.zig` | ✅ Implementat | Token OS layer |
| `token_distribution.zig` | ✅ Implementat | Distribuire tokeni (airdrop, staking) |
| `token_registry.zig` | ✅ Implementat | Registru tokeni |
| `miner_rewards.zig` | ✅ Implementat | Recompense mineri |
| `network_integration.zig` | ✅ Implementat | Integrare rețea |
| `blockchain_simulator.zig` | ✅ Test tool | Simulator blockchain |
| `blockchain_test_runner.zig` | ✅ Test tool | Runner teste |
| `id_conflict_resolver.zig` | ✅ Compilat | Rezolvare conflicte ID |
| `libc_stubs.asm` | ✅ Bare-metal | Stub-uri pentru libc (bare-metal) |
| `omnibus_blockchain.zig` | ✅ Entry point | Entry point principal |

---

## 4. Ce Lipsește / TODO

### 4.1 Critic (Fără Acestea Nu Merge în Producție)

| Prioritate | Modul | Descriere |
|------------|-------|-----------|
| 🔴 P0 | `real_nic_driver.zig` | NIC TX/RX real (acum: stub la 0x140000). Necesită driver E1000/RTL8169 sau VIRTIO pentru QEMU |
| 🔴 P0 | `ahci_driver.zig` | Driver AHCI real pentru NVMe/SATA (acum: RAM-mapped disk @ 0x700000) |
| 🔴 P0 | `vault_storage` → `run_blockchain_cycle()` | `save_block()` nu e apelat în main loop după fiecare bloc confirmat |
| 🔴 P0 | `cross_chain_bridge.zig` | Bridge real BTC/ETH/SOL/EGLD/OP/BASE (acum: stub opcode) |

### 4.2 Important (Funcționalitate Incompletă)

| Prioritate | Modul | Descriere |
|------------|-------|-----------|
| 🟡 P1 | `client_bridge.zig` | Light node Windows/Linux (pentru utilizatorii finali fără bare-metal) |
| 🟡 P1 | `binary_dictionary` ↔ `vid_shard_grid` | Conectarea alocarii Short ID din binary_dictionary cu shard grid-ul V-ID |
| 🟡 P1 | Smart Contract VM | VM-ul de opcode-uri definit în spec (0x00–0x7F) nu e complet implementat |
| 🟡 P1 | `key_rotation.zig` (modules/) | Key rotation PQ (opcode 0x0B) definit în spec |
| 🟡 P1 | `slashing_protection` | Slashing oracle complet + validator ejection |
| 🟡 P2 | `governance.zig` | Proposals DAO (opcode 0x0C) |

### 4.3 Îmbunătățiri / Nice-to-Have

| Prioritate | Descriere |
|------------|-----------|
| 🟢 P3 | Anchor real pe BTC/ETH (OP_RETURN / event log) |
| 🟢 P3 | Mempool persistent (acum: tranzacții pierdute la reboot) |
| 🟢 P3 | Sync protocol – nodul nou nu știe să descarce chain-ul complet |
| 🟢 P3 | GDB debug helpers pentru QEMU (symbol table în build) |
| 🟢 P3 | Testnet faucet backend (definit în spec, neimplementat) |

---

## 5. Statistici & Parametri

### 5.1 Parametri Blockchain

| Parametru | Valoare | Note |
|-----------|---------|------|
| Block Time | 10 secunde | PoW SHA-256d |
| Sub-bloc | 100ms | Price aggregation tick |
| TPS target | 1,000 | Batch + sharding |
| Finality | 60 sec (6 blocuri) | Confirmation depth |
| Max TX/bloc | 1,024 | |
| Difficulty adjust | La fiecare 10 blocuri | Auto-adjust |
| Cross-chain anchor | La fiecare 100 blocuri | → BTC/ETH/SOL/EGLD/OP/BASE |

### 5.2 Capacitate de Adresare

| Tip ID | Biți | Capacitate |
|--------|------|------------|
| Short ID | 48b | 281,474,976,710,656 (281 trilioane) |
| Extended | 96b | 79,228,162,514,264,337,593,543,950,336 (79 sextilioane) |
| Full ID | 160b | 1,461,501,637,330,902,918,203,684,832,716,283,019,655,932,542,976 (1.46 octilioane) |
| Grid Shards | 16b | 65,536 shard-uri |

### 5.3 Latență (Bare-Metal @ 3GHz)

| Operație | Latență estimată |
|----------|-----------------|
| Sub-bloc tick (TSC) | ~100ms ± 1% |
| PQ sign (Dilithium-87) | ~500μs – 2ms (via IPC) |
| Block assembly | <1ms |
| BHG gossip (16 hops) | <100ms (rețea locală) |
| Merkle root compute | <50μs (64 shard-uri hot cache) |

### 5.4 Memorie Folosită (Blockchain Layer)

| Segment | Adresă | Dimensiune | Utilizare |
|---------|--------|------------|-----------|
| BlockchainOS | 0x250000 | 192KB | Main state + IPC |
| ws_collector state | 0x5D9000 | 4KB | Collector metadata |
| ws_collector ring | 0x5D9100 | ~20KB | Price ring buffer |
| ws_collector block | 0x5DB100 | ~8KB | MainBlock curent |
| ShardGridState | 0x5E0000 | 4KB | Grid metadata |
| Shard Bitmap | 0x5E1000 | 8KB | 65,536 biți |
| Hot Cache | 0x5E3000 | 64KB | 64 shards × 256 sectors |
| GossipState | 0x5F3000 | 8KB | Peers + routing |
| NodeIdentity | 0x602000 | 4KB | Identitate nod |
| P2PNodeState | 0x603000 | 8KB | Peers P2P |
| Disk RAM-map | 0x700000 | 8MB | Emulare disc QEMU |
| **Total** | | **~8.5MB** | |

### 5.5 Criptografie – Dimensiuni

| Algoritm | Cheie Publică | Semnătură | Domeniu |
|----------|---------------|-----------|---------|
| ML-DSA-65 | 1,952 B | 3,293 B | OMNI/LOVE |
| ML-DSA-87 | 2,592 B | 4,595 B | RENT |
| FN-DSA-512 | 897 B | 666 B | FOOD |
| SLH-DSA-128S | 32 B | 7,856 B | VACATION |

---

## 6. Tokenomics

### 6.1 Token OMNI (Fixed Supply)

```
Supply fix: 21,000,000 OMNI (ca Bitcoin)
Smallest unit: 1 SAT = 0.00000001 OMNI

Distribuire Genesis:
├─ Community Airdrop:     10,500,000 OMNI (50%)
├─ Foundation Treasury:    4,200,000 OMNI (20%)
├─ Core Team/Dev:          3,150,000 OMNI (15%)
├─ Early Investors:        2,100,000 OMNI (10%)
└─ Reserves (locked):      1,050,000 OMNI  (5%)

Block Reward Year 1: 50 OMNI/bloc
Halving: La fiecare 210,000 blocuri (ca Bitcoin)
```

### 6.2 Tokeni Domain (Elastic Supply)

| Token | Simbol | Supply Inițial | Inflație anuală | Utilizare |
|-------|--------|---------------|-----------------|-----------|
| OMNI-LOVE | ΩLOVE | 2,100,000 | 5% | Romance/social dApps |
| OMNI-FOOD | ΩFOOD | 2,100,000 | 5% | Agricultură/supply chain |
| OMNI-RENT | ΩRENT | 2,100,000 | 5% | Real estate/housing |
| OMNI-VACA | ΩVACA | 2,100,000 | 5% | Travel/leisure |

**Rată de schimb**: 1 OMNI = 1 ΩLOVE = 1 ΩFOOD = 1 ΩRENT = 1 ΩVACA (atomic swap)

### 6.3 Distribuția Fee-urilor per Bloc

```
Fee total per bloc:
├─ 50% → Block Proposer (mining reward)
├─ 30% → OMNI staking pool (validatori delegați)
├─ 15% → Bridge validator set
└─ 5%  → Treasury (fond governance)
```

### 6.4 Gas Pricing

| Operație | Gas Base | Per-Byte |
|----------|----------|---------|
| Transfer | 21,000 | 16 |
| Contract Deploy | 100,000 | 200 |
| Contract Call | 50,000 | 100 |
| Cross-Chain Init | 30,000 | 50 |
| Flash Loan | 25,000 | 32 |

**1 Gas Unit = 1 SAT**

---

## 7. Adresare & Criptografie PQ

### 7.1 Format Adresă OmniBus

```
Address = <domain_prefix 1B><pubkey_hash 32B><checksum 4B>
Total: 37 bytes = 74 caractere hex

Domain Prefix:
  0x0 = OMNI (main chain)
  0x1 = LOVE domain
  0x2 = FOOD domain
  0x3 = RENT domain
  0x4 = VACA domain

Exemplu: 0x0a1f2e3d4c5b6a7f8e9d0c1b2a3f4e5d6c7b8a9f
```

### 7.2 Adresă Nativă Nod

```
Format: ob_d5_<14 hex chars>
Exemplu: ob_d5_a3f2e1d4c5b6a7
Derivată din: primii 7 bytes ai cheii publice PQ
```

### 7.3 BIP-44 Path-uri

```
Coin Type 506 (OmniBus)
m/44'/506'/0'/0/0  → OMNI account 0, address 0
m/44'/506'/1'/0/0  → LOVE domain
m/44'/506'/2'/0/0  → FOOD domain
m/44'/506'/3'/0/0  → RENT domain
m/44'/506'/4'/0/0  → VACATION domain
```

### 7.4 Tipuri Tranzacții

| Opcode | Tip | Descriere |
|--------|-----|-----------|
| 0x01 | Transfer | Token OMNI/domain transfer |
| 0x02 | Deploy | Smart contract deploy |
| 0x03 | Call | Smart contract call |
| 0x04 | Liquidity Pool | DEX liquidity |
| 0x05 | Staking Vault | Staking |
| 0x06 | Governance | Proposal DAO |
| 0x07 | NFT Mint | NFT minting |
| 0x08 | Oracle Feed | Price feed commit |
| 0x09 | Futures | Derivatives |
| 0x0A | Domain Anchor | Anchor domain la chain extern |
| 0x0B | Key Rotation | Rotație cheie PQ |
| 0x0C | Governance Proposal | Propunere modificare protocol |
| 0x10 | Bridge Init | Inițiere cross-chain transfer |
| 0x11 | Bridge Confirm | Confirmare bridge (3-of-5) |
| 0x20 | Flash Loan | Împrumut atomic în aceeași tranzacție |
| 0x21 | Atomic Swap | Swap atomic (2 părți) |
| 0x22 | Data Commitment | Oracle data commit |
| 0x23 | Batch Transfer | Până la 100 transferuri/TX |

---

## 8. Flux de Date End-to-End

### 8.1 Price Collection → Block → Broadcast

```
1. ws_collector.price_feed_push(token_id, price, exchange_id)
   ↓ scriere în ring buffer @ 0x5D9100
2. rdtsc() check → fiecare ~300M cicli
   ↓ ws_collector.tick_100ms()
3. SubBlock: median(prețuri per token) cu outlier rejection ±1%
   ↓ la 10 sub-blocuri (1 secundă)
4. assemble_main_block() → MainBlock cu 10 sub-blocuri
   ↓
5. oracle_consensus.commit_price_snapshot(block_data, block_len)
   ↓ Byzantine 4-of-6 quorum
6. pqc_bridge.sign_tx(.RENT, merkle_root)
   ↓ IPC @ 0x100110 → pqc_gate_os → ML-DSA-87
7. p2p_node.broadcast_block(signed_block)
   ↓ BHG gossip routing
8. Vecini → verifică semnătură PQ → propagă mai departe
9. vault_storage.save_block(height, merkle_root, consensus_hash)
   ↓ scriere sector disc @ 0x700000
```

### 8.2 Tranzacție Utilizator

```
1. User → tx = HDWallet.sign_transaction_pq(domain, tx_hash)
   ↓ derivă cheie BIP-44 → pqc_bridge.sign_tx()
2. p2p_node.broadcast_tx(tx)
   ↓ propagă prin gossip
3. Validator → oracle_consensus validează prețul (dacă TX are oracle data)
4. omnibus_opcodes.execute_opcode(opcode, arg0, arg1)
5. Block producer include TX în bloc
6. 6 blocuri confirmă → finality
```

### 8.3 Cross-Chain Anchor (la fiecare 100 blocuri)

```
Block 100n → merkle_root calculat
           → BridgeInitTx (0x10) creat
           → Semnat PQ (Dilithium-87)
           → Trimis la anchor chain (BTC OP_RETURN / ETH event / SOL memo)
           → 3-of-5 validator signatures (BridgeConfirmTx 0x11)
           → Finality cross-chain
```

---

## 9. Interconexiuni cu OmniBus Application

OmniBus Blockchain (Layer 5) este profund integrat cu celelalte 6 layer-uri ale aplicației.

### 9.1 → Layer 1: Ada Mother OS (0x100000)

**Relație**: Mother OS validează FIECARE request cross-segment al Blockchain OS.

**Protocol**:
```
1. Blockchain OS scrie request la 0x130000 (Execution OS buffer)
2. Setează flag la 0x100050 (Ada auth gate)
3. Ada validează: bounds check, permisiuni, buffer overflow
4. Ada setează response flag
5. Blockchain OS citește răspunsul
```

**Ce validează Ada**:
- Orice scriere în afara segmentului 0x250000–0x27FFFF → SYS_PANIC
- Orice apel IPC la pqc_gate (0x100110) trece prin Ada
- Execuția opcode-urilor malițioase → reject

**Fișier relevant**: `modules/ada_mother_os/`

---

### 9.2 → Layer 2: Grid OS (0x110000)

**Relație**: Grid OS furnizează prețuri de trading (mid-price pe pair-uri), blockchain-ul le consumă ca oracle data.

**Protocol**:
```
Grid OS scrie: prețuri pair-uri @ shared buffer (ex: 0x160000)
Blockchain OS: inject_oracle_prices() → ws_collector.price_feed_push()
```

**Ce primește**:
- `(token_id: u16, price: u64, exchange_id: u8)` per pair
- Perechi: BTC/USDT, ETH/USDT, SOL/USDT, EGLD/USDT, OMNI/USDT etc.

**Fișier relevant**: `modules/grid_os/`

---

### 9.3 → Layer 3: Analytics OS (0x150000)

**Relație**: Analytics OS agregează prețuri din multiple exchange-uri. Blockchain-ul consumă output-ul final.

**Protocol**:
```
Analytics OS:
  - Calculează prețul mediu ponderat (VWAP) din 8 exchange-uri
  - Detectează anomalii de preț (±3% față de median)
  - Scrie în shared buffer la 0x1C0000

Blockchain OS:
  - run_blockchain_cycle() → inject_oracle_prices()
  - Citește VWAP-urile și le trimite în ws_collector
```

**Ce furnizează blockchain-ul înapoi**:
- Prețuri mediane oficiale (blocurile Oracle confirmate)
- Hash-uri de blocuri pentru verificare istorică

**Fișier relevant**: `modules/analytics_os/`

---

### 9.4 → Layer 4: Execution OS (0x130000)

**Relație**: Execution OS trimite tranzacțiile de trading spre Blockchain OS pentru settlement final.

**Protocol**:
```
Execution OS:
  - Execută ordinele de arbitraj pe CEX-uri
  - Calculează profit/pierdere
  - Trimite settlement TX: (from, to, amount, token, nonce)

Blockchain OS:
  - Primește TX via IPC
  - execute_transaction() → validate → include în mempool
  - La confirmare (6 blocuri) → finality pentru settlement
```

**Important**: Execution OS NU are voie să cheme direct blockchain-ul. Trece prin Ada (0x100050).

**Fișier relevant**: `modules/execution_os/`

---

### 9.5 → Layer 6: Bank OS (0x280000)

**Relație**: Bank OS trimite mesaje SWIFT/ACH pentru settlement bancar. Blockchain-ul furnizează dovezi criptografice.

**Protocol**:
```
Blockchain OS → Bank OS:
  - Hash bloc confirmat (pentru audit trail)
  - Suma totală în OMNI de convertit în fiat
  - Merkle proof pentru tranzacția specifică

Bank OS → Blockchain OS:
  - Confirmare bancară → emite WrappedFiat token pe blockchain
  - SWIFT MT103 message hash → stocat în oracle data
```

**Fișier relevant**: `modules/bank_os/`

---

### 9.6 → Layer 7: Neuro OS (0x2D0000)

**Relație**: Neuro OS optimizează parametrii de trading via algoritm genetic. Blockchain-ul furnizează date istorice.

**Protocol**:
```
Blockchain OS → Neuro OS:
  - Ultimele N blocuri de prețuri (via load_last_block)
  - Statistici oracle: token, median_price, timestamp

Neuro OS → Blockchain OS:
  - Parametrii optimizați: fee_priority, gas_price_adjustment
  - Prediction: preț estimat la block+10
```

**Fișier relevant**: `modules/neuro_os/`

---

## 10. Interconexiuni cu Alte Module

### 10.1 → `pqc_gate_os` – Post-Quantum Crypto Gate

**Relație**: CRITICĂ. Toate semnăturile PQ trec prin acest modul.

**Protocol IPC**:
```
Blockchain scrie:   opcode @ 0x100110 (0x01=keygen, 0x02=sign, 0x03=verify)
                    param  @ 0x100115
                    hash   @ 0x100400 (pentru sign)
pqc_gate execută:   algoritmul NIST (liboqs)
                    scrie result @ 0x100120
                    semnătură   @ 0x100200
                    pubkey      @ 0x100300
```

**Fișier relevant**: `modules/pqc_gate_os/`, `modules/pqc_wallet_bridge.zig`

---

### 10.2 → `quantum_resistant_crypto_os`

**Relație**: Verificare suplimentară PQ pentru blocuri primite. Double-check independent față de pqc_gate.

**Utilizare**: Validatorii verifică semnăturile PQ ale blocurilor primite prin P2P.

**Fișier relevant**: `modules/quantum_resistant_crypto_os/`

---

### 10.3 → `omnibus_network_os`

**Relație**: Furnizează primitives de rețea pentru p2p_node.zig.

**Ce folosește blockchain-ul**:
- NIC TX buffer (acum: stub la 0x140000+peer×1120)
- Packet routing primitives
- UDP send/recv abstracție

**TODO**: Înlocuiește stub-ul cu apeluri reale la `omnibus_network_os`.

**Fișier relevant**: `modules/omnibus_network_os/`

---

### 10.4 → `cross_chain_bridge_os`

**Relație**: Implementează bridge-urile BTC/ETH/SOL/EGLD/OP/BASE menționate în spec.

**Ce furnizează blockchain-ul**:
- Merkle root per 100 blocuri (pentru anchor)
- Opcode 0x10/0x11 handler (BridgeInit/Confirm)

**Ce primește**:
- Confirmare anchor de pe chain-ul extern
- Locked funds status

**Fișier relevant**: `modules/cross_chain_bridge_os/`

---

### 10.5 → `dao_governance_os`

**Relație**: Implementează voting-ul pe opcode 0x0C/0x06 (GovernanceTx/GovernanceProposal).

**Protocol**:
```
Blockchain: emite GovernanceTx cu proposal_hash
dao_governance: colectează voturi (1 OMNI = 1 vot, staked = 1.5x)
                contabilizează quorum (3 zile discuție + 7 zile vot)
Blockchain: execută decizia la finality
```

**Fișier relevant**: `modules/dao_governance_os/`

---

### 10.6 → `consensus_engine_os`

**Relație**: Motor de consens extern pentru validatorii PoS (100-200 activi).

**Utilizare**: Slashing detectare, validator rotation la fiecare 1,000 blocuri, staking rewards calcul.

**Fișier relevant**: `modules/consensus_engine_os/`

---

### 10.7 → `mev_guard_os` / `stealth_os`

**Relație**: Protecție MEV (Miner Extractable Value) pentru tranzacțiile de arbitraj.

**Ce face blockchain-ul**:
- Marchează TX ca `STEALTH` dacă vine de la Execution OS cu flag MEV_PROTECT
- stealth_os randomizează ordinea TX în mempool pentru a preveni front-running

**Fișier relevant**: `modules/mev_guard_os/`, `modules/stealth_os/`

---

### 10.8 → `liquid_staking_os`

**Relație**: Staking lichid pentru OMNI. Emite stOMNI (staked OMNI) tokens.

**Protocol**:
```
User: stake_tx(amount=1000, lock=180days)
liquid_staking_os: emite 1000 stOMNI
                   calculează APY (10-20%)
Blockchain: înregistrează în state: staked_balances[addr] += amount
            la epoch end (1000 blocuri): distribute rewards
```

**Fișier relevant**: `modules/liquid_staking_os/`

---

### 10.9 → `rpc_state_os`

**Relație**: Expune starea blockchain-ului către clienți externi (light nodes, mobile).

**Endpoint-uri**: getBlock, getTransaction, getBalance, getOraclePrice

**Fișier relevant**: `modules/rpc_state_os/`

---

### 10.10 → `status_token_os` / `status_token_distribution`

**Relație**: Sistemul de tokeni de status (reward pentru activitate în rețea).

**Protocol**:
```
Utilizator activ (tranzacții, validare, oracle) → primește STATUS tokens
status_token_os: calculează scorul de activitate
blockchain: înregistrează distribuirile în state
```

**Fișier relevant**: `modules/status_token_os/`, `modules/status_token_distribution/`

---

### 10.11 → `agent_omni_sales`

**Relație**: Agentul OMNI de sales (Phase 66) care monetizează ecosistemul.

**Ce primește de la blockchain**:
- Prețuri OMNI în timp real
- Statistici tranzacții
- Balances pentru verificare eligibilitate

**Fișier relevant**: `modules/agent_omni_sales/`

---

### 10.12 → `zk_rollups_os`

**Relație**: ZK Rollup layer pentru scalabilitate. Agregează mii de TX într-un singur ZK proof.

**Protocol**:
```
zk_rollups_os: procesează batch de TX off-chain
               generează ZK proof (Groth16/PLONK)
blockchain: verifică proof (opcode viitor)
            include batch în bloc principal
```

**Fișier relevant**: `modules/zk_rollups_os/`

---

## 11. Harta Memoriei Bare-Metal

```
Adresă         Dimensiune   Modul
─────────────────────────────────────────────────────
0x000000       64KB         BIOS / Real Mode Area
0x010000       640KB        Kernel 32-bit (protected mode)
0x100000       64KB         Ada Mother OS (Layer 1)
  0x100050                  Auth gate (request flag)
  0x100110                  PQC IPC opcode
  0x100115                  PQC IPC param
  0x100120                  PQC IPC result len
  0x100200                  PQC signature output (4096B)
  0x100300                  PQC pubkey output (2592B)
  0x100400                  TX hash input (32B)
0x110000       128KB        Grid OS (Layer 2)
0x130000       128KB        Execution OS (Layer 4)
0x150000       256KB        Analytics OS (Layer 3)
0x200000       64KB         Paging Tables
0x250000       192KB        BlockchainOS (Layer 5) ← NOUL NOSTRU
0x280000       192KB        Bank OS (Layer 6)
0x2C0000       128KB        Stealth OS
0x2D0000       512KB        Neuro OS (Layer 7)
0x350000+      1MB+         Plugin Segment
─────────────────────────────────────────────────────
Blockchain intern (dincolo de segment principal):
0x5D9000       4KB          WsCollector state
0x5D9100       ~20KB        Price ring buffer
0x5DB100       ~8KB         MainBlock curent
0x5E0000       4KB          ShardGridState
0x5E1000       8KB          Shard Bitmap (65,536 bits)
0x5E3000       64KB         Hot Shard Cache (64×256 sectors)
0x5F3000       8KB          GossipState (peers routing)
0x602000       4KB          NodeIdentity
0x603000       8KB          P2PNodeState
0x700000       8MB          RAM-Mapped Disk (QEMU)
─────────────────────────────────────────────────────
```

---

## 12. Roadmap Viitor

### Phase 66 (Acum – Q1 2026) ✅ Aproape complet
- [x] Core chain (blockchain_os, opcodes, wallet)
- [x] PQ cryptography (pqc_wallet_bridge + pqc_gate)
- [x] Price oracle pipeline (ws_collector + oracle_consensus)
- [x] P2P network stub (p2p_node + vid_shard_grid)
- [x] Bare-metal persistence (vault_storage)
- [x] Node identity (node_identity)
- [x] Token system (omni_token, token_distribution)
- [ ] NIC driver real (P0)
- [ ] save_block() în main loop (P0)

### Phase 67 (Q2 2026)
- [ ] Smart Contract VM complet (opcode 0x00–0x7F)
- [ ] Cross-chain bridges live (BTC/ETH/SOL/EGLD)
- [ ] client_bridge.zig (light node)
- [ ] DEX local (liquidity pools)
- [ ] Mainnet launch (2026-03-15 target → shift la Q2)

### Phase 68 (Q3 2026)
- [ ] ZK Rollups integration
- [ ] Governance DAO live
- [ ] CEX listings (Kraken, Coinbase, Binance)
- [ ] Mobile wallet app

### Phase 69 (Q4 2026)
- [ ] Full decentralizare (100+ validator nodes)
- [ ] Flash loan arbitrage (opcode 0x20 complet)
- [ ] NFT layer
- [ ] 1,000 TPS verified

---

## Sumar Executiv

**OmniBus Blockchain** este un blockchain post-quantum bare-metal, primul de acest tip, integrat direct în cel mai rapid sistem de trading de înaltă frecvență. Cu **~15 module implementate**, **3 algoritmi NIST PQC**, **65,536 shard-uri** și o arhitectură capabilă să scaleze la **1.46 octilioane de adrese**, este funcțional ca un proof-of-concept complet.

**Cel mai important lucru de știut**: Nu rulează pe o mașină virtuală sau un OS clasic. Rulează pe bare-metal, controlând direct hardware-ul, ceea ce îl face unic în industrie.

**Cel mai important lucru de făcut**: Driver NIC real și integrarea `save_block()` în main loop pentru producție.

---

*Document generat automat din codul sursă și specificațiile proiectului OmniBus.*
*Director: `modules/omnibus_blockchain_os/`*
*Data: 2026-03-14*
