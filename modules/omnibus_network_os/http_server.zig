// Phase 66: Unified HTTP Server
// Routes wallet and explorer endpoints to their respective API modules
// =====================================================================

const std = @import("std");
const web_api = @import("web_api.zig");
const wallet_api = @import("wallet_api.zig");

pub const HTTP_SERVER_BASE: usize = 0x5E6000;

pub fn route_request(method: u8, path: [*:0]const u8, query: [*:0]const u8) web_api.HttpResponse {
    const path_str = std.mem.span(path);
    var response: web_api.HttpResponse = undefined;

    // Route wallet endpoints
    if (std.mem.startsWith(u8, path_str, "/api/wallet/")) {
        return wallet_api.handle_get_request(path, query);
    }
    // Route explorer endpoints
    else if (std.mem.startsWith(u8, path_str, "/api/")) {
        return web_api.handle_get_request(path);
    }
    // Static HTML pages would be served by filesystem
    else if (std.mem.startsWith(u8, path_str, "/")) {
        response.status_code = 404;
        @memcpy(response.content_type[0..16], "text/html");
        response.content_type[16] = 0;
        return response;
    }

    response.status_code = 404;
    return response;
}

/// Initialize HTTP server on port 8080
pub fn init_http_server() void {
    // In real implementation:
    // 1. Bind to port 8080 (or configured port)
    // 2. Create listening socket
    // 3. Accept incoming HTTP requests
    // 4. Parse method, path, query
    // 5. Call route_request()
    // 6. Serialize response back to socket
}

/// IPC handler for HTTP server
pub fn ipc_dispatch(opcode: u8, arg0: u64, arg1: u64) u64 {
    return switch (opcode) {
        0xC0 => init_http_server_ipc(),
        0xC1 => handle_http_request_ipc(arg0, arg1),
        else => 0,
    };
}

fn init_http_server_ipc() u64 {
    init_http_server();
    return 1;
}

fn handle_http_request_ipc(method: u64, path: u64) u64 {
    const path_ptr = @as([*:0]const u8, @ptrFromInt(path));
    var response = route_request(@as(u8, @intCast(method)), path_ptr, "");
    _ = response;
    return 1;
}
