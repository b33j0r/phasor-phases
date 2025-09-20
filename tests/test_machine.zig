/// Shared logger used by all contexts to append messages.
const Logger = struct {
    allocator: std.mem.Allocator,
    log: std.ArrayListUnmanaged([]const u8) = .empty,

    pub fn init(alloc: std.mem.Allocator) Logger {
        return .{ .allocator = alloc, .log = .empty };
    }

    pub fn append(self: *Logger, msg: []const u8) !void {
        try self.log.append(self.allocator, msg);
    }

    pub fn deinit(self: *Logger) void {
        self.log.deinit(self.allocator);
    }
};

/// Per-level context: just carries a reference to the shared Logger.
const TestCtx = struct {
    logger: *Logger,
};

const TestCtxFactory = struct {
    alloc: std.mem.Allocator,

    const Self = @This();

    pub fn create(self: *Self) !*TestCtx {
        const ctx = self.alloc.create(TestCtx) catch @panic("oom");
        ctx.* = .{ .logger = &global_logger.? };
        return ctx;
    }

    pub fn destroy(self: *Self, ctx: *TestCtx) void {
        self.alloc.destroy(ctx);
    }
};

var global_logger: ?Logger = null;

test "StateMachine hierarchical enter/exit with sibling-substate optimization" {
    global_logger = Logger.init(std.testing.allocator);
    defer global_logger.?.deinit();

    const MyStates = union(enum) {
        StateA: struct {
            pub fn enter(ctx: *TestCtx) !void {
                try ctx.logger.append("StateA.enter");
            }
            pub fn exit(ctx: *TestCtx) !void {
                try ctx.logger.append("StateA.exit");
            }
        },
        StateB: union(enum) {
            SubState1: struct {
                pub fn enter(ctx: *TestCtx) !void {
                    try ctx.logger.append("SubState1.enter");
                }
                pub fn exit(ctx: *TestCtx) !void {
                    try ctx.logger.append("SubState1.exit");
                }
            },
            SubState2: struct {
                pub fn enter(ctx: *TestCtx) !void {
                    try ctx.logger.append("SubState2.enter");
                }
                pub fn exit(ctx: *TestCtx) !void {
                    try ctx.logger.append("SubState2.exit");
                }
            },
            pub fn enter(ctx: *TestCtx) !void {
                try ctx.logger.append("StateB.enter");
            }
            pub fn exit(ctx: *TestCtx) !void {
                try ctx.logger.append("StateB.exit");
            }
        },
    };

    const Machine = StateMachine(MyStates, TestCtx, TestCtxFactory);
    var context_factory = TestCtxFactory{ .alloc = std.testing.allocator };
    var m = Machine.init(std.testing.allocator, &context_factory);
    defer m.deinit();

    // null → StateA
    try m.transitionTo(.StateA);
    // StateA → StateB.SubState1   (exit A; enter B; enter Sub1)
    try m.transitionTo(.{ .StateB = .{ .SubState1 = .{} } });
    // StateB.SubState1 → StateB.SubState2   (exit Sub1; enter Sub2; NO B exit/enter)
    try m.transitionTo(.{ .StateB = .{ .SubState2 = .{} } });
    // Re-transition to same leaf (no-op)
    try m.transitionTo(.{ .StateB = .{ .SubState2 = .{} } });
    // StateB.SubState2 → StateA   (exit Sub2; exit B; enter A)
    try m.transitionTo(.StateA);

    const expected = [_][]const u8{
        "StateA.enter",
        "StateA.exit",
        "StateB.enter",
        "SubState1.enter",
        "SubState1.exit",
        "SubState2.enter",
        "SubState2.exit",
        "StateB.exit",
        "StateA.enter",
    };

    if (DEBUG) {
        std.debug.print("Log length: {d}\n", .{global_logger.?.log.items.len});
        for (global_logger.?.log.items, 0..) |item, idx| {
            std.debug.print("Log[{d}] = '{s}'\n", .{ idx, item });
        }
    }

    try std.testing.expectEqual(expected.len, global_logger.?.log.items.len);
    for (expected, global_logger.?.log.items) |e, a| {
        try std.testing.expectEqualStrings(e, a);
    }
}

test "StateMachine nested LCA transition Leaf1 -> Leaf3" {
    global_logger = Logger.init(std.testing.allocator);
    defer global_logger.?.deinit();

    const MyStates = union(enum) {
        Root: union(enum) {
            Mid1: union(enum) {
                Leaf1: struct {
                    pub fn enter(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf1.enter");
                    }
                    pub fn exit(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf1.exit");
                    }
                },
                Leaf2: struct {
                    pub fn enter(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf2.enter");
                    }
                    pub fn exit(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf2.exit");
                    }
                },
                pub fn enter(ctx: *TestCtx) !void {
                    try ctx.logger.append("Mid1.enter");
                }
                pub fn exit(ctx: *TestCtx) !void {
                    try ctx.logger.append("Mid1.exit");
                }
            },
            Mid2: union(enum) {
                Leaf3: struct {
                    pub fn enter(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf3.enter");
                    }
                    pub fn exit(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf3.exit");
                    }
                },
                Leaf4: struct {
                    pub fn enter(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf4.enter");
                    }
                    pub fn exit(ctx: *TestCtx) !void {
                        try ctx.logger.append("Leaf4.exit");
                    }
                },
                pub fn enter(ctx: *TestCtx) !void {
                    try ctx.logger.append("Mid2.enter");
                }
                pub fn exit(ctx: *TestCtx) !void {
                    try ctx.logger.append("Mid2.exit");
                }
            },
            pub fn enter(ctx: *TestCtx) !void {
                try ctx.logger.append("Root.enter");
            }
            pub fn exit(ctx: *TestCtx) !void {
                try ctx.logger.append("Root.exit");
            }
        },
    };

    const Machine = StateMachine(MyStates, TestCtx, TestCtxFactory);
    var context_factory = TestCtxFactory{ .alloc = std.testing.allocator };
    var m = Machine.init(std.testing.allocator, &context_factory);
    defer m.deinit();

    // null → Root.Mid1.Leaf1
    try m.transitionTo(.{ .Root = .{ .Mid1 = .{ .Leaf1 = .{} } } });
    // Root.Mid1.Leaf1 → Root.Mid2.Leaf3
    try m.transitionTo(.{ .Root = .{ .Mid2 = .{ .Leaf3 = .{} } } });

    const expected = [_][]const u8{
        "Root.enter",
        "Mid1.enter",
        "Leaf1.enter",
        "Leaf1.exit",
        "Mid1.exit",
        "Mid2.enter",
        "Leaf3.enter",
    };

    if (DEBUG) {
        std.debug.print("Log length: {d}\n", .{global_logger.?.log.items.len});
        for (global_logger.?.log.items, 0..) |item, idx| {
            std.debug.print("Log[{d}] = '{s}'\n", .{ idx, item });
        }
    }

    try std.testing.expectEqual(expected.len, global_logger.?.log.items.len);
    for (expected, global_logger.?.log.items) |e, a| {
        try std.testing.expectEqualStrings(e, a);
    }
}

const std = @import("std");
const phasor_phases = @import("phasor-phases");
const StateMachine = phasor_phases.StateMachine;

const DEBUG = false;
