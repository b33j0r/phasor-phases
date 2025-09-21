const std = @import("std");

const phasor_ecs = @import("phasor-ecs");
const Schedule = phasor_ecs.Schedule;
const World = phasor_ecs.World;

enter_schedule: *Schedule,
update_schedule: *Schedule,
exit_schedule: *Schedule,

const PhaseContext = @This();

pub fn init(alloc: std.mem.Allocator) !PhaseContext {
    const enter_schedule = try alloc.create(Schedule);
    errdefer alloc.destroy(enter_schedule);
    enter_schedule.* = Schedule.init(alloc);

    const update_schedule = try alloc.create(Schedule);
    errdefer alloc.destroy(update_schedule);
    update_schedule.* = Schedule.init(alloc);

    const exit_schedule = try alloc.create(Schedule);
    errdefer alloc.destroy(exit_schedule);
    exit_schedule.* = Schedule.init(alloc);

    return .{
        .enter_schedule = enter_schedule,
        .update_schedule = update_schedule,
        .exit_schedule = exit_schedule,
    };
}

pub fn deinit(self: *PhaseContext) void {
    const alloc = self.enter_schedule.allocator;

    self.enter_schedule.deinit();
    alloc.destroy(self.enter_schedule);

    self.update_schedule.deinit();
    alloc.destroy(self.update_schedule);

    self.exit_schedule.deinit();
    alloc.destroy(self.exit_schedule);
}

pub fn addEnterSystem(self: *PhaseContext, system: anytype) !void {
    try self.enter_schedule.*.add(system);
}
pub fn addUpdateSystem(self: *PhaseContext, system: anytype) !void {
    try self.update_schedule.*.add(system);
}
pub fn addExitSystem(self: *PhaseContext, system: anytype) !void {
    try self.exit_schedule.*.add(system);
}

pub fn runEnter(self: *PhaseContext, world: *World) !void {
    try self.enter_schedule.*.run(world);
}
pub fn runExit(self: *PhaseContext, world: *World) !void {
    try self.exit_schedule.*.run(world);
}
pub fn update(self: *PhaseContext, world: *World) !void {
    try self.update_schedule.*.run(world);
}
