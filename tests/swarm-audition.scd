// Standalone SwarmAudition regression. No server, Qt, or composition is loaded.
(
var check, makeState, variants, registry, environment, playback;
var audition, facade, production, baseline, prepared, error, calls = 0;
var first, second, savedRandom, recording, run, plotted, callbacks;
var noPhraseHooks, phraseAudition, phraseFacade, phraseCalls = 0;

check = { |condition, message| if (condition.not) { Error(message).throw } };
makeState = { |frequency=123, partials=3, variations=2|
	SwarmMath.new([frequency], partials, variations, (
		ratio: { |event| event.p1 },
		freq: { |event| calls = calls + 1; event.freq * event.ratio },
		amp: { |event| calls = calls + 1; event.vol / event.ratio },
		phase: { calls = calls + 1; 2pi.rand },
		pan: { calls = calls + 1; 1.0.rand2 },
		out: 99,
		tone: 0.25,
		nyquistMode: -1
	), 0.2)
};
variants = (
	plain: (args: (
		ratio: { |event| event.p1 },
		freq: { |event| event.freq * event.ratio },
		amp: { |event| event.vol / event.ratio },
		phase: { 0 }, pan: { 0 }, out: 0, tone: 0.25, nyquistMode: -1
	), partials: 3, variations: 2),
	glass: (args: (
		ratio: { |event| event.p1.squared },
		freq: { |event| SwarmMath.freqRatio(event) },
		amp: { |event| event.vol / event.p1.squared },
		phase: { 0 }, pan: { 0 }, out: 0, tone: 0.75, nyquistMode: -1
	), partials: 4, variations: 1)
);

try {
	environment = Environment.new;
	production = makeState.();
	playback = Object.new;
	environment.put(\nebulaState, production);
	environment.put(\nebulaSynth, playback);
	registry = SwarmInstrumentRegistry.new;
	registry.register(\nebulaVoice, { |lookup|
		(synth: lookup[\nebulaSynth], state: lookup[\nebulaState])
	}, (
		synthDef: \swarm_audition_test, variant: \plain,
		defaultParams: [\release, 0.01], hasGate: true,
		liveSwitch: \sustained
	), variants, (
		label: "Nebula Voice",
		descriptors: [
			(key: \tone, label: "Tone", min: 0, max: 1, step: 0.01)
		],
		defaultNyquistPolicy: \fold,
		frequencyInterpretation: { |values| values[\freq] },
		releaseKey: \release, releaseTime: 0.01,
		preservePhasePan: true, auditionGate: true,
		auditionParams: [\release, 0.01]
	));
	check.(registry.names == [\nebulaVoice], "Registry lost arbitrary instrument ordering");
	check.(calls == 0, "Registration evaluated spectral callbacks");
	check.(registry.instruments(environment).isEmpty,
		"Registration eagerly created an instrument wrapper");

	noPhraseHooks = CmdPeriod.objects.size;
	audition = environment.use {
		SwarmAudition.new(registry, (
			nodeLimit: 16,
			captureContext: { (routes: (dry: 0), token: \captured) },
			variantSettings: { |selected| (variant: selected, duration: 0.04, gap: 0.02) },
			variantKey: { |variant, preset| variant }
		))
	};
	facade = audition.facade;
	check.(CmdPeriod.objects.size == (noPhraseHooks + 1),
		"Audition did not install exactly one CmdPeriod hook");
	check.(facade[\context].isNil and: { facade[\run].isNil },
		"Construction captured context or started playback");
	audition.capture;
	check.(facade[\context][\token] == \captured,
		"captureContext result was not retained");
	baseline = facade[\baselines][\nebulaVoice];
	check.(baseline !== production and: { baseline.args !== production.args },
		"Capture shared production SwarmMath state");
	check.(facade[\settings][\nebulaVoice][\duration] == 0.04,
		"variantSettings did not initialize private settings");
	check.(facade[\variantChoices].value(facade) == [\glass, \plain],
		"Arbitrary variants were not exposed in sorted order");

	audition.update(\variant, \glass);
	prepared = facade[\prepare].value(facade, \nebulaVoice, [200]);
	check.(prepared !== baseline and: { prepared !== production },
		"Prepare reused captured or production state");
	check.(prepared.calc(2).asDict[\freq] == 800,
		"variantKey/variant selection did not select the private formula");
	check.(production.freqs == [123] and: { production.partials == 3 }
		and: { production.args[\tone] == 0.25 },
		"Private capture or prepare mutated production state");

	audition.update(\freqs, [100, 200]);
	audition.update(\partials, 4);
	audition.update(\variations, 2);
	check.(facade[\nodeCount].value(facade) == 16,
		"Node count did not include chord, partial, and variation dimensions");
	error = try { audition.update(\partials, 5); nil } { |caught| caught };
	check.(error.notNil and: { error.what.contains("exceeds") },
		"Node cap accepted an oversized audition");
	audition.update(\freqs, [123]);
	audition.update(\partials, 3);
	audition.update(\variations, 2);
	audition.update(\variant, \plain);

	// Preview uses a stable seed and restores the caller's random stream.
	savedRandom = thisThread.randData.copy;
	first = audition.previewPartials.records.deepCopy;
	second = audition.previewPartials.records.deepCopy;
	check.(first == second, "Stopped preview was not deterministic");
	check.(savedRandom == thisThread.randData, "Stopped preview advanced randomness");

	// One playback snapshot feeds both the backend and published capture.
	calls = 0;
	recording = SwarmAuditionRecordingSynth.new;
	run = (name: \nebulaVoice, synth: recording);
	prepared = facade[\prepare].value(facade, \nebulaVoice, [123]);
	facade[\sampledPartials].value(facade, run, prepared);
	check.(calls == (prepared.size * 4),
		"Attack evaluated a spectral callback more than once per node");
	check.(audition.partialCapture.records.collect { |record| record[\values].asPairs.asDict }
		== recording.params.collect { |pairs| pairs.asDict },
		"Published partials differ from playback's merged controls");
	callbacks = calls;
	plotted = SwarmPartialPlotData.fromCapture(audition.partialCapture,
		\frequency, \policy, 0, 0);
	check.(plotted[\records].size == 3, "Plot filters returned the wrong cached nodes");
	check.(calls == callbacks, "Plot projection resampled spectral callbacks");
	check.(plotted[\records].every { |record| record[\policy] == \fold },
		"Plot ignored metadata defaultNyquistPolicy");

	error = try { audition.update(\mode, \phrase); nil } { |caught| caught };
	check.(error.notNil, "Phrase mode was accepted without a phrase callback");
	check.(facade[\settings][\nebulaVoice][\mode] == \single,
		"Rejected phrase mode changed settings");

	// Server-free lifecycle through the supported Event overrides.
	facade[\ready] = { true };
	facade[\makeSynth] = { |self, name| SwarmAuditionRecordingSynth.new };
	audition.update(\duration, 0.04);
	audition.update(\gap, 0.02);
	audition.update(\mode, \repeat);
	Routine {
		try {
			var firstRun, firstSynth, secondRun, child, beforeDispose;
			audition.start;
			firstRun = facade[\run];
			firstSynth = firstRun[\synth];
			0.16.wait;
			check.(firstSynth.sets.size >= 2, "Repeat mode did not retrigger");
			audition.stopAudition;
			check.(facade[\run].isNil and: { firstRun[\active].not }
				and: { firstSynth.isPlaying.not }, "Stop left repeat playback active");

			audition.update(\mode, \single);
			audition.start;
			secondRun = facade[\run];
			child = Routine { 20.wait }.play(secondRun[\clock]);
			secondRun[\children].add(child);
			0.12.wait;
			check.(facade[\run].isNil and: { child.isPlaying.not },
				"Single completion left controller or child routine active");
			beforeDispose = CmdPeriod.objects.size;
			audition.dispose;
			check.(CmdPeriod.objects.size == (beforeDispose - 1),
				"Dispose did not remove the audition CmdPeriod hook");

			// A configured phrase is an explicit third mode and receives context.
			phraseAudition = environment.use {
				SwarmAudition.new(registry, (
					captureContext: { (routes: (dry: 0), marker: \phraseContext) },
					phrase: { |controller, phraseRun, context|
						phraseCalls = phraseCalls + 1;
						check.(context[\marker] == \phraseContext,
							"Phrase callback received wrong captured context");
						controller[\note].value(controller, phraseRun, [246], 0.02, true);
					}
				))
			};
			phraseFacade = phraseAudition.facade;
			phraseAudition.capture;
			phraseFacade[\ready] = { true };
			phraseFacade[\makeSynth] = { SwarmAuditionRecordingSynth.new };
			phraseAudition.update(\mode, \phrase);
			phraseAudition.start;
			0.08.wait;
			check.(phraseCalls == 1, "Phrase callback did not run exactly once");
			phraseAudition.stopAudition;
			phraseAudition.dispose;
			check.(CmdPeriod.objects.size == noPhraseHooks,
				"Repeated lifecycle retained CmdPeriod hooks");

			registry.dispose;
			"PASS: standalone SwarmAudition isolation, sampling, plotting, modes, and lifecycle".postln;
			0.exit;
		} { |caught|
			caught.reportError;
			try { audition.dispose };
			try { phraseAudition !? { |item| item.dispose } };
			1.exit;
		};
	}.play(AppClock);
} { |caught|
	caught.reportError;
	try { audition !? { |item| item.dispose } };
	1.exit;
};
)
