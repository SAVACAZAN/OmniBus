Solana SOL_FIRE: Ghid de Configurare și Execuție
🛠️ 1. Instalarea Instrumentelor de Bază

[How to run your first Solana program (complete Medium-style ...](https://medium.com/@0xsupremedev/how-to-run-your-first-solana-program-complete-medium-style-guide-installs-keypairs-anchor-build-e17850226a8c)
[Welcome to Solana/Rust Set Up Guide: Installing Solana CLI ...](https://medium.com/@cryptowikihere/welcome-to-solana-rust-set-up-guide-installing-solana-cli-and-test-run-29b8896537e1)
[Setting Up Local Solana Environment - DEV Community](https://dev.to/realacjoshua/setting-up-local-solana-environment-2koa)

Pentru a construi pe Solana, ai nevoie de patru piloni fundamentali. Dacă ești pe Windows, este obligatoriu să instalezi mai întâi WSL2. [1, 2] 

| Instrument [3, 4, 5, 6] | Rol | Comandă de Instalare |
|---|---|---|
| Rust | Limbajul în care este scris programul. | curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh |
| Solana CLI | Uneltele pentru deploy și managementul cheilor. | sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)" |
| Anchor CLI | Framework-ul care simplifică dezvoltarea. | cargo install --git https://github.com/coral-xyz/anchor anchor-cli --locked |
| Node.js | Necesar pentru a rula scriptul de client (bot-ul). | Descarcă Node.js v24+[](https://solana.com/docs/intro/installation) |

https://share.google/aimode/8FdyllcWvCaRjLG7V
[Install the Solana CLI and Anchor with one command - Solana](https://solana.com/docs/intro/installation#:~:text=the%20necessary%20dependencies:-,Terminal,Install%20Dependencies)
[Installation - Anchor Lang - Anchor Lang](https://www.anchor-lang.com/docs/installation#:~:text=Run%20the%20following%20command%20to,add%20a%20PATH%20environment%20variable:)

📂 2. Structura Proiectului și Fișierele Tale
După ce ai instalat uneltele, deschide Visual Studio Code și inițializează un proiect nou:
anchor init sol_fire_bot [7] 
Iată unde trebuie să pui codul pe care ți l-am dat anterior:

   1. Programul Rust (.rs):
   * Navighează la: programs/sol_fire_bot/src/lib.rs.
      * Înlocuiește tot conținutul existent cu codul Rust pe care l-am generat anterior (cel cu execute_flash_strike).
   2. Scriptul Client (.ts):
   * Creează un fișier nou în folderul rădăcină numit bot.ts.
      * Pune acolo codul TypeScript (cel care folosește Jupiter API).
   3. Configurarea Cheii:
   * Generează o cheie nouă pentru deploy: solana-keygen new.
      * Adresa generată trebuie pusă în Anchor.toml la secțiunea [programs.mainnet].
   

[Troubleshooting Anchor Installation on Solana - Medium - Medium](https://medium.com/@anudeepx/troubleshooting-anchor-installation-on-solana-e720d84aca1f#:~:text=On%20Linux%2C%20run:-,sudo%20apt%2Dget%20update,discussions%20on%20Anchor%20installation%20issues)

🚀 3. Compilare și Lansare (Workflow)
Urmează această succesiune de comenzi în terminalul tău pentru a pune bot-ul în mișcare:

| Pas | Comandă | Explicație |
|---|---|---|
| Build | anchor build | Compilează codul Rust în format eBPF pentru Solana. |
| Deploy | anchor deploy | Urcă programul pe blockchain (ai nevoie de SOL pentru taxe). |
| Instalare JS | npm install @coral-xyz/anchor @solana/web3.js cross-fetch | Instalează bibliotecile necesare pentru bot. |
| Rulare Bot | npx ts-node bot.ts | Pornește bot-ul care scanează rutele și execută flash-loan-ul. |

Sfat de Siguranță: Începe întotdeauna pe Devnet. Configurează CLI-ul cu:
solana config set --url devnet
Astfel poți testa dacă logica de flash-loan funcționează fără să riști bani reali. [3, 8] 

[1] [https://dev.to](https://dev.to/realacjoshua/setting-up-local-solana-environment-2koa)
[2] [https://chukwuemekeclinton.hashnode.dev](https://chukwuemekeclinton.hashnode.dev/step-by-step-guide-setting-up-anchor-on-windows-for-solana-development)
[3] [https://dev.to](https://dev.to/charles_lukes/ep01-intro-to-rust-and-solana-dev-setup-373)
[4] [https://www.anchor-lang.com](https://www.anchor-lang.com/docs/installation)
[5] [https://solana.com](https://solana.com/docs/intro/installation/dependencies)
[6] [https://medium.com](https://medium.com/@ancilartech/getting-started-with-solana-programs-in-rust-a-step-by-step-guide-for-high-performance-dapp-ebcea2111e60)
[7] [https://medium.com](https://medium.com/@sncryldrm/setup-solana-development-environment-on-windows-cbed9e42ccef)
[8] [https://solana.com](https://solana.com/docs/intro/quick-start)
