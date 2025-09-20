enter_schedule: *Schedule,
update_schedule: *Schedule,
exit_schedule: *Schedule,

const PhaseContext = @This();

pub fn init(alloc: std.mem.Allocator) !PhaseContext {
    return PhaseContext{
        .enter_schedule = try Schedule.init(alloc),
        .update_schedule = try Schedule.init(alloc),
        .exit_schedule = try Schedule.init(alloc),
    };
}

pub fn deinit(self: *PhaseContext) void {
    self.enter_schedule.deinit();
    self.update_schedule.deinit();
    self.exit_schedule.deinit();
}

pub fn addEnterSystem(self: *PhaseContext, system: anytype) !void {
    try self.enter_schedule.addSystem(system);
}

pub fn addUpdateSystem(self: *PhaseContext, system: anytype) !void {
    try self.update_schedule.addSystem(system);
}

pub fn addExitSystem(self: *PhaseContext, system: anytype) !void {
    try self.exit_schedule.addSystem(system);
}

pub fn update(self: *PhaseContext, world: *World) !void {
    try self.update_schedule.run(world);
}

const std = @import("std");
const phasor_ecs = @import("phasor-ecs");
const App = phasor_ecs.App;
const Schedule = phasor_ecs.Schedule;
const Commands = phasor_ecs.Commands;
const World = phasor_ecs.World;
