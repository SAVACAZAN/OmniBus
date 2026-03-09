-- Post-Quantum Cryptography Vault Package Specification
-- ======================================================
--
-- Manages Kyber-512 keys and PQC operations
-- Located at 0x100800 in kernel memory (2KB)
--
-- Kyber-512 is a NIST-standardized post-quantum key encapsulation mechanism
-- Used to secure API credentials and key material

with System;
with Interfaces;
use System;
use Interfaces;

package PQC_Vault is

   -- =============================================
   -- CONSTANTS
   -- =============================================

   PQC_BASE       : constant Unsigned_32 := 16#100800#;
   PQC_SIZE       : constant Unsigned_32 := 16#800#;  -- 2KB

   KYBER_PK_SIZE  : constant Natural := 800;      -- Kyber-512 public key (bytes)
   KYBER_SK_SIZE  : constant Natural := 1632;     -- Kyber-512 secret key (bytes)
   KYBER_SS_SIZE  : constant Natural := 32;       -- Shared secret (bytes)
   KYBER_CT_SIZE  : constant Natural := 768;      -- Ciphertext (bytes)

   -- =============================================
   -- TYPES
   -- =============================================

   type Kyber_Public_Key is array (0 .. KYBER_PK_SIZE - 1) of Unsigned_8;
   type Kyber_Secret_Key is array (0 .. KYBER_SK_SIZE - 1) of Unsigned_8;
   type Kyber_Shared_Secret is array (0 .. KYBER_SS_SIZE - 1) of Unsigned_8;
   type Kyber_Ciphertext is array (0 .. KYBER_CT_SIZE - 1) of Unsigned_8;

   -- =============================================
   -- VAULT OPERATIONS
   -- =============================================

   --  Initialize PQC vault (load Kyber keys)
   procedure Initialize_PQC_Vault;

   --  Get public key from vault
   function Get_Public_Key return Kyber_Public_Key;

   --  Get secret key from vault
   function Get_Secret_Key return Kyber_Secret_Key;

   --  Validate key material (hash check)
   function Validate_Keys return Boolean;

   --  Encapsulate (generate shared secret + ciphertext)
   procedure Kyber_Encapsulate
     (PK : Kyber_Public_Key;
      SS : out Kyber_Shared_Secret;
      CT : out Kyber_Ciphertext);

   --  Decapsulate (recover shared secret from ciphertext)
   procedure Kyber_Decapsulate
     (SK : Kyber_Secret_Key;
      CT : Kyber_Ciphertext;
      SS : out Kyber_Shared_Secret);

   -- =============================================
   -- DIAGNOSTICS
   -- =============================================

   --  Check if keys are initialized
   function Is_Vault_Initialized return Boolean;

end PQC_Vault;
