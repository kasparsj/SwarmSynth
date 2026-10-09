// Named timbre variants share one SwarmMath state and one playback object.
(
var variants;

variants = (
	original: (
		args: (
			freq: { |e| e.freq * e.p1 },
			amp: { |e| e.vol / e.p1 },
			phase: { 0 },
			pan: { 0 }
		),
		partials: 12,
		variations: 1
	),
	revised: (
		args: (
			ratio: { |e| e.p1 ** 1.08 },
			freq: { |e| SwarmMath.freqRatio(e) },
			amp: { |e| SwarmMath.ampPower(e, 2) * e.vol },
			phase: { 0 },
			pan: { 0 }
		),
		partials: 12,
		variations: 1
	)
);

~instrument = SwarmInstrument.new(
	\swarm_partial,
	SwarmMath.new([110], 12, 1, variants[\original][\args], 0.08),
	variants,
	variant: \original,
	defaultParams: [\attack, 0.02, \decay, 1, \sustain, 0.7, \release, 1],
	hasGate: true,
	liveSwitch: \sustained
);
)

// Playback is created lazily here. Pitch and volume survive later switches.
~instrument.play((midinote: 45));

// Preserve score-driven partial/variation counts while changing the formula.
~instrument.setVariant(\revised, transitionTime: 0.5, preserveDimensions: true);
~instrument.variant = \original; // immediate switch

~instrument.closeGate;
~instrument.dispose;

// Existing composition playback can be borrowed. dispose only detaches it.
(
~sharedSynth = SwarmSynth.new(\swarm_partial, [\release, 1]);
~borrowed = SwarmInstrument.new(\swarm_partial,
	SwarmMath.new([110], 12, 1, ~instrument.variants[\original][\args], 0.08),
	~instrument.variants, synth: ~sharedSynth);
~borrowed.dispose;
// ~sharedSynth remains owned by the composition.
)
