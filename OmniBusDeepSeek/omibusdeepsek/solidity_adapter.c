// solidity_adapter.c
void handle_solidity_message(struct SolidityMessage* msg) {
    // 1. Load contract
    Contract* contract = load_contract(msg->contract_id);
    
    // 2. Execute function
    uint8_t* result = execute_contract(
        contract, 
        msg->function_selector,
        msg->params
    );
    
    // 3. Send response
    struct SolidityResponse resp = {
        .timestamp = get_timestamp(),
        .status = 0,
        .return_data = result
    };
    send_message(&resp);
}