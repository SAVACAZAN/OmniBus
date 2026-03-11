// metrics_os.zig — Observability Hub (Phase 59)
// Prometheus + Elasticsearch integration

const std = @import("std");
const types = @import("metrics_types.zig");

fn getMetricsStatePtr() *volatile types.MetricsOsState {
    return @as(*volatile types.MetricsOsState, @ptrFromInt(types.METRICS_BASE));
}

fn getProviderMetricsPtr(provider_id: u8) *volatile types.ProviderMetrics {
    if (provider_id >= types.MAX_PROVIDERS) return undefined;
    const base = types.METRICS_BASE + @sizeOf(types.MetricsOsState);
    return @as(*volatile types.ProviderMetrics, @ptrFromInt(base + provider_id * @sizeOf(types.ProviderMetrics)));
}

export fn init_plugin() void {
    const state = getMetricsStatePtr();
    state.magic = 0x4D455452;  // 'METR'
    state.flags = 0x01;
    state.cycle_count = 0;
    state.total_cycles_measured = 0;
    state.total_metrics_published = 0;
    state.total_elasticsearch_docs = 0;
    state.last_prometheus_scrape = 0;
    state.last_elasticsearch_flush = 0;
    state.agg_trades_executed = 0;
    state.agg_trades_failed = 0;
    state.agg_latency_sum_us = 0;
    state.agg_latency_max_us = 0;

    var i: u8 = 0;
    while (i < types.MAX_PROVIDERS) : (i += 1) {
        const metrics = getProviderMetricsPtr(i);
        metrics.provider_id = i;
        metrics.timestamp = 0;
        metrics.trades_executed = 0;
        metrics.trades_failed = 0;
        metrics.latency_p50_us = 0;
        metrics.latency_p95_us = 0;
        metrics.latency_p99_us = 0;
        metrics.availability_pct = 10000;  // 100.00%
    }
}

export fn run_metrics_cycle() void {
    const state = getMetricsStatePtr();
    state.cycle_count +|= 1;
    state.total_cycles_measured +|= 1;

    // Aggregate metrics from all providers
    var total_executed: u32 = 0;
    var total_failed: u32 = 0;
    var max_latency: u32 = 0;

    var i: u8 = 0;
    while (i < types.MAX_PROVIDERS) : (i += 1) {
        const metrics = getProviderMetricsPtr(i);
        total_executed +|= metrics.trades_executed;
        total_failed +|= metrics.trades_failed;
        if (metrics.latency_p99_us > max_latency) {
            max_latency = metrics.latency_p99_us;
        }
    }

    state.agg_trades_executed = total_executed;
    state.agg_trades_failed = total_failed;
    state.agg_latency_max_us = max_latency;
}

export fn update_provider_metrics(
    provider_id: u8,
    trades_executed: u32,
    trades_failed: u32,
    latency_p50: u32,
    latency_p95: u32,
    latency_p99: u32,
    availability: u16,
) void {
    const state = getMetricsStatePtr();
    const metrics = getProviderMetricsPtr(provider_id);

    metrics.provider_id = provider_id;
    metrics.timestamp = state.cycle_count;
    metrics.trades_executed = trades_executed;
    metrics.trades_failed = trades_failed;
    metrics.latency_p50_us = latency_p50;
    metrics.latency_p95_us = latency_p95;
    metrics.latency_p99_us = latency_p99;
    metrics.availability_pct = availability;

    state.total_metrics_published +|= 1;
}

export fn prometheus_format(provider_id: u8) void {
    // Format: omnibus_trades_total{provider="microsoft"} 1024
    // This would be sent to Prometheus scrape endpoint
    _ = provider_id;  // Future: calculate_prometheus_metrics()
}

export fn elasticsearch_document(provider_id: u8) void {
    // Format: {"timestamp": 1000000, "provider": "oracle", "trades": 1024, ...}
    // This would be indexed into Elasticsearch
    const state = getMetricsStatePtr();
    _ = provider_id;  // Future: format_elasticsearch_doc()
    state.total_elasticsearch_docs +|= 1;
}

export fn get_latency_percentile(provider_id: u8, percentile: u8) u32 {
    const metrics = getProviderMetricsPtr(provider_id);
    return switch (percentile) {
        50 => metrics.latency_p50_us,
        95 => metrics.latency_p95_us,
        99 => metrics.latency_p99_us,
        else => 0,
    };
}

export fn get_availability(provider_id: u8) u16 {
    return getProviderMetricsPtr(provider_id).availability_pct;
}

export fn get_aggregated_trades() u32 {
    return getMetricsStatePtr().agg_trades_executed;
}

export fn get_cycle_count() u64 {
    return getMetricsStatePtr().cycle_count;
}

export fn is_initialized() u8 {
    const state = getMetricsStatePtr();
    return if (state.magic == 0x4D455452) 1 else 0;
}
