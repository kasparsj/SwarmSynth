(
var root = PathName(thisProcess.nowExecutingPath).pathOnly.dirname;
var renderDirectory = "SWARM_SYNTHDEF_RENDER_DIR".getenv;
var scsynth = "SCSYNTH".getenv;
var definitions = IdentityDictionary.new, specs, options, renderNext, fail;
var seeded;

fail = { |message| ("ERROR: " ++ message).postln; 1.exit };
if (renderDirectory.isNil or: { PathName(renderDirectory).isFolder.not }) {
	fail.("Missing SwarmSynthDefs render directory");
};
if (scsynth.isNil or: { File.exists(scsynth).not }) {
	fail.("Missing scsynth executable");
};

try {
	Score.program = scsynth;
	(root +/+ "tests/fixtures/legacy-sine-synthdefs.scd").load;
	seeded = { |source, name|
		var definition = SynthDef(name, {
			RandSeed.ir(1, 20261009);
			SynthDef.wrap(source.func);
		});
		definitions[name] = definition.asBytes;
	};

	seeded.(~legacySineSynthDefs[\partial].value(\legacyPartial), \baseline_partial);
	seeded.(SwarmSynthDefs.partial(\currentPartial), \current_partial);
	seeded.(~legacySineSynthDefs[\sustained].value(\legacySustained), \baseline_sustained);
	seeded.(SwarmSynthDefs.sustained(\currentSustained), \current_sustained);
	seeded.(~legacySineSynthDefs[\pad].value(\legacyPad), \baseline_pad);
	seeded.(SwarmSynthDefs.pad(\currentPad), \current_pad);
	seeded.(~legacySineSynthDefs[\chip].value(\legacyChip), \baseline_chip);
	seeded.(SwarmSynthDefs.chip(\currentChip), \current_chip);

	specs = List.new;
	[\baseline, \current].do { |variant|
		specs.add((family: \partial, label: "partial-transient", variant: variant,
			args: [\freq, 30000, \amp, 0.1, \attack, 0.005, \decay, 0.12,
				\phase, 0.3, \pan, -0.25, \nyquistMode, 1]));
		specs.add((family: \partial, label: "partial-gated", variant: variant, gate: true,
			args: [\freq, 880, \amp, 0.1, \attack, 0.005, \decay, 0.02,
				\sustain, 0.7, \release, 0.03, \phase, 0.2, \pan, 0.25,
				\nyquistMode, 0]));
		specs.add((family: \sustained, label: "sustained-modulated", variant: variant, gate: true,
			args: [\freq, 1234, \amp, 0.1, \fadeTime, 0.01,
				\pulse, 0.4, \pulsef, 9, \pulsew, 0.35,
				\saw, 0.25, \sawf, 7, \mod, 0.3, \modf, 5,
				\detune, 0.04, \detunef, 11, \phasef, 3, \panf, 4]));
		specs.add((family: \pad, label: "pad-detuned", variant: variant,
			args: [\freq, 987, \amp, 0.1, \duration, 0.12,
				\detune, -0.03, \detunef, 8, \phase, 0.2, \pan, 0.35]));
		specs.add((family: \pad, label: "pad-route-out2", variant: variant,
			outputChannels: 4,
			args: [\out, 2, \freq, 660, \amp, 0.1, \duration, 0.12,
				\detune, 0, \detunef, 0, \phase, 0.2, \pan, -0.2]));
		specs.add((family: \chip, label: "chip-legacy-enabled", variant: variant,
			args: [\freq, 30000, \detune, 0.01, \duration, 0.12,
				\amp, 0.1, \phase, 0.4, \pan, -0.4]));
		[
			["chip-policy-none", 0, 1], ["chip-policy-fold", 1, 1],
			["chip-policy-mute", 2, 1], ["chip-policy-taper", 3, 1],
			["chip-legacy-bypass", -1, 0]
		].do { |policy|
			specs.add((family: \chip, label: policy[0], variant: variant,
				args: [\freq, 30000, \duration, 0.12, \amp, 0.1,
					\phase, 0.4, \pan, -0.4, \nyquistMode, policy[1],
					\foldNyquist, policy[2]]));
		};
	};
	renderNext = {
		var spec, name, events, score, outputPath, oscPath;
		if (specs.isEmpty) {
			"PASS: SwarmSynthDefs seeded NRT parity".postln;
			0.exit;
		} {
			spec = specs.removeAt(0);
			name = (spec[\variant].asString ++ "_" ++ spec[\family].asString).asSymbol;
			events = List[
				[0.0, [\d_recv, definitions[name]]],
				[0.01, [\s_new, name, 1000, 0, 1] ++ spec[\args]]
			];
			if (spec[\gate] == true) { events.add([0.18, [\n_set, 1000, \gate, 0]]) };
			events.add([0.35, [\c_set, 0, 0]]);
			score = Score(events);
			options = ServerOptions.new
				.numOutputBusChannels_(spec[\outputChannels] ? 2)
				.numInputBusChannels_(0)
				.blockSize_(64)
				.loadDefs_(false);
			outputPath = renderDirectory +/+ (spec[\variant].asString ++ "-"
				++ spec[\label] ++ ".wav");
			oscPath = renderDirectory +/+ (spec[\variant].asString ++ "-"
				++ spec[\label] ++ ".osc");
			score.recordNRT(oscPath, outputPath, nil, 48000, "WAV", "float",
				options, "SWARM_SYNTHDEF_NRT_OPTIONS".getenv ? "", nil, { |exitCode|
					if (exitCode != 0) {
						fail.("scsynth failed for %".format(name));
					} {
						renderNext.();
					};
				});
		};
	};
	renderNext.();
} { |error|
	error.reportError;
	1.exit;
};
)
