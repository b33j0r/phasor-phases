const MyPhases = union(enum) {
    MainMenu: MainMenu,
    InGame: InGame,
    Quit,
};

const Logged = struct {
    name: []const u8,
};

const MainMenu = struct {
    pub fn enter(_: *MainMenu, ctx: *PhaseContext) !void {
        try ctx.addEnterSystem(log_enter);
        try ctx.addExitSystem(log_exit);
        try ctx.addUpdateSystem(transition_to_in_game);
    }

    fn log_enter(logger: EventWriter(Logged)) !void {
        try logger.send(Logged{ .name = "MainMenu.enter" });
    }

    fn log_exit(logger: EventWriter(Logged)) !void {
        try logger.send(Logged{ .name = "MainMenu.exit" });
    }

    fn transition_to_in_game(cmds: *Commands) !void {
        try cmds.insertResource(NextPhase{ .phase = MyPhases.InGame });
    }
};

const InGame = struct {
    pub fn enter(_: *InGame, ctx: *PhaseContext) !void {
        try ctx.addEnterSystem(log_enter);
        try ctx.addExitSystem(log_exit);
        try ctx.addUpdateSystem(quit_game);
    }

    fn log_enter(logger: EventWriter(Logged)) !void {
        try logger.send(Logged{ .name = "InGame.enter" });
    }

    fn log_exit(logger: EventWriter(Logged)) !void {
        try logger.send(Logged{ .name = "InGame.exit" });
    }

    fn quit_game(cmds: *Commands) !void {
        try cmds.insertResource(NextPhase{ .phase = MyPhases.Quit });
    }
};

const MyPhasesPlugin = PhasePlugin(MyPhases, MyPhases{ .MainMenu = .{} });
const NextPhase = MyPhasesPlugin.NextPhase;
const CurrentPhase = MyPhasesPlugin.CurrentPhase;

test "PhasePlugin sequence MainMenu -> InGame -> Quit" {
    const alloc = std.testing.allocator;
    var app = try App.default(alloc);
    defer app.deinit();

    try app.registerEvent(Logged, 100);
    try app.addPlugin(MyPhasesPlugin{ .allocator = alloc });

    // Run the startup systems first
    _ = try app.runSchedulesFrom("PreStartup");

    // Then run the first frame
    _ = try app.step(); // 1. MainMenu.enter
    _ = try app.step(); // 2. MainMenu.exit → InGame.enter
    _ = try app.step(); // 3. InGame.exit → Quit

    // Verify log sequence
    const log = app.world.getResource(Events(Logged)).?;
    const expected = [_][]const u8{
        "MainMenu.enter",
        "MainMenu.exit",
        "InGame.enter",
        "InGame.exit",
    };

    for (expected) |exp| {
        const ev = try log.tryRecv() orelse {
            std.debug.print("Expected event: {s}\n", .{exp});
            return error.MissingEvent;
        };
        try std.testing.expectEqualStrings(exp, ev.name);
    }

    // Verify final phase really is Quit
    const cur = app.world.getResource(CurrentPhase).?;
    try std.testing.expect(cur.phase == MyPhases.Quit);
}

// Imports
const std = @import("std");

const phasor_ecs = @import("phasor-ecs");
const App = phasor_ecs.App;
const Commands = phasor_ecs.Commands;
const Events = phasor_ecs.Events;
const EventWriter = phasor_ecs.EventWriter;
const EventReader = phasor_ecs.EventReader;
const Res = phasor_ecs.Res;
const ResMut = phasor_ecs.ResMut;

const phasor_phases = @import("phasor-phases");
const PhasePlugin = phasor_phases.PhasePlugin;
const PhaseContext = phasor_phases.PhaseContext;
