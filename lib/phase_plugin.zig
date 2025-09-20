pub fn PhasePlugin(comptime PhasesT: type) type {
    return struct {
        allocator: std.mem.Allocator,

        const Phases = PhasesT;
        const PhaseMachine = StateMachine(Phases, PhaseContext, Self);

        const Self = @This();

        pub fn build(self: *Self, app: *App) !void {
            const phase_machine = PhaseMachine.init(app.allocator, self);
            try app.insertResource(phase_machine);
            try app.addSystem("Update", Self.updateSystem);
        }

        pub fn create(self: *Self) !PhaseContext {
            return PhaseContext.init(self.allocator);
        }

        pub fn destroy(_: *Self, ctx: *PhaseContext) void {
            ctx.deinit();
        }

        pub fn updateSystem(
            cmds: *Commands,
            r_phase_machine: ResMut(PhaseMachine),
        ) !void {
            // var phase_machine = r_phase_machine.ptr;
            // try phase_machine.update(cmds);
            _ = cmds;
            _ = r_phase_machine;
        }
    };
}

const std = @import("std");

const root = @import("root.zig");
const PhaseContext = root.PhaseContext;
const StateMachine = root.StateMachine;

const phasor_ecs = @import("phasor-ecs");
const App = phasor_ecs.App;
const Schedule = phasor_ecs.Schedule;
const Commands = phasor_ecs.Commands;
const Res = phasor_ecs.Res;
const ResMut = phasor_ecs.ResMut;
