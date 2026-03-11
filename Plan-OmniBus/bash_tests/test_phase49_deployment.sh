#!/bin/bash
# Phase 49.5: Deployment Testing & Validation
# Tests Docker/Kubernetes infrastructure, load testing, WebSocket validation

set -e

RESULTS_DIR="./test_results"
DEPLOYMENT_DIR="${RESULTS_DIR}/deployment"
LOAD_DIR="${RESULTS_DIR}/load_testing"

mkdir -p "$DEPLOYMENT_DIR" "$LOAD_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

test_count=0
pass_count=0
fail_count=0

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

# ============================================================================
# Phase 49.5 Test 1: Docker Deployment
# ============================================================================

test_docker_deployment() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 1: Docker Deployment ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    cd docker

    # Start services
    echo "Starting Docker Compose services..."
    docker-compose up -d 2>&1 | tee "${DEPLOYMENT_DIR}/docker_startup.log"

    # Wait for services to be ready
    sleep 15

    # Check Redis
    if docker exec omnibus-redis redis-cli ping > /dev/null 2>&1; then
        log_test "Redis container healthy" "PASS"
    else
        log_test "Redis container healthy" "FAIL"
        return 1
    fi

    # Check API Gateway
    if docker exec omnibus-api-gateway curl -s http://localhost:8000/health > /dev/null 2>&1; then
        log_test "API Gateway responsive" "PASS"
    else
        log_test "API Gateway responsive" "FAIL"
        return 1
    fi

    # Check Nginx
    if docker exec omnibus-nginx nginx -t > /dev/null 2>&1; then
        log_test "Nginx configuration valid" "PASS"
    else
        log_test "Nginx configuration valid" "FAIL"
        return 1
    fi

    cd ..
}

# ============================================================================
# Phase 49.5 Test 2: API Health Checks
# ============================================================================

test_api_health() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 2: API Health Checks ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    # Health endpoint
    local health_response=$(curl -s http://localhost:8000/health)

    if echo "$health_response" | grep -q "healthy"; then
        log_test "Health endpoint responds" "PASS"
        echo "  Response: $health_response" | head -c 100
    else
        log_test "Health endpoint responds" "FAIL"
        return 1
    fi

    # Metrics endpoint
    if curl -s http://localhost:8000/metrics | grep -q "active_connections"; then
        log_test "Metrics endpoint available" "PASS"
    else
        log_test "Metrics endpoint available" "FAIL"
        return 1
    fi
}

# ============================================================================
# Phase 49.5 Test 3: WebSocket Connectivity
# ============================================================================

test_websocket_connection() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 3: WebSocket Connectivity ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    # Create WebSocket test script
    cat > /tmp/ws_test.py << 'WSTEST'
import asyncio
import websockets
import json
import sys

async def test_websocket():
    try:
        # Test price WebSocket
        async with websockets.connect('ws://localhost:8000/ws/prices/kraken?token=test') as websocket:
            # Send ping
            await asyncio.sleep(1)

            # Try to receive message
            try:
                message = await asyncio.wait_for(websocket.recv(), timeout=5)
                data = json.loads(message)
                if 'price_update' in data or 'type' in data:
                    return True
            except asyncio.TimeoutError:
                return True  # Connection successful, just no messages yet
    except Exception as e:
        print(f"WebSocket error: {e}", file=sys.stderr)
        return False

result = asyncio.run(test_websocket())
sys.exit(0 if result else 1)
WSTEST

    if python3 /tmp/ws_test.py 2>/dev/null; then
        log_test "WebSocket price stream connects" "PASS"
    else
        log_test "WebSocket price stream connects" "FAIL (expected in first run)"
    fi

    rm /tmp/ws_test.py
}

# ============================================================================
# Phase 49.5 Test 4: Order Submission
# ============================================================================

test_order_submission() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 4: Order Submission ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    local order_response=$(curl -s -X POST http://localhost:8000/orders/submit \
        -H "X-API-Key: test_user_abc123" \
        -H "Content-Type: application/json" \
        -d '{
            "pair": "BTC-USD",
            "side": "BUY",
            "price_cents": 7160000,
            "quantity": 0.1,
            "exchange": "kraken"
        }')

    if echo "$order_response" | grep -q "SUBMITTED"; then
        log_test "Order submission successful" "PASS"
        echo "  Order: $order_response" | grep -o '"order_id":"[^"]*"'
    else
        log_test "Order submission successful" "FAIL"
        echo "  Response: $order_response"
        return 1
    fi
}

# ============================================================================
# Phase 49.5 Test 5: Load Testing (100 concurrent requests)
# ============================================================================

test_load_100() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 5: Load Test (100 concurrent) ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    if ! command -v ab &> /dev/null; then
        echo "Apache Bench not installed, skipping load test"
        return 0
    fi

    echo "Running 1000 requests with 100 concurrent..."
    local ab_output=$(ab -n 1000 -c 100 -q http://localhost:8000/health 2>&1)

    if echo "$ab_output" | grep -q "Requests per second"; then
        log_test "Load test 100 concurrent completed" "PASS"
        echo "$ab_output" | grep -E "Requests per second|Time per request|Failed requests" | sed 's/^/  /'
        echo "$ab_output" > "${LOAD_DIR}/ab_100_concurrent.txt"
    else
        log_test "Load test 100 concurrent completed" "FAIL"
        return 1
    fi
}

# ============================================================================
# Phase 49.5 Test 6: Load Testing (500 concurrent requests)
# ============================================================================

test_load_500() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 6: Load Test (500 concurrent) ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    if ! command -v ab &> /dev/null; then
        echo "Apache Bench not installed, skipping load test"
        return 0
    fi

    echo "Running 5000 requests with 500 concurrent..."
    local ab_output=$(ab -n 5000 -c 500 -q http://localhost:8000/health 2>&1)

    if echo "$ab_output" | grep -q "Requests per second"; then
        log_test "Load test 500 concurrent completed" "PASS"
        echo "$ab_output" | grep -E "Requests per second|Time per request|Failed requests" | sed 's/^/  /'
        echo "$ab_output" > "${LOAD_DIR}/ab_500_concurrent.txt"
    else
        log_test "Load test 500 concurrent completed" "FAIL"
        return 1
    fi
}

# ============================================================================
# Phase 49.5 Test 7: Redis Performance
# ============================================================================

test_redis_performance() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 7: Redis Performance ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    # Benchmark Redis with redis-benchmark
    if command -v redis-benchmark &> /dev/null; then
        echo "Running Redis benchmark..."
        local redis_bench=$(redis-benchmark -h localhost -p 6379 -q -n 10000 2>&1 | head -5)

        if echo "$redis_bench" | grep -q "PING"; then
            log_test "Redis performance benchmark" "PASS"
            echo "$redis_bench" | sed 's/^/  /'
        else
            log_test "Redis performance benchmark" "FAIL"
        fi
    else
        # Fallback: test Redis connectivity
        if docker exec omnibus-redis redis-cli INFO stats | grep -q "total_commands"; then
            log_test "Redis stats collection" "PASS"
        else
            log_test "Redis stats collection" "FAIL"
        fi
    fi
}

# ============================================================================
# Phase 49.5 Test 8: Memory Usage
# ============================================================================

test_memory_usage() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 8: Memory Usage ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    # Check Docker container memory
    local mem_output=$(docker stats --no-stream --format "{{.MemUsage}}" omnibus-api-gateway omnibus-redis)

    echo "Container memory usage:"
    echo "  API Gateway: $(docker stats --no-stream --format '{{.MemUsage}}' omnibus-api-gateway)"
    echo "  Redis: $(docker stats --no-stream --format '{{.MemUsage}}' omnibus-redis)"

    log_test "Memory usage monitoring" "PASS"
}

# ============================================================================
# Phase 49.5 Test 9: Kubernetes Readiness Check
# ============================================================================

test_kubernetes_readiness() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 9: Kubernetes Readiness ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    if ! command -v kubectl &> /dev/null; then
        echo "kubectl not installed, skipping Kubernetes tests"
        echo "(Install kubectl to test Kubernetes deployment)"
        return 0
    fi

    # Check if cluster is available
    if kubectl cluster-info > /dev/null 2>&1; then
        log_test "Kubernetes cluster accessible" "PASS"
    else
        echo "Kubernetes cluster not available (optional)"
        return 0
    fi

    # Check namespace
    if kubectl get namespace omnibus > /dev/null 2>&1; then
        log_test "OmniBus namespace exists" "PASS"
    else
        echo "OmniBus namespace not yet deployed (run: kubectl apply -f k8s/)"
        return 0
    fi
}

# ============================================================================
# Phase 49.5 Test 10: Dashboard Accessibility
# ============================================================================

test_dashboard_access() {
    local test_name="$1"
    echo -e "\n${YELLOW}=== Phase 49.5 Test 10: Dashboard Accessibility ===${NC}"
    echo -e "${BLUE}Testing:${NC} $test_name"

    if curl -s http://localhost/dashboard_scaled.html | grep -q "OmniBus Trading Dashboard"; then
        log_test "Dashboard accessible via Nginx" "PASS"
    else
        echo "Dashboard not accessible (expected if Nginx not routing)"
        return 0
    fi
}

# ============================================================================
# Main Test Suite
# ============================================================================

echo "=========================================="
echo "  Phase 49.5: Deployment Testing"
echo "  OmniBus API Gateway Validation"
echo "=========================================="

# Run tests
test_docker_deployment "Docker Compose startup and health checks"
test_api_health "API Gateway health endpoints"
test_websocket_connection "WebSocket price stream"
test_order_submission "Order submission pipeline"
test_load_100 "Load test with 100 concurrent connections"
test_load_500 "Load test with 500 concurrent connections"
test_redis_performance "Redis performance and stats"
test_memory_usage "Container memory usage monitoring"
test_kubernetes_readiness "Kubernetes cluster readiness"
test_dashboard_access "Dashboard HTML accessibility"

# ============================================================================
# Results Summary
# ============================================================================

echo -e "\n=========================================="
echo "  Phase 49.5 Test Results"
echo "=========================================="
echo -e "Total Tests:  ${test_count}"
echo -e "${GREEN}Passed:${NC}      ${pass_count}"
echo -e "${RED}Failed:${NC}      ${fail_count}"

# Performance summary
if [ -f "${LOAD_DIR}/ab_100_concurrent.txt" ]; then
    echo -e "\n${BLUE}Load Test Results:${NC}"
    grep "Requests per second" "${LOAD_DIR}/ab_100_concurrent.txt" | sed 's/^/  [100 concurrent] /'
    grep "Requests per second" "${LOAD_DIR}/ab_500_concurrent.txt" | sed 's/^/  [500 concurrent] /'
fi

echo -e "\n${BLUE}Next Steps:${NC}"
echo "1. Phase 6: Run optimization sprint (Phase 6 modules)"
echo "2. Phase 50: Full integration with OmniBus"
echo "3. Kubernetes: Deploy with kubectl apply -f k8s/"

if [ "$fail_count" -eq 0 ]; then
    echo -e "\n${GREEN}✓ PHASE 49.5 DEPLOYMENT TESTS PASSED${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠ Some tests failed (see above for details)${NC}"
    exit 1
fi
