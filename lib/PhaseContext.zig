enter_schedule: *Schedule,
update_schedule: *Schedule,
exit_schedule: *Schedule,

const PhaseContext = @This();

pub fn init(alloc: std.mem.Allocator, app: *App) !PhaseContext {
    return PhaseContext{
        .allocator = alloc,
        .app = app,
        .current_phase = null,
        .next_phase = null,
    };
}

const std = @import("std");
const phasor_ecs = @import("phasor-ecs");
const App = phasor_ecs.App;
const Schedule = phasor_ecs.Schedule;
