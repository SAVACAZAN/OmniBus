/* Consensus Engine OS Linker Script
   Entry: init_plugin
   Target: 0x390000 (64KB)
   Memory: State (128B) + Proposal ring buffer (16*32B = 512B) + History (112B) = 752B reserved
*/

ENTRY(init_plugin)

SECTIONS
{
  . = 0x390000;

  /* Reserve 752 bytes for ConsensusState + ProposalBuffer + fault history */
  .reserved : {
    BYTE(0);
    . = 0x2F0;  /* 752 bytes reserved */
  }

  /* Code section */
  .text ALIGN(0x100) : {
    *(.text.init_plugin)
    *(.text*)
    *(.gnu.linkonce.t*)
  }

  .rodata ALIGN(0x100) : {
    *(.rodata*)
    *(.gnu.linkonce.r*)
  }

  .data ALIGN(0x100) : {
    *(.data*)
    *(.gnu.linkonce.d*)
  }

  .bss ALIGN(0x100) : {
    *(.bss*)
    *(COMMON)
  }

  /DISCARD/ : {
    *(.note.GNU-stack)
    *(.gnu_debuglink)
    *(.gnu_debugdata)
  }
}
