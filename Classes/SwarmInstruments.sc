// Composition-independent, finite additive spectra. No server-side effects.
SwarmInstruments {
	*names { ^[\flute, \clarinet, \organ, \marimba, \bell, \kick] }

	*prProfile { |name|
		^switch(name,
			\flute, { (
				ratios: [1, 2, 3, 4, 5], weights: [1, 0.12, 0.06, 0.02, 0.01],
				attack: [0.07, 0.09, 0.11, 0.13, 0.15],
				decay: [0.15, 0.12, 0.1, 0.08, 0.06],
				sustain: [0.9, 0.8, 0.7, 0.6, 0.5],
				release: [0.18, 0.15, 0.12, 0.1, 0.08],
				register: [60, 96], label: "Flute",
				description: "Fundamental-led additive flute approximation.",
				articulation: "Gentle gated attack; close the gate between phrases."
			) },
			\clarinet, { (
				ratios: [1, 3, 5, 7, 9], weights: [1, 0.65, 0.3, 0.16, 0.07],
				attack: [0.025, 0.035, 0.045, 0.055, 0.065],
				decay: [0.12, 0.1, 0.08, 0.06, 0.04],
				sustain: [0.9, 0.85, 0.75, 0.65, 0.55],
				release: [0.12, 0.1, 0.08, 0.06, 0.045],
				register: [50, 82], label: "Clarinet",
				description: "Odd-harmonic, low-register clarinet approximation.",
				articulation: "Quick gated articulation; low notes emphasize the hollow spectrum."
			) },
			\organ, { (
				ratios: [1, 2, 3, 4, 5, 6, 7, 8],
				weights: [1, 0.7, 0.5, 0.45, 0.12, 0.22, 0.06, 0.25],
				attack: [0.01, 0.012, 0.014, 0.016, 0.018, 0.02, 0.022, 0.024],
				decay: Array.fill(8, 0.01), sustain: Array.fill(8, 1),
				release: [0.06, 0.055, 0.05, 0.045, 0.04, 0.035, 0.03, 0.025],
				register: [36, 84], label: "Organ",
				description: "Stable harmonic organ with octave and fifth emphasis.",
				articulation: "Short attack and release; hold the gate for steady chords."
			) },
			\marimba, { (
				ratios: [1, 4, 10], weights: [1, 0.3, 0.12],
				attack: [0.003, 0.002, 0.001], decay: [1.2, 0.35, 0.12],
				sustain: [0, 0, 0], release: [0.05, 0.05, 0.05],
				register: [48, 84], label: "Marimba",
				description: "Three-mode additive marimba approximation at 1:4:10.",
				articulation: "Retrigger each strike; upper modes decay before the fundamental."
			) },
			\bell, { (
				ratios: [0.5, 1, 1.2, 1.5, 2, 3], weights: [0.35, 0.8, 0.4, 0.5, 1, 0.15],
				attack: [0.004, 0.003, 0.002, 0.002, 0.001, 0.001],
				decay: [5, 4, 2.8, 3.5, 2, 1.2],
				sustain: Array.fill(6, 0), release: Array.fill(6, 0.05),
				register: [48, 84], label: "Bell",
				description: "Generic inharmonic bell; base pitch is a reference, not its lowest mode.",
				articulation: "Retrigger and let independent modal tails overlap."
			) },
			\kick, { (
				register: [24, 48], label: "Kick",
				description: "Pitch-swept additive kick with electronic, rough, and acoustic-like recipes.",
				articulation: "Retrigger each hit; self-freeing partial tails may overlap."
			) },
			{ Error("SwarmInstruments: unknown instrument %".format(name)).throw }
		);
	}

	*metadata { |name|
		var profile = this.prProfile(name), kick = name == \kick;
		var held = kick.not and: { profile[\sustain].first > 0 };
		^(
			label: profile[\label].copy, register: profile[\register].copy,
			description: profile[\description].copy, articulation: profile[\articulation].copy,
			auditionGate: held, releaseKey: if(kick) { \duration } { \release },
			releaseTime: if (kick) { 0.4 } {
				if (held) { profile[\release].maxItem * 1.3 } {
					profile[\decay].maxItem * 1.25 + 0.01
				}
			},
			defaultDuration: if (kick) { 0.4 } { nil },
			synthDef: if (kick) { \swarm_kick } { \swarm_partial },
			defaultNyquistPolicy: \mute, descriptors: []
		).deepCopy;
	}

	*prKickVariants {
		var variants = IdentityDictionary.new;
		var definitions = (
			natural: (
				ratios: [1, 2, 3, 4, 6], weights: [1, 0.22, 0.1, 0.045, 0.02],
				attacks: [0.0025, 0.0018, 0.0012, 0.0008, 0.0005],
				durations: [0.4, 0.16, 0.085, 0.055, 0.035],
				detunes: [0, 0, 0, 0, 0], sweeps: [3.8, 2.5, 1.8, 1.4, 1.15],
				sweepTimes: [0.05, 0.035, 0.025, 0.018, 0.012], drive: 1
			),
			rough: (
				ratios: [1, 2, 3, 4, 6], weights: [1, 0.34, 0.23, 0.14, 0.08],
				attacks: [0.0015, 0.001, 0.0008, 0.0006, 0.0004],
				durations: [0.42, 0.2, 0.13, 0.09, 0.06],
				detunes: [0, 0.012, -0.018, 0.028, -0.035], sweeps: [4.5, 2.8, 2.1, 1.6, 1.25],
				sweepTimes: [0.055, 0.04, 0.03, 0.022, 0.015], drive: 4
			),
			acoustic: (
				ratios: [1, 1.47, 2.08, 2.72, 3.91], weights: [1, 0.42, 0.28, 0.17, 0.1],
				attacks: [0.003, 0.0018, 0.0012, 0.0008, 0.0005],
				durations: [0.38, 0.25, 0.18, 0.12, 0.075],
				detunes: [0, 0.006, -0.009, 0.013, -0.016], sweeps: [2.8, 1.7, 1.4, 1.2, 1.08],
				sweepTimes: [0.035, 0.025, 0.019, 0.014, 0.01], drive: 1.35
			)
		);
		definitions.keysValuesDo { |variant, definition|
			var weights = definition[\weights] / definition[\weights].sum;
			var args = (
				ratio: { |e| definition[\ratios].at(e.p) ? e.p1 },
				freq: { |e| SwarmMath.freqRatio(e) },
				amp: { |e| (weights.at(e.p) ? 0) * e.vol / e.variations.max(1) },
				duration: 0.4, attack: definition[\attacks].first,
				detune: 0, sweepRatio: definition[\sweeps].first,
				sweepTime: definition[\sweepTimes].first, drive: definition[\drive],
				decayScale: { |e| definition[\durations].clipAt(e.p) / definition[\durations].maxItem },
				attackScale: { |e| definition[\attacks].clipAt(e.p) / definition[\attacks].first },
				detuneOffset: { |e| definition[\detunes].clipAt(e.p) },
				sweepRatioScale: { |e| definition[\sweeps].clipAt(e.p) / definition[\sweeps].first },
				sweepTimeScale: { |e| definition[\sweepTimes].clipAt(e.p) / definition[\sweepTimes].first },
				out: 0, pan: 0, nyquistMode: 2
			);
			variants[variant] = (args: args, partials: definition[\ratios].size, variations: 1);
		};
		^variants;
	}

	*prVariants { |profile|
		var variants = IdentityDictionary.new, ratios = profile[\ratios];
		[\natural, \soft, \bright].do { |variant|
			var tilt, attackScale, decayScale, releaseScale, weights, args;
			tilt = switch(variant, \soft, { -0.6 }, \bright, { 0.45 }, { 0 });
			attackScale = switch(variant, \soft, { 1.5 }, \bright, { 0.65 }, { 1 });
			decayScale = switch(variant, \soft, { 0.8 }, \bright, { 1.25 }, { 1 });
			releaseScale = switch(variant, \soft, { 1.3 }, \bright, { 0.8 }, { 1 });
			weights = profile[\weights].collect { |weight, index|
				weight * (ratios[index] ** tilt)
			};
			weights = weights / weights.sum;
			args = (
				ratio: { |e| ratios.at(e.p) ? e.p1 },
				freq: { |e| SwarmMath.freqRatio(e) },
				amp: { |e| (weights.at(e.p) ? 0) * e.vol / e.variations.max(1) },
				attack: { |e| profile[\attack].clipAt(e.p) * attackScale },
				decay: { |e| profile[\decay].clipAt(e.p) * decayScale },
				sustain: { |e| profile[\sustain].clipAt(e.p) },
				release: { |e| profile[\release].clipAt(e.p) * releaseScale },
				out: 0, phase: 0, pan: 0, gate: 1, nyquistMode: 2
			);
			variants[variant] = (args: args, partials: ratios.size, variations: 1);
		};
		^variants;
	}

	*variants { |name|
		var profile = this.prProfile(name);
		^(if (name == \kick) { this.prKickVariants } { this.prVariants(profile) }).deepCopy;
	}

	*make { |name, freqs=nil, amp=0.1, variant=\natural|
		var profile = this.prProfile(name), variants = this.variants(name);
		var selected = variants[variant], kick = name == \kick;
		var held = kick.not and: { profile[\sustain].first > 0 }, state;
		freqs = freqs ? if (kick) { #[55] } { #[440] };
		SwarmMath.prFrequencies(freqs);
		if (SwarmMath.prFiniteNumber(amp).not or: { amp < 0 }) {
			Error("SwarmInstruments: amp must be a nonnegative finite number").throw;
		};
		if (selected.isNil) {
			Error("SwarmInstruments: unknown variant %".format(variant)).throw;
		};
		state = SwarmMath.new(freqs.copy, selected[\partials], 1, selected[\args], amp);
		^SwarmInstrument.new(if(kick) { \swarm_kick } { \swarm_partial }, state, variants, variant,
			hasGate: held, liveSwitch: if (held) { \sustained } { \nextTrigger });
	}
}
