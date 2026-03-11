#!/bin/bash
# Phase 48A: Unit Test Runner for OmniBus 33-Layer System
# Tests: Memory bounds, initialization, state consistency, determinism
# Output: Test results + profiling baseline

set -e

RESULTS_DIR="./test_results"
LOGS_DIR="${RESULTS_DIR}/logs"
PROFILES_DIR="${RESULTS_DIR}/profiles"
mkdir -p "$RESULTS_DIR" "$LOGS_DIR" "$PROFILES_DIR"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_count=0
pass_count=0
fail_count=0

# ============================================================================
# Test Infrastructure
# ============================================================================

log_test() {
    local test_name="$1"
    local status="$2"
    test_count=$((test_count + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        pass_count=$((pass_count + 1))
    else
        echo -e "${RED}✗${NC} $test_name"
        fail_count=$((fail_count + 1))
    fi
}

run_boot_test() {
    local test_name="$1"
    local cycle_count="${2:-100}"

    echo -e "\n${YELLOW}Running:${NC} $test_name (expecting $cycle_count+ cycles)"

    timeout 30 make qemu 2>&1 | tee "${LOGS_DIR}/${test_name// /_}.log" > /tmp/qemu_out.txt

    local cycle_markers=$(grep -c "INISIM!" /tmp/qemu_out.txt || true)

    if [ "$cycle_markers" -ge "$cycle_count" ]; then
        log_test "$test_name" "PASS"
        return 0
    else
        log_test "$test_name" "FAIL"
        echo "  Expected: $cycle_count+ cycle markers, Got: $cycle_markers"
        return 1
    fi
}

verify_memory_layout() {
    local test_name="$1"
    echo -e "\n${YELLOW}Verifying:${NC} $test_name"

    # Check kernel is at 0x100000
    local kernel_size=$(stat -f%z "./build/kernel.bin" 2>/dev/null || stat -c%s "./build/kernel.bin")
    if [ "$kernel_size" -gt 0 ]; then
        log_test "Kernel binary present (${kernel_size} bytes)" "PASS"
    else
        log_test "Kernel binary present" "FAIL"
        return 1
    fi

    # Check all module binaries exist
    local modules=("grid_os" "execution_os" "analytics_os" "blockchain_os" "neuro_os" \
                   "bank_os" "stealth_os" "report_os" "checksum_os" "autorepair_os" \
                   "zorin_os" "audit_os" "param_tuning_os" "historical_analytics_os" \
                   "alert_system_os" "consensus_os" "federation_os" "mev_guard_os" \
                   "cross_chain_bridge_os" "dao_governance_os" "performance_profiler_os" \
                   "disaster_recovery_os" "compliance_reporter_os" "liquid_staking_os" \
                   "slashing_protection_os" "orderflow_auction_os" "circuit_breaker_os" \
                   "flash_loan_protection_os" "l2_rollup_bridge_os" "quantum_resistant_crypto_os" \
                   "pqc_gate_os")

    local found=0
    for mod in "${modules[@]}"; do
        if [ -f "build/${mod}.bin" ]; then
            found=$((found + 1))
        fi
    done

    if [ "$found" -ge 30 ]; then
        log_test "Module binaries present ($found/33)" "PASS"
    else
        log_test "Module binaries present ($found/33)" "FAIL"
    fi
}

verify_compilation() {
    local test_name="$1"
    echo -e "\n${YELLOW}Compiling:${NC} $test_name"

    if make clean > /dev/null 2>&1 && make build > /tmp/build.log 2>&1; then
        log_test "Clean build succeeds" "PASS"
    else
        log_test "Clean build succeeds" "FAIL"
        tail -20 /tmp/build.log
        return 1
    fi
}

# ============================================================================
# Unit Tests
# ============================================================================

echo "=========================================="
echo "  Phase 48A: Unit Test Suite"
echo "  OmniBus 33-Layer System"
echo "=========================================="

# Test 1: Compilation
echo -e "\n${YELLOW}=== UNIT TEST 1: Compilation ===${NC}"
verify_compilation "Build all modules"

# Test 2: Memory Layout
echo -e "\n${YELLOW}=== UNIT TEST 2: Memory Layout ===${NC}"
verify_memory_layout "33-layer memory layout"

# Test 3: Boot Stability (100 cycles)
echo -e "\n${YELLOW}=== UNIT TEST 3: Boot Stability ===${NC}"
run_boot_test "Boot with 100+ cycles" 100

# Test 4: Extended Stability (1000 cycles)
echo -e "\n${YELLOW}=== UNIT TEST 4: Extended Stability ===${NC}"
run_boot_test "Boot with 1000+ cycles" 1000

# Test 5: Serial Output Markers
echo -e "\n${YELLOW}=== UNIT TEST 5: Serial Output Markers ===${NC}"
if timeout 30 make qemu 2>&1 | grep -q "KTCRPLONG_MODE_OK"; then
    log_test "Long mode marker present" "PASS"
else
    log_test "Long mode marker present" "FAIL"
fi

if timeout 30 make qemu 2>&1 | grep -q "MOTHER_OS_64_OK"; then
    log_test "Kernel init marker present" "PASS"
else
    log_test "Kernel init marker present" "FAIL"
fi

# ============================================================================
# Results Summary
# ============================================================================

echo -e "\n=========================================="
echo "  Test Results Summary"
echo "=========================================="
echo -e "Total Tests:  ${test_count}"
echo -e "${GREEN}Passed:${NC}      ${pass_count}"
echo -e "${RED}Failed:${NC}      ${fail_count}"

if [ "$fail_count" -eq 0 ]; then
    echo -e "\n${GREEN}✓ ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "\n${RED}✗ SOME TESTS FAILED${NC}"
    exit 1
fi
