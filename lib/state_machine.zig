const std = @import("std");

// ─────────────────────────────────────────────────────────────────────────────
// Hierarchical StateMachine core
// ─────────────────────────────────────────────────────────────────────────────

pub fn StateMachine(comptime States: type, comptime Context: type) type {
    return struct {
        const Self = @This();

        ctx: *Context,
        current: ?States = null,

        pub fn init(ctx: *Context) Self {
            return .{
                .ctx = ctx,
                .current = null,
            };
        }

        /// Transition with hierarchical semantics:
        /// - Compute LCA between current and next
        /// - Exit from leaf up to (but not including) the LCA
        /// - Enter from just below the LCA down to the leaf
        pub fn transitionTo(self: *Self, next: States) !void {
            if (self.current) |cur| {
                // Exit only the differing suffix of the current path
                try self.exitDiff(cur, next);
                // Enter only the differing suffix of the next path
                try self.enterDiff(cur, next);
                self.current = next;
                return;
            }

            // Initial enter when there is no current state
            try self.callEnterRecursive(next);
            self.current = next;
        }

        // ── Diff helpers (compute difference around Lowest Common Ancestor) ──

        fn exitDiff(self: *Self, cur: anytype, nxt: anytype) !void {
            const CurT = @TypeOf(cur);
            const NxtT = @TypeOf(nxt);

            switch (@typeInfo(CurT)) {
                .@"union" => {
                    if (CurT == NxtT) {
                        const cur_tag = std.meta.activeTag(cur);
                        const nxt_tag = std.meta.activeTag(nxt);
                        if (cur_tag == nxt_tag) {
                            // Same parent state and same tag - only exit the inner states
                            switch (cur) {
                                inline else => |cur_inner, tag| {
                                    const nxt_inner = @field(nxt, @tagName(tag));
                                    try self.exitDiff(cur_inner, nxt_inner);
                                },
                            }
                            return;
                        }
                    }
                    // Different parent or different tag → exit entire current branch
                    switch (cur) {
                        inline else => |inner| {
                            try self.callExitRecursive(inner);
                        },
                    }
                    // Exit the parent state only if moving to a different parent
                    if (CurT != NxtT) {
                        if (@hasDecl(CurT, "exit")) {
                            try CurT.exit(self.ctx);
                        }
                    }
                },
                .@"struct" => {
                    // Leaf: if leaves differ (by type), exit this leaf
                    if (CurT != NxtT) {
                        if (@hasDecl(CurT, "exit")) {
                            try CurT.exit(self.ctx);
                        }
                    }
                },
                else => {}, // Not expected in this design
            }
        }

        fn enterDiff(self: *Self, cur: anytype, nxt: anytype) !void {
            const CurT = @TypeOf(cur);
            const NxtT = @TypeOf(nxt);

            switch (@typeInfo(NxtT)) {
                .@"union" => {
                    if (CurT == NxtT) {
                        const cur_tag = std.meta.activeTag(cur);
                        const nxt_tag = std.meta.activeTag(nxt);
                        if (cur_tag == nxt_tag) {
                            // Same parent state and same tag - only enter the inner states
                            switch (nxt) {
                                inline else => |nxt_inner, tag| {
                                    const cur_inner = @field(cur, @tagName(tag));
                                    try self.enterDiff(cur_inner, nxt_inner);
                                },
                            }
                            return;
                        }
                    }
                    // Enter the parent state only if coming from a different parent
                    if (CurT != NxtT) {
                        if (@hasDecl(NxtT, "enter")) {
                            try NxtT.enter(self.ctx);
                        }
                    }
                    // Enter the inner states
                    switch (nxt) {
                        inline else => |inner| {
                            try self.callEnterRecursive(inner);
                        },
                    }
                },
                .@"struct" => {
                    // Leaf: if leaves differ (by type), enter this leaf
                    if (CurT != NxtT) {
                        if (@hasDecl(NxtT, "enter")) {
                            try NxtT.enter(self.ctx);
                        }
                    }
                },
                else => {}, // Not expected in this design
            }
        }

        // ── Hierarchical enter/exit walkers ──
        // Enter: parent first, then child
        fn callEnterRecursive(self: *Self, v: anytype) !void {
            const T = @TypeOf(v);
            switch (@typeInfo(T)) {
                .@"union" => {
                    if (@hasDecl(T, "enter")) {
                        try T.enter(self.ctx);
                    }
                    switch (v) {
                        inline else => |inner| {
                            try self.callEnterRecursive(inner);
                        },
                    }
                },
                .@"struct" => {
                    if (@hasDecl(T, "enter")) {
                        try T.enter(self.ctx);
                    }
                },
                else => {},
            }
        }

        // Exit: child first, then parent
        fn callExitRecursive(self: *Self, v: anytype) !void {
            const T = @TypeOf(v);
            switch (@typeInfo(T)) {
                .@"union" => {
                    switch (v) {
                        inline else => |inner| {
                            try self.callExitRecursive(inner);
                        },
                    }
                    if (@hasDecl(T, "exit")) {
                        try T.exit(self.ctx);
                    }
                },
                .@"struct" => {
                    if (@hasDecl(T, "exit")) {
                        try T.exit(self.ctx);
                    }
                },
                else => {},
            }
        }

        fn typeShortName(comptime T: type) []const u8 {
            const full = @typeName(T);
            var i: usize = full.len;
            while (i > 0) : (i -= 1) {
                if (full[i - 1] == '.') break;
            }
            return full[i..];
        }
    };
}

test "StateMachine hierarchical enter/exit with sibling-substate optimization" {
    const MyContext = struct {
        allocator: std.mem.Allocator = std.testing.allocator,
        log: std.ArrayListUnmanaged([]const u8) = .empty,
        const Self = @This();
        pub fn append(self: *Self, msg: []const u8) !void {
            try self.log.append(self.allocator, msg);
        }
        pub fn deinit(self: *Self) void {
            self.log.deinit(self.allocator);
        }
    };

    const MyStates = union(enum) {
        StateA: struct {
            pub fn enter(ctx: *MyContext) !void {
                try ctx.append("StateA.enter");
            }
            pub fn exit(ctx: *MyContext) !void {
                try ctx.append("StateA.exit");
            }
        },
        StateB: union(enum) {
            SubState1: struct {
                pub fn enter(ctx: *MyContext) !void {
                    try ctx.append("SubState1.enter");
                }
                pub fn exit(ctx: *MyContext) !void {
                    try ctx.append("SubState1.exit");
                }
            },
            SubState2: struct {
                pub fn enter(ctx: *MyContext) !void {
                    try ctx.append("SubState2.enter");
                }
                pub fn exit(ctx: *MyContext) !void {
                    try ctx.append("SubState2.exit");
                }
            },
            pub fn enter(ctx: *MyContext) !void {
                try ctx.append("StateB.enter");
            }
            pub fn exit(ctx: *MyContext) !void {
                try ctx.append("StateB.exit");
            }
        },
    };

    var ctx = MyContext{};
    defer ctx.deinit();

    const Machine = StateMachine(MyStates, MyContext);
    var m = Machine.init(&ctx);

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

    std.debug.print("Log length: {d}\n", .{ctx.log.items.len});
    for (ctx.log.items, 0..) |item, idx| {
        std.debug.print("Log[{d}] = '{s}'\n", .{ idx, item });
    }

    try std.testing.expectEqual(expected.len, ctx.log.items.len);
    for (expected, ctx.log.items, 0..) |e, a, idx| {
        if (!std.mem.eql(u8, e, a)) {
            std.debug.print("Log mismatch at {d}: expected='{s}' actual='{s}'\n", .{ idx, e, a });
        }
        try std.testing.expectEqualStrings(e, a);
    }
}

test "StateMachine nested LCA transition Leaf1 -> Leaf3" {
    const MyContext = struct {
        allocator: std.mem.Allocator = std.testing.allocator,
        log: std.ArrayListUnmanaged([]const u8) = .empty,
        const Self = @This();
        pub fn append(self: *Self, msg: []const u8) !void {
            try self.log.append(self.allocator, msg);
        }
        pub fn deinit(self: *Self) void {
            self.log.deinit(self.allocator);
        }
    };

    const MyStates = union(enum) {
        Root: union(enum) {
            Mid1: union(enum) {
                Leaf1: struct {
                    pub fn enter(ctx: *MyContext) !void {
                        try ctx.append("Leaf1.enter");
                    }
                    pub fn exit(ctx: *MyContext) !void {
                        try ctx.append("Leaf1.exit");
                    }
                },
                Leaf2: struct {
                    pub fn enter(ctx: *MyContext) !void {
                        try ctx.append("Leaf2.enter");
                    }
                    pub fn exit(ctx: *MyContext) !void {
                        try ctx.append("Leaf2.exit");
                    }
                },
                pub fn enter(ctx: *MyContext) !void {
                    try ctx.append("Mid1.enter");
                }
                pub fn exit(ctx: *MyContext) !void {
                    try ctx.append("Mid1.exit");
                }
            },
            Mid2: union(enum) {
                Leaf3: struct {
                    pub fn enter(ctx: *MyContext) !void {
                        try ctx.append("Leaf3.enter");
                    }
                    pub fn exit(ctx: *MyContext) !void {
                        try ctx.append("Leaf3.exit");
                    }
                },
                Leaf4: struct {
                    pub fn enter(ctx: *MyContext) !void {
                        try ctx.append("Leaf4.enter");
                    }
                    pub fn exit(ctx: *MyContext) !void {
                        try ctx.append("Leaf4.exit");
                    }
                },
                pub fn enter(ctx: *MyContext) !void {
                    try ctx.append("Mid2.enter");
                }
                pub fn exit(ctx: *MyContext) !void {
                    try ctx.append("Mid2.exit");
                }
            },

            pub fn enter(ctx: *MyContext) !void {
                try ctx.append("Root.enter");
            }
            pub fn exit(ctx: *MyContext) !void {
                try ctx.append("Root.exit");
            }
        },
    };

    var ctx = MyContext{};
    defer ctx.deinit();

    const Machine = StateMachine(MyStates, MyContext);
    var m = Machine.init(&ctx);

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

    std.debug.print("Log length: {d}\n", .{ctx.log.items.len});
    for (ctx.log.items, 0..) |item, idx| {
        std.debug.print("Log[{d}] = '{s}'\n", .{ idx, item });
    }

    try std.testing.expectEqual(expected.len, ctx.log.items.len);
    for (expected, ctx.log.items) |e, a| {
        try std.testing.expectEqualStrings(e, a);
    }
}
