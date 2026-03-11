// Mesaj Solidity către OmniBus
struct SolidityMessage {
    uint64_t timestamp;
    uint32_t contract_id;
    uint32_t function_selector;
    uint8_t* params;
    uint32_t params_length;
    uint64_t gas_limit;
    uint64_t value;  // Pentru transferuri ETH
}

// Răspuns de la OmniBus
struct SolidityResponse {
    uint64_t timestamp;
    uint32_t status;  // 0 = success, 1 = error
    uint8_t* return_data;
    uint32_t data_length;
    uint64_t gas_used;
}