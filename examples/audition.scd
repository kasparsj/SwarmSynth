// Standalone registry + private audition GUI. Evaluate the whole block.
(
SynthDef(\swarmAuditionSine, { |freq=220, amp=0.02, phase=0, pan=0, gate=1,
	attack=0.01, release=0.4, out=0|
	var envelope = EnvGen.kr(Env.asr(attack, 1, release), gate, doneAction: 2);
	Out.ar(out, Pan2.ar(SinOsc.ar(freq, phase), pan, amp * envelope));
}).add;

s.waitForBoot {
	var variants, registry;
	variants = (
		soft: (args: (
			ratio: { |event| event.p1 },
			freq: { |event| SwarmMath.freqRatio(event) },
			amp: { |event| event.vol / event.p1.squared },
			phase: { 0 }, pan: { |event| event.p.linlin(0, 11, -0.7, 0.7) },
			out: 0
		), partials: 12, variations: 1),
		bright: (args: (
			ratio: { |event| event.p1 },
			freq: { |event| SwarmMath.freqRatio(event) },
			amp: { |event| event.vol / event.p1 },
			phase: { 0 }, pan: { |event| event.p.linlin(0, 19, -0.9, 0.9) },
			out: 0
		), partials: 20, variations: 1)
	);

	~auditionState = SwarmMath.new([110], 12, 1,
		variants[\soft][\args], 0.04);
	~auditionPlayback = SwarmSynth.new(\swarmAuditionSine,
		[\attack, 0.01, \release, 0.4], true);
	registry = SwarmInstrumentRegistry.new;
	registry.register(\sineBank, { |environment|
		(synth: environment[\auditionPlayback], state: environment[\auditionState])
	}, (
		synthDef: \swarmAuditionSine, variant: \soft,
		defaultParams: [\attack, 0.01, \release, 0.4],
		hasGate: true, liveSwitch: \sustained
	), variants, (
		label: "Sine Bank",
		descriptors: [],
		defaultNyquistPolicy: \none,
		releaseKey: \release,
		releaseTime: 0.4,
		preservePhasePan: true
	));

	~audition = SwarmAudition.new(registry, (
		title: "SwarmSynth Audition",
		routes: (dry: 0)
	));
	~audition.open;
};
)

// Later cleanup:
// ~audition.dispose; ~audition.registry.dispose; ~auditionPlayback.dispose;
