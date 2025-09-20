pub fn PhaseMachine(comptime PhasesT: type) type {
    return struct {
        const Phases = PhasesT;
    };
}
