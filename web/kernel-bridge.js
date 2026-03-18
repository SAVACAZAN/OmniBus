/**
 * OmniBus Phase 29: WebSocket Kernel Memory Bridge
 * Real-time connection to kernel metrics via Socket.IO
 */

(function() {
    'use strict';

    // Configuration
    const KERNEL_UPDATE_MS = 100;
    const RECONNECT_DELAY_MS = 1000;

    // State
    let socket = null;
    let isConnected = false;
    let lastMetrics = null;
    let startTime = Date.now();

    /**
     * Initialize Socket.IO connection to kernel bridge
     */
    function initSocket() {
        console.log('[Dashboard] Initializing WebSocket connection to OmniBus kernel...');

        socket = io('http://' + window.location.host, {
            reconnection: true,
            reconnectionDelay: RECONNECT_DELAY_MS,
            reconnectionDelayMax: 5000,
            reconnectionAttempts: 10,
            transports: ['websocket', 'polling'],
        });

        // Connection events
        socket.on('connect', onSocketConnect);
        socket.on('disconnect', onSocketDisconnect);
        socket.on('error', onSocketError);

        // Kernel metrics events
        socket.on('kernel_state', onKernelState);
        socket.on('connection', onConnectionMessage);
    }

    /**
     * Handle socket connection
     */
    function onSocketConnect() {
        console.log('[Dashboard] WebSocket connected!');
        isConnected = true;
        updateConnectionStatus(true);

        // Request immediate kernel state
        if (socket) {
            socket.emit('request_state');
        }
    }

    /**
     * Handle socket disconnection
     */
    function onSocketDisconnect() {
        console.log('[Dashboard] WebSocket disconnected');
        isConnected = false;
        updateConnectionStatus(false);
    }

    /**
     * Handle socket errors
     */
    function onSocketError(error) {
        console.error('[Dashboard] WebSocket error:', error);
    }

    /**
     * Handle initial connection message from server
     */
    function onConnectionMessage(data) {
        console.log('[Dashboard] Connection message:', data);
        const modeDisplay = document.getElementById('mode-display');
        if (modeDisplay && data.mode) {
            modeDisplay.textContent = data.mode;
        }
    }

    /**
     * Handle kernel state updates
     */
    function onKernelState(metrics) {
        lastMetrics = metrics;
        updateTimestamp(metrics.timestamp);

        // Animate number changes
        if (metrics.grid && metrics.grid.valid) {
            updateNumberAnimated('grid-profit', metrics.grid.profit_usd);
            updateNumberAnimated('grid-orders', metrics.grid.orders);
        }

        // Log for debugging
        console.log('[Dashboard] Kernel state updated:', metrics);
    }

    /**
     * Update connection status indicator
     */
    function updateConnectionStatus(connected) {
        const status = document.getElementById('connection-status');
        if (!status) return;

        if (connected) {
            status.classList.add('connected');
            status.innerHTML = '<div class="dot"></div><span class="text-green-400">Connected</span>';
        } else {
            status.classList.remove('connected');
            status.innerHTML = '<div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div><span class="text-red-400">Reconnecting...</span>';
        }
    }

    /**
     * Update timestamp display
     */
    function updateTimestamp(timestamp) {
        const el = document.getElementById('timestamp');
        if (el && timestamp) {
            const date = new Date(timestamp * 1000);
            el.textContent = date.toLocaleTimeString();
        }
    }

    /**
     * Animate number changes with color feedback
     */
    function updateNumberAnimated(elementId, newValue) {
        const el = document.getElementById(elementId);
        if (!el) return;

        const oldValue = parseFloat(el.textContent) || 0;
        if (newValue > oldValue) {
            el.classList.remove('number-decrease');
            el.classList.add('number-increase');
        } else if (newValue < oldValue) {
            el.classList.remove('number-increase');
            el.classList.add('number-decrease');
        }

        el.textContent = newValue.toFixed(2);

        // Remove animation class after animation completes
        setTimeout(() => {
            el.classList.remove('number-increase', 'number-decrease');
        }, 300);
    }

    /**
     * Handle HTMX panel swaps with smooth animation
     */
    function setupHTMXAnimations() {
        document.addEventListener('htmx:afterSwap', (event) => {
            const content = event.detail.target;
            if (content) {
                content.classList.add('panel-update');
                setTimeout(() => content.classList.remove('panel-update'), 300);
            }
        });

        document.addEventListener('htmx:oob:swap', (event) => {
            console.log('[Dashboard] OOB swap triggered');
        });
    }

    /**
     * Setup polling fallback for REST API (if WebSocket fails)
     */
    function setupPollingFallback() {
        if (!isConnected) {
            console.log('[Dashboard] Setting up polling fallback...');
            setInterval(pollKernelState, 500);
        }
    }

    /**
     * Poll kernel state via REST API
     */
    async function pollKernelState() {
        try {
            const response = await fetch('/api/kernel-state');
            if (!response.ok) return;

            const metrics = await response.json();
            onKernelState(metrics);
        } catch (error) {
            console.debug('[Dashboard] Polling error:', error);
        }
    }

    /**
     * Initialize heartbeat to keep connection alive
     */
    function setupHeartbeat() {
        setInterval(() => {
            if (socket && isConnected) {
                socket.emit('ping');
            }
        }, 30000);  // Every 30 seconds
    }

    /**
     * Log dashboard info
     */
    function logDashboardInfo() {
        const uptime = Math.floor((Date.now() - startTime) / 1000);
        console.log(`
╔════════════════════════════════════════════════════╗
║    OmniBus Phase 29: HTMX Dashboard Initialized   ║
║                                                    ║
║  Mode: ${isConnected ? 'WebSocket' : 'Polling Fallback':<30} ║
║  Uptime: ${uptime}s${' '.repeat(38 - uptime.toString().length)} ║
║  Status: ${isConnected ? 'CONNECTED ✓' : 'CONNECTING...'}${' '.repeat(34 - (isConnected ? 'CONNECTED ✓' : 'CONNECTING...').length)}║
║                                                    ║
║  Real-time panels:                                 ║
║  • Trading (Grid OS)                               ║
║  • Compliance (Zorin OS)                           ║
║  • Health (Checksum + AutoRepair)                  ║
║  • Audit (Event log)                               ║
║  • NeuroOS (Genetic algorithm)                     ║
║                                                    ║
║  Updates: Every 100ms (WebSocket)                  ║
║  Kernel: /dev/mem or QEMU SHM bridge              ║
╚════════════════════════════════════════════════════╝
        `);
    }

    /**
     * Initialize dashboard
     */
    function init() {
        console.log('[Dashboard] Starting OmniBus Phase 29 Dashboard...');

        // Setup HTMX animations
        setupHTMXAnimations();

        // Initialize WebSocket
        initSocket();

        // Setup heartbeat
        setupHeartbeat();

        // Setup polling fallback after short delay
        setTimeout(setupPollingFallback, 2000);

        // Log info
        setTimeout(logDashboardInfo, 1000);
    }

    // Start when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    // Export for debugging
    window.OmniBusDashboard = {
        socket,
        isConnected: () => isConnected,
        lastMetrics: () => lastMetrics,
        requestState: () => socket && socket.emit('request_state'),
    };
})();
