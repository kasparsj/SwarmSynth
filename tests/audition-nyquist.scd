// Standard profiles through audition preparation, sampled playback, plots, and NRT.
(
var check, instrument, registry, audition, facade, state, synth, plot;
var runs = List.new, renderNext, directory = "SWARM_NYQUIST_RENDER_DIR".getenv;

check = { |condition, message| if (condition.not) { Error(message).throw } };
try {
	SwarmInstruments.names.do { |name|
		instrument = SwarmInstruments.make(name, [8000]);
		registry = SwarmInstrumentRegistry.new;
		registry.register(name, { |environment|
			(synth: Object.new, state: instrument.state)
		}, (synthDef: \swarm_partial, variant: \natural, hasGate: true),
			instrument.variants, SwarmInstruments.metadata(name));
		audition = SwarmAudition.new(registry, (sampleRate: 48000));
		audition.capture;
		facade = audition.facade;
		[\natural, \soft, \bright].do { |variant|
			audition.update(\variant, variant);
			state = facade[\prepare].value(facade, name, [8000]);
			check.(state.calc(0).asDict[\nyquistMode] == 2,
				"Inherit lost standard profile policy: " ++ name ++ " / " ++ variant);
		};
		check.(instrument.state.args[\nyquistMode] == 2,
			"Preparing audition mutated production policy");
		audition.dispose; registry.dispose; instrument.dispose;
	};

	instrument = SwarmInstruments.make(\clarinet, [8000]);
	registry = SwarmInstrumentRegistry.new;
	registry.register(\clarinet, { |environment|
		(synth: Object.new, state: instrument.state)
	}, (synthDef: \swarm_partial, variant: \natural, hasGate: true),
		instrument.variants, SwarmInstruments.metadata(\clarinet));
	audition = SwarmAudition.new(registry, (sampleRate: 48000));
	audition.capture;
	facade = audition.facade;
	[
		(label: "inherited", setting: -1, expected: 2, policy: \mute, gain: 0),
		(label: "explicit-bypass", setting: 0, expected: 0, policy: \none, gain: 1),
		(label: "explicit-fold", setting: 1, expected: 1, policy: \fold, gain: 1),
		(label: "explicit-mute", setting: 2, expected: 2, policy: \mute, gain: 0),
		(label: "explicit-taper", setting: 3, expected: 3, policy: \taper, gain: 0),
		(label: "restored-inherit", setting: -1, expected: 2, policy: \mute, gain: 0)
	].do { |test|
		audition.update(\nyquistMode, test.setting);
		state = facade[\prepare].value(facade, \clarinet, [8000]);
		synth = SwarmAuditionRecordingSynth.new;
		facade[\sampledPartials].value(facade, (name: \clarinet, synth: synth), state);
		plot = SwarmPartialPlotData.fromCapture(audition.partialCapture, display: \policy);
		check.(synth.params[2].asDict[\freq] == 40000, "Wrong high partial");
		check.(synth.params[2].asDict[\nyquistMode] == test.expected,
			"Sampled playback policy mismatch: " ++ test.label);
		check.(plot[\records][2][\policy] == test.policy
			and: { plot[\records][2][\frequencyGain] == test.gain },
			"Plot and playback policy disagree: " ++ test.label);
		runs.add((label: test.label, args: synth.params[2].copy));
		synth.dispose;
	};
	audition.dispose; registry.dispose; instrument.dispose;
	Score.program = "SCSYNTH".getenv;
	renderNext = {
		if (runs.isEmpty) {
			"PASS: audition inherited Nyquist controls and plots".postln;
			0.exit;
		} {
			var test = runs.removeAt(0), score;
			score = Score([
				[0, [\d_recv, SwarmSynthDefs.partial(\swarm_partial).asBytes]],
				[0.01, [\s_new, \swarm_partial, 1001, 0, 1] ++ test.args],
				[0.3, [\n_free, 1001]], [0.4, [\c_set, 0, 0]]
			]);
			score.recordNRT(directory +/+ (test.label ++ ".osc"),
				directory +/+ (test.label ++ ".wav"), nil, 48000, "WAV", "float",
				ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0), "", nil,
				{ |code| if (code != 0) { 1.exit }; renderNext.value });
		};
	};
	renderNext.value;
} { |error| error.reportError; 1.exit };
)
