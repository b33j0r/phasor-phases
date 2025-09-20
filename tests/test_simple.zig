const MyPhases = union(enum) {
    MainMenu: MainMenu,
    InGame: InGame,
    Quit,
};

const MainMenu = struct {
    pub fn enter(_: *MainMenu, ctx: *PhaseContext) !void {
        try ctx.addUpdateSystem(transition_to_in_game);
    }

    pub fn transition_to_in_game(cmds: *Commands) !void {
        try cmds.insertResource(NextPhase{ .phase = MyPhases.InGame });
    }
};

const InGame = struct {
    pub fn enter(_: *InGame, ctx: *PhaseContext) !void {
        try ctx.addUpdateSystem(quit_game);
    }

    pub fn quit_game(cmds: *Commands) !void {
        try cmds.insertResource(NextPhase{ .phase = MyPhases.Quit });
    }
};

const MyPhasesPlugin = PhasePlugin(MyPhases);
const NextPhase = MyPhasesPlugin.NextPhase;

test "PhasePlugin init" {
    const alloc = std.testing.allocator;
    var app = try App.default(alloc);
    defer app.deinit();

    try app.addPlugin(MyPhasesPlugin{ .allocator = alloc });
}

const std = @import("std");

const phasor_ecs = @import("phasor-ecs");
const App = phasor_ecs.App;
const Commands = phasor_ecs.Commands;

const phasor_phases = @import("phasor-phases");
const PhasePlugin = phasor_phases.PhasePlugin;
const PhaseContext = phasor_phases.PhaseContext;
