pub fn PhasePlugin(comptime PhasesT: type) type {
    return struct {
        const Phases = PhasesT;
        const Machine = PhaseMachine(Phases);
    };
}

const root = @import("root.zig");
const PhaseMachine = root.PhaseMachine;
