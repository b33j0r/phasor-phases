pub fn PhaseListener(PhasesT: type) type {
    return struct {
        on_phase_enter: ?*const fn (phase: PhasesT, ctx: *PhaseContext) anyerror!void = null,
        on_phase_exit: ?*const fn (phase: PhasesT, ctx: *PhaseContext) anyerror!void = null,

        const Self = @This();

        pub const empty = Self{
            .on_phase_enter = null,
            .on_phase_exit = null,
        };
    };
}

pub fn PhaseContextStack(PhasesT: type) type {
    return struct {
        allocator: std.mem.Allocator,
        stack: std.ArrayListUnmanaged(*PhaseContext) = .empty,

        pub const Phases = PhasesT;

        const Self = @This();

        pub fn init(alloc: std.mem.Allocator) !Self {
            return Self{
                .allocator = alloc,
            };
        }
    };
}

pub fn PhasePlugin(PhasesT: type, initial_phase: PhasesT) type {
    return struct {
        phase_context_stack: Stack,

        pub const Phases = PhasesT;
        pub const Stack = PhaseContextStack(Phases);
        pub const NextPhase = struct { phase: Phases };
        pub const CurrentPhase = struct { phase: Phases };

        const Self = @This();

        pub fn init(alloc: std.mem.Allocator) !Self {
            return Self{
                .phase_context_stack = try Stack.init(alloc),
            };
        }

        pub fn build(_: *Self, app: *App) !void {
            try app.addSystem("Startup", handleInitialPhase);
            try app.addSystem("BetweenFrames", Self.handlePhaseTransitions);
            try app.addSystem("Update", Self.updateCurrentPhaseStack);
        }

        fn handleInitialPhase(commands: *Commands) !void {
            try commands.insertResource(CurrentPhase{ .phase = initial_phase });
        }

        pub fn getCurrentPhase(commands: *Commands) !Phases {
            const current_phase_res = try commands.getResource(CurrentPhase);
            return current_phase_res.phase;
        }

        pub fn getNextPhase(commands: *Commands) !?Phases {
            if (commands.getResource(NextPhase)) |next_phase_res| {
                return next_phase_res.phase;
            } else {
                return null;
            }
        }

        pub fn setNextPhase(commands: *Commands, phase: Phases) !void {
            if (commands.getResource(NextPhase)) |next_phase_res| {
                next_phase_res.phase = phase;
            } else {
                try commands.insertResource(NextPhase{ .phase = phase });
            }
        }

        fn replaceCurrentPhase(commands: *Commands, phase: Phases) !void {
            const current_phase_res = try commands.getResource(CurrentPhase);
            current_phase_res.phase = phase;
        }

        fn clearNextPhase(commands: *Commands) !void {
            try commands.removeResource(NextPhase);
        }

        fn handlePhaseTransitions(commands: *Commands) !void {
            _ = commands;
        }

        fn updateCurrentPhaseStack(commands: *Commands) !void {
            _ = commands;
        }
    };
}

const std = @import("std");

const ecs = @import("phasor-ecs");
const App = ecs.App;
const Commands = ecs.Commands;
const Schedule = ecs.Schedule;
const World = ecs.World;

const root = @import("root.zig");
const PhaseContext = root.PhaseContext;
