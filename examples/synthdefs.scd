(
// Builders neither register SynthDefs nor boot a server.
~customSustain = SwarmSynthDefs.sustained(\exampleSwarmSustain);
~customSustain.add;

~spectrum = SwarmMath.new([110, 165], 8, 1, (
	amp: { |e| (e.vol / e.p1) * 0.25 },
	freq: { |e| e.freq * e.p1 },
	detune: 0.005,
	detunef: 0,
	phase: 0,
	phasef: 0,
	pan: { |e| e.i.linlin(0, e.size - 1, -0.8, 0.8) },
	panf: 0,
	fadeTime: 0.25,
	gate: 1
), 0.08);

// Boot explicitly before playback.
s.waitForBoot {
	~voice = SwarmSynth.new(\exampleSwarmSustain);
	~voice.set(~spectrum);
};
)

// Stop and release:
// ~voice.closeGate;
// ~voice.dispose;

// Install all canonical definitions when desired:
// SwarmSynthDefs.install;
