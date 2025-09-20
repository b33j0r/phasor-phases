pub fn PhasePlugin(comptime PhasesT: type) type {
    return struct {
        const Phases = PhasesT;
    };
}
