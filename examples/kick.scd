// Shared additive kick. Evaluate after recompiling the SwarmSynth classes.
(
s.waitForBoot {
	SwarmSynthDefs.install;
	s.sync;

	~kick = SwarmInstruments.make(\kick, amp: 0.1);
	~kick.play; // Deep Electronic (natural), 55 Hz, 0.4 seconds.

	Routine {
		0.6.wait;
		~kick.setVariant(\rough);
		~kick.play((freq: 50, drive: 5));
		0.6.wait;
		~kick.setVariant(\acoustic);
		~kick.play((freq: 60, duration: 0.5));
	}.play;
};
)

// Stop early and remove owned playback:
// ~kick.dispose;
