const phase_plugin_mod = @import("phase_plugin.zig");
pub const PhasePlugin = phase_plugin_mod.PhasePlugin;

pub const PhaseContext = @import("PhaseContext.zig");

const state_machine_mod = @import("state_machine.zig");
pub const StateMachine = state_machine_mod.StateMachine;

test "ref all decls" {
    _ = PhasePlugin;
    _ = PhaseContext;
    _ = StateMachine;
}
