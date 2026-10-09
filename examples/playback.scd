// Timed playback borrows state and synths registered by the composition.
(
var variants = (
	original: (args: (
		freq: { |e| e.freq * e.p1 },
		amp: { |e| e.vol / e.p1 }, phase: 0, pan: 0
	), partials: 12, variations: 1)
);

s.waitForBoot {
	SwarmSynthDefs.install;
	~registry = SwarmInstrumentRegistry.new;
	~bellState = SwarmMath.new([110], 12, 1,
		variants[\original][\args].deepCopy, 0.05);
	~bellSynth = SwarmSynth.new(\swarm_pad);
	~registry.register(\bell, { |environment|
		(synth: environment[\bellSynth], state: environment[\bellState])
	}, (synthDef: \swarm_pad, variant: \original,
		hasGate: false, liveSwitch: \nextTrigger), variants, ());

	~bellPhrase = Routine {
		SwarmPlayback.play(~registry, \bell,
			(freq: 220, duration: 0.2), 0.5);
		SwarmPlayback.play(~registry, \bell,
			(freq: 330, duration: 0.4), 1);
	}.play(TempoClock.default);
};
)

// The Environment remains responsible for stopping and disposing its synth.
