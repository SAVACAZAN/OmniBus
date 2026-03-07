SOL_FIRE Client Executor (TypeScript)

import * as anchor from "@coral-xyz/anchor";import { Program } from "@coral-xyz/anchor";import { 
  Connection, 
  PublicKey, 
  Keypair, 
  Transaction, 
  ComputeBudgetProgram 
} from "@solana/web3.js";import fetch from "cross-fetch"; // Asigură-te că instalezi: npm install cross-fetch
// 1. CONFIGURARE INITIALĂconst RPC_ENDPOINT = "https://api.mainnet-beta.solana.com";const PROGRAM_ID = new PublicKey("SOL_FIRE_Exec11111111111111111111111111111");const WALLET_PRIVATE_KEY = Uint8Array.from([/* Introdu cheia ta privată aici */]);
const connection = new Connection(RPC_ENDPOINT, "confirmed");const wallet = Keypair.fromSecretKey(WALLET_PRIVATE_KEY);


async function runFlashStrike() {
    console.log("🚀 SOL_FIRE: Inițiere secvență de scanare...");

    // 2. GĂSIRE RUTĂ ARBITRAJ (Exemplu: SOL -> USDC -> SOL)
    // Folosim Jupiter API v6 pentru a găsi cea mai bună rută
    const inputMint = "So11111111111111111111111111111111111111112"; // WSOL
    const outputMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"; // USDC
    const amount = 1000000000; // 1 SOL în lamports

    console.log(`🔍 Căutare cotație pentru ${amount / 1e9} SOL...`);
    
    const quoteResponse = await (
        await fetch(`https://quote-api.jup.ag{inputMint}&outputMint=${outputMint}&amount=${amount}&slippageBps=50`)
    ).json();

    if (!quoteResponse || quoteResponse.error) {
        console.error("❌ Eroare Jupiter API:", quoteResponse.error);
        return;
    }


    console.log(`📈 Profit estimat: ${quoteResponse.outAmount} unități de ieșire`);

    // 3. CONSTRUIRE INSTRUCȚIUNE CĂTRE PROGRAMUL TĂU
    // Aici apelăm programul Rust (SOL_FIRE_Exec) pe care l-am scris anterior
    const provider = new anchor.AnchorProvider(connection, new anchor.Wallet(wallet), { commitment: "confirmed" });
    const program = new anchor.Program(IDL as any, PROGRAM_ID, provider);

    try {
        console.log("⚡ Generare tranzacție Flash Loan...");

        // Adăugăm Priority Fees pentru a trece în fața altor bot-i
        const modifyComputeUnits = ComputeBudgetProgram.setComputeUnitLimit({ 
            units: 1_000_000 
        });
        const addPriorityFee = ComputeBudgetProgram.setComputePrice({ 
            microLamports: 50_000 
        });

        const tx = await program.methods

            .executeFlashStrike(new anchor.BN(amount))
            .accounts({
                user: wallet.publicKey,
                vault: new PublicKey("CONTUL_TAU_DE_TOKENI_PROFIT"),
                jupiterProgram: new PublicKey("Lend6ByTsCCUNZymv9otbmR767EFyS47v5SAnH6H99N"), // Jupiter Lend Program
                lendingPool: new PublicKey("POOL_LICHIDITATE_SOL"),
                tokenProgram: anchor.utils.token.TOKEN_PROGRAM_ID,
                systemProgram: anchor.web3.SystemProgram.programId,
            })
            .preInstructions([modifyComputeUnits, addPriorityFee])
            .signers([wallet])
            .rpc();

        console.log(`✅ Tranzacție reușită! Signature: ${tx}`);
    } catch (err) {
        console.error("❌ Eșec Execuție: Arbitrajul nu a fost profitabil sau rețeaua a respins tranzacția.");
    }
}


// Exemplu minimal de IDL (Interfața programului)const IDL = {
    "version": "0.1.0",
    "name": "solana_flash_strike",
    "instructions": [
        {
            "name": "executeFlashStrike",
            "accounts": [
                { "name": "user", "isMut": true, "isSigner": true },
                { "name": "vault", "isMut": true, "isSigner": false },
                { "name": "jupiterProgram", "isMut": false, "isSigner": false },
                { "name": "lendingPool", "isMut": true, "isSigner": false },
                { "name": "tokenProgram", "isMut": false, "isSigner": false },
                { "name": "systemProgram", "isMut": false, "isSigner": false }
            ],
            "args": [
                { "name": "amount", "type": "u64" }
            ]
        }

    ]
};
// Pornire bot
runFlashStrike();


