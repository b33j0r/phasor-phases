const MyPhases = union(enum) {
    MainMenu: MainMenu,
    InGame: InGame,
};

const MainMenu = struct {
    pub fn enter(_: *MainMenu, ctx: *PhaseContext) !void {
        try ctx.addUpdateSystem(MainMenu.transition_to_in_game);
    }
    pub fn exit(_: *MainMenu, ctx: *PhaseContext) !void {
        _ = ctx; // Unused parameter
    }
};

const InGame = struct {
    pub fn enter(_: *InGame, ctx: *PhaseContext) !void {
        try ctx.addUpdateSystem(InGame.quit_game);
    }
    pub fn exit(_: *InGame, ctx: *PhaseContext) !void {
        _ = ctx; // Unused parameter
    }
};

const MyPhasesPlugin = PhasePlugin(MyPhases);

test "PhasePlugin init" {
    const alloc = std.testing.allocator;
    var app = try App.default(alloc);
    defer app.deinit();

    try app.addPlugin(MyPhasesPlugin{});
}

const std = @import("std");

const phasor_ecs = @import("phasor-ecs");
const App = phasor_ecs.App;
const Commands = phasor_ecs.Commands;

const phasor_phases = @import("phasor-phases");
const PhasePlugin = phasor_phases.PhasePlugin;
const PhaseContext = phasor_phases.PhaseContext;
