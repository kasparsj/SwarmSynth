// Standalone Qt smoke. It uses unrelated names and no project dependencies.
(
var check, makeArgs, makeState, registry, environment, audition, facade, firstWindow;
var variantsA, variantsB, productionA, productionB, playbackA, playbackB;

check = { |condition, message| if (condition.not) { Error(message).throw } };
makeArgs = { |power=1|
	(
		ratio: { |event| event.p1 ** power },
		freq: { |event| event.freq * event.ratio },
		amp: { |event| event.vol / event.ratio },
		phase: { 0 }, pan: { 0 }, out: 0, tone: 0.5, nyquistMode: -1
	)
};
makeState = { |frequency, args, variations=1|
	SwarmMath.new(frequency.asArray, 3, variations, args.deepCopy.asPairs, 0.1)
};
variantsA = (
	cloud: (args: makeArgs.(1), partials: 3, variations: 2),
	crystal: (args: makeArgs.(1.2), partials: 3, variations: 2)
);
variantsB = (
	ember: (args: makeArgs.(0.8), partials: 2, variations: 1),
	metal: (args: makeArgs.(1.5), partials: 2, variations: 1),
	noise: (args: makeArgs.(2), partials: 2, variations: 1)
);

try {
	environment = Environment.new;
	productionA = makeState.([120, 180], variantsA[\cloud][\args], 2);
	productionB = makeState.(240, variantsB[\ember][\args]);
	playbackA = SwarmAuditionRecordingSynth.new;
	playbackB = SwarmAuditionRecordingSynth.new;
	environment.put(\auroraState, productionA);
	environment.put(\auroraSynth, playbackA);
	environment.put(\cinderState, productionB);
	environment.put(\cinderSynth, playbackB);
	registry = SwarmInstrumentRegistry.new;
	registry.register(\aurora, { |lookup|
		(synth: lookup[\auroraSynth], state: lookup[\auroraState])
	}, (synthDef: \guiSmoke, variant: \cloud, hasGate: false), variantsA,
		(label: "Aurora", descriptors: [(key: \tone, label: "Tone", min: 0, max: 1)]));
	registry.register(\cinder, { |lookup|
		(synth: lookup[\cinderSynth], state: lookup[\cinderState])
	}, (synthDef: \guiSmoke, variant: \ember, hasGate: false), variantsB,
		(label: "Cinder", descriptors: [(key: \tone, label: "Tone", min: 0, max: 1)]));
	audition = environment.use {
		SwarmAudition.new(registry, (
			nodeLimit: 16,
			captureContext: { (routes: (dry: 0)) },
			variantSettings: { |selected| (variant: selected, duration: 0.05, gap: 0.05) },
			variantKey: { |variant| variant },
			title: "SwarmAuditionGUI smoke",
			makeSynth: { SwarmAuditionRecordingSynth.new }
		))
	};
	facade = audition.facade;
	check.(facade[\window].isNil and: { facade[\partialCapture].isNil },
		"Construction created Qt or sampled a preview");
	// A deferred open invalidated by disposal must never build a window.
	{
		var disposed = environment.use { SwarmAudition.new(registry, (
			nodeLimit: 16, captureContext: { (routes: (dry: 0)) },
			variantSettings: { |selected| (variant: selected) }, variantKey: { |variant| variant }
		)) };
		disposed.open;
		disposed.dispose;
		AppClock.sched(0.05, {
			check.(disposed.facade[\window].isNil,
				"Dispose before deferred open still created a window");
			nil
		});
	}.value;
	// Two queued opens should collapse to the newest request.
	audition.open;
	audition.open;
	Routine {
		try {
			var gui, firstCapture, staleStatus;
			0.25.wait;
			gui = facade[\guiViews];
			check.(facade[\window].notNil and: { facade[\window].isClosed.not },
				"Open did not create a live window");
			check.(gui[\partialView].notNil and: { gui[\partialDisplay].notNil },
				"GUI did not publish cached-partial handles");
			check.(gui[\instrument].items.asArray == ["Aurora", "Cinder"],
				"Default instrument formatting ignored registry labels");
			check.(facade[\partialCapture].notNil, "Open did not publish a partial preview");
			check.(gui[\variant].items.asArray == ["cloud", "crystal"],
				"First instrument variant inventory was not rendered");
			check.(gui[\mode].items.size == 2,
				"Phrase was shown without a phrase callback");
			check.(gui[\count].string.contains("/ 16"), "Configured node limit was not shown");
			check.(playbackA.sets.isEmpty and: { playbackB.sets.isEmpty },
				"Opening the GUI drove borrowed production playback");
			gui[\partialBase].valueAction_(2);
			gui[\partialVariation].valueAction_(2);

			gui[\instrument].valueAction_(1);
			check.(facade[\selected] == \cinder, "Instrument selection did not reach the controller");
			check.(gui[\variant].items.asArray == ["ember", "metal", "noise"],
				"Variant menu did not rebuild for the selected instrument");
			check.(gui[\partialBase].value == 0 and: { gui[\partialVariation].value == 0 },
				"Unavailable partial filters were not normalized to All");
			gui[\variant].valueAction_(2);
			check.(facade[\settings][\cinder][\variant] == \noise,
				"Arbitrary variant selection did not update private settings");
			check.(registry.instrument(\cinder, environment).variant == \ember,
				"GUI variant selection changed the production wrapper");
			firstCapture = facade[\partialCapture];
			gui[\partialDisplay].valueAction_(1);
			gui[\partialAxis].valueAction_(1);
			check.(facade[\partialCapture] === firstCapture,
				"Plot interaction resampled the controller capture");

			firstWindow = facade[\window];
			staleStatus = facade[\onStatus];
			staleStatus.value("queued before close");
			firstWindow.close;
			0.15.wait;
			check.(facade[\window].isNil and: { facade[\guiViews].isNil },
				"Close retained GUI ownership");
			audition.open;
			0.2.wait;
			check.(facade[\window].notNil and: { facade[\window] !== firstWindow },
				"Reopen reused a closed window");
			// Simulate Qt closing the native window without delivering onClose.
			// The generation-guarded monitor must run the same ownership cleanup.
			facade[\window].onClose_({});
			facade[\window].close;
			0.15.wait;
			check.(facade[\window].isNil and: { facade[\guiViews].isNil },
				"Closed-window fallback retained GUI ownership");
			audition.dispose;
			"PASS: standalone SwarmAuditionGUI variants, cached plot, and lifecycle".postln;
			0.exit;
		} { |caught| caught.reportError; 1.exit };
	}.play(AppClock);
} { |caught| caught.reportError; 1.exit };
)
