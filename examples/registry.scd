// Ordered, dynamically resolved instruments shared by tools and compositions.
(
var variants = (
	soft: (args: (
		freq: { |e| e.freq * e.p1 },
		amp: { |e| e.vol / e.p1 }, phase: 0, pan: 0
	), partials: 12, variations: 1),
	bright: (args: (
		ratio: { |e| e.p1 ** 1.2 },
		freq: { |e| SwarmMath.freqRatio(e) },
		amp: { |e| SwarmMath.ampPower(e, 1.5) * e.vol }, phase: 0, pan: 0
	), partials: 18, variations: 1)
);

~registry = SwarmInstrumentRegistry.new;
~registry.register(\bell, { |environment|
	(synth: environment[\bellSynth], state: environment[\bellState])
}, (
	synthDef: \swarm_partial, variant: \soft,
	hasGate: true, liveSwitch: \sustained
), variants, (label: "Bell"));

~bellSynth = SwarmSynth.new(\swarm_partial);
~bellState = SwarmMath.new([110], 12, 1, variants[\soft][\args], 0.05);
~registry.instrument(\bell).play((midinote: 57));
~registry.instrument(\bell).setVariant(\bright, 0.5, true);
)

// The composition owns ~bellSynth. Registry disposal only detaches it.
~registry.dispose;
