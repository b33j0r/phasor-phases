pub fn StateMachine(comptime States: type, comptime Context: type, comptime ContextFactory: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        context_factory: *ContextFactory,

        // One context per *active level* in the current state path (root .. leaf).
        // Index 0 = topmost active level; last = current leaf level.
        ctx_stack: std.ArrayListUnmanaged(*Context) = .empty,

        current: ?States = null,

        pub fn init(
            allocator: std.mem.Allocator,
            context_factory: *ContextFactory,
        ) Self {
            return .{
                .allocator = allocator,
                .context_factory = context_factory,
                .ctx_stack = .empty,
                .current = null,
            };
        }

        pub fn deinit(self: *Self) void {
            // Defensive: if the machine is dropped while some contexts are live, drain them properly
            var i: usize = self.ctx_stack.items.len;
            while (i > 0) {
                i -= 1;
                self.context_factory.destroy(self.ctx_stack.items[i]);
            }
            self.ctx_stack.deinit(self.allocator);
        }

        /// LCA semantics:
        /// - exit from the current leaf up to (but not including) the LCA
        /// - enter from just below the LCA down to the new leaf
        pub fn transitionTo(self: *Self, next: States) !void {
            if (self.current) |cur| {
                try self.exitDiff(cur, next);
                try self.enterDiff(cur, next);
                self.current = next;
                return;
            }
            // Initial activation: enter the entire next branch (root→leaf)
            try self.enterWhole(next);
            self.current = next;
        }

        inline fn pushCtx(self: *Self) !*Context {
            const ctx = try self.context_factory.create();
            try self.ctx_stack.append(self.allocator, ctx);
            return ctx;
        }

        inline fn topCtx(self: *Self) *Context {
            return self.ctx_stack.items[self.ctx_stack.items.len - 1];
        }

        inline fn popCtx(self: *Self) void {
            const ctx = self.ctx_stack.pop().?;
            if (@hasDecl(ContextFactory, "destroy")) {
                self.context_factory.destroy(ctx);
            }
        }

        fn exitDiff(self: *Self, cur: anytype, nxt: anytype) !void {
            const CurT = @TypeOf(cur);
            const NxtT = @TypeOf(nxt);

            switch (@typeInfo(CurT)) {
                .@"union" => {
                    if (CurT == NxtT) {
                        const cur_tag = std.meta.activeTag(cur);
                        const nxt_tag = std.meta.activeTag(nxt);
                        if (cur_tag == nxt_tag) {
                            // Same parent & same tag → dive deeper; no exit at this level.
                            switch (cur) {
                                inline else => |cur_inner, tag| {
                                    const nxt_inner = @field(nxt, @tagName(tag));
                                    try self.exitDiff(cur_inner, nxt_inner);
                                },
                            }
                            return;
                        }

                        // Same parent union but different tag → exit *only the active child*.
                        // Keep the parent union's context alive.
                        try self.exitActiveChildOnly(cur);
                        return;
                    }

                    // Different union types → exit the whole current branch (child→parent).
                    try self.exitWhole(cur);
                },
                .@"struct" => {
                    // At leaf: if leaf types differ, this leaf is going away → exit it at this level.
                    if (CurT != NxtT) {
                        if (@hasDecl(CurT, "exit")) {
                            try CurT.exit(self.topCtx());
                        }
                        self.popCtx();
                    }
                },
                else => {},
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
                            // Same parent & same tag → dive deeper; no enter at this level.
                            switch (nxt) {
                                inline else => |nxt_inner, tag| {
                                    const cur_inner = @field(cur, @tagName(tag));
                                    try self.enterDiff(cur_inner, nxt_inner);
                                },
                            }
                            return;
                        }

                        // Same parent union, different tag → enter *only the new child*.
                        // Reuse the existing parent union context; do not re-enter parent.
                        try self.enterChildOnly(nxt);
                        return;
                    }

                    // Different union types → enter the whole next branch (parent→child).
                    try self.enterWhole(nxt);
                },
                .@"struct" => {
                    // At leaf: if leaf types differ, enter the new leaf *at this level*.
                    if (CurT != NxtT) {
                        const ctx = try self.pushCtx();
                        if (@hasDecl(NxtT, "enter")) {
                            try NxtT.enter(ctx);
                        }
                    }
                },
                else => {},
            }
        }

        /// Enter the entire subtree `v` (parent first, then descendants), allocating
        /// a fresh context for *each* level and keeping them until corresponding exits.
        fn enterWhole(self: *Self, v: anytype) !void {
            const T = @TypeOf(v);
            switch (@typeInfo(T)) {
                .@"union" => {
                    // Enter this union level (push a new context for it)
                    const ctx = try self.pushCtx();
                    if (@hasDecl(T, "enter")) {
                        try T.enter(ctx);
                    }
                    // Then enter the active child
                    switch (v) {
                        inline else => |inner| {
                            try self.enterWhole(inner);
                        },
                    }
                },
                .@"struct" => {
                    // Enter this leaf level (push new context)
                    const ctx = try self.pushCtx();
                    if (@hasDecl(T, "enter")) {
                        try T.enter(ctx);
                    }
                },
                else => {},
            }
        }

        /// Exit the entire subtree `v` (descendants first, then this level),
        /// calling exits with the matching contexts and popping them.
        fn exitWhole(self: *Self, v: anytype) !void {
            const T = @TypeOf(v);
            switch (@typeInfo(T)) {
                .@"union" => {
                    // Exit the active child first
                    switch (v) {
                        inline else => |inner| {
                            try self.exitWhole(inner);
                        },
                    }
                    // Then exit this union level with its context, and pop it
                    if (@hasDecl(T, "exit")) {
                        try T.exit(self.topCtx());
                    }
                    self.popCtx();
                },
                .@"struct" => {
                    if (@hasDecl(T, "exit")) {
                        try T.exit(self.topCtx());
                    }
                    self.popCtx();
                },
                else => {},
            }
        }

        /// Exit only the *active child* subtree of a union value, leaving the
        /// union level (and its context) mounted.
        fn exitActiveChildOnly(self: *Self, u: anytype) !void {
            switch (u) {
                inline else => |inner| {
                    // This will exit the child's entire subtree and pop exactly
                    // the child's stack frames, but *not* the parent's.
                    try self.exitWhole(inner);
                },
            }
        }

        /// Enter only the *child* subtree of a union value, assuming the union
        /// level is already mounted (context already on the stack).
        fn enterChildOnly(self: *Self, u: anytype) !void {
            switch (u) {
                inline else => |inner| {
                    try self.enterWhole(inner);
                },
            }
        }
    };
}

const std = @import("std");
