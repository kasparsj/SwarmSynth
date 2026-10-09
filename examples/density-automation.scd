// A complete density-growth example. Definition registration and server boot
// are explicit below; SwarmDensityAutomation itself creates neither.
(
SwarmSynthDefs.sustained(\densityExample).add;
~densityState = SwarmMath.new([55], 4, 1, (
	freq: { |e| e.freq * e.p1 },
	amp: { |e| e.vol / e.p1 },
	detune: 0, detunef: 0, phase: 0, phasef: 0,
	pan: 0, panf: 0, fadeTime: 0.3, gate: 1
), 0.08);

// Boot explicitly before playback.
s.waitForBoot {
	~densitySynth = SwarmSynth.new(\densityExample);
	~densitySynth.set(~densityState);
	~densityRoutine = Routine {
		SwarmDensityAutomation.run(
			~densityState, ~densitySynth, \partials,
			duration: 6, from: ~densityState.partials, to: 24,
			rampTime: 0.3
		);
		~densitySynth.closeGate;
	}.play(TempoClock.default);
};
)

// Stopping the owner cancels further density progression.
// ~densityRoutine.stop;
// ~densitySynth.dispose;
