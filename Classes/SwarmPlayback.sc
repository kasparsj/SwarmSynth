SwarmPlayback {
	*play { |registry, name, event, waitBeats, closeGate=false, excludeParams=nil|
		var resolved, state, synth;
		if (SwarmMath.prFiniteNumber(waitBeats).not or: { waitBeats < 0 }) {
			Error("SwarmPlayback: waitBeats must be a nonnegative finite number").throw;
		};
		resolved = registry.at(name);
		state = resolved[\state];
		synth = resolved[\synth];
		state.putEvent(event);
		synth.set(state, excludeParams: excludeParams);
		waitBeats.wait;
		if (closeGate == true) { synth.closeGate };
		^resolved;
	}
}
