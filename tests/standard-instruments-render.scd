(
var directory = "SWARM_STANDARD_RENDER_DIR".getenv;
var capture = SwarmStandardScoreServer(\standardScore, NetAddr("127.0.0.1", 57999));
var originalServer = Server.default;
var specs = List.new, next, definition = SwarmSynthDefs.partial(\swarm_partial).asBytes;
Score.program = "SCSYNTH".getenv;
Server.default = capture;

SwarmInstruments.names.do { |name|
	[\natural, \soft, \bright].do { |variant|
		specs.add((name: name, variant: variant, label: name.asString ++ "-" ++ variant));
	};
};
specs.add((name: \marimba, variant: \natural, label: "marimba-overlap", overlap: true));
specs.add((name: \bell, variant: \natural, label: "bell-overlap", overlap: true));
specs.add((name: \organ, variant: \natural, label: "organ-route", out: 2));
specs.add((name: \marimba, variant: \natural, label: "marimba-nyquist", freq: 30000));
SwarmInstruments.names.do { |name|
	specs.add((name: name, variant: \natural, label: name.asString ++ "-listening", phrase: true));
};

next = {
	var spec, instrument, events, length, score, options, addNote;
	if (specs.isEmpty) {
		"PASS: SwarmInstruments NRT renders".postln;
		Server.default = originalServer;
		0.exit;
	} {
	spec = specs.removeAt(0);
	instrument = SwarmInstruments.make(spec[\name], [spec[\freq] ? 440], 0.2, spec[\variant]);
	capture.startCapture;
	addNote = { |time, frequency|
		capture.scoreTime = time;
		instrument.play((freq: frequency, out: spec[\out] ? 0, gate: 1));
		if (instrument.hasGate) {
			capture.scoreTime = time + 0.8;
			instrument.closeGate;
		};
	};
	if (spec[\phrase] == true) {
		[0, 2, 4, 7].do { |semitones, index| addNote.(0.01 + (index * 0.6), 440 * (2 ** (semitones / 12))) };
		length = 9;
	} {
		addNote.(0.01, spec[\freq] ? 440);
		if (spec[\overlap] == true) { addNote.(0.266, 440) };
		length = 7;
	};
	events = List[[0, [\d_recv, definition]]];
	events.addAll(capture.events);
	// This server-side query must show the default group with no synth children.
	events.add([length - 0.1, [\g_dumpTree, 1, 0]]);
	capture.startCapture;
	capture.scoreTime = length - 0.05;
	instrument.dispose;
	events.addAll(capture.events);
	events.add([length - 0.01, [\g_dumpTree, 0, 0]]);
	events.add([length, [\c_set, 0, 0]]);
	("RENDER: " ++ spec[\label]).postln;
	// Preserve capture order for equal-time group creation and node messages.
	score = Score(events.asArray.collect { |entry, index| [entry, index] }
		.sort { |a, b| if (a[0][0] == b[0][0]) { a[1] < b[1] } { a[0][0] < b[0][0] } }
		.collect { |entry| entry[0] });
	options = ServerOptions.new.numOutputBusChannels_(if(spec[\out].notNil, 4, 2))
		.numInputBusChannels_(0).blockSize_(64);
	score.recordNRT(directory +/+ (spec[\label] ++ ".osc"),
		directory +/+ (spec[\label] ++ ".wav"), nil, 48000, "WAV", "float",
		options, "SWARM_STANDARD_NRT_OPTIONS".getenv ? "", nil, { |code|
			if (code != 0) { ("ERROR: render failed " ++ spec[\label]).postln; 1.exit };
			next.value;
		});
	};
};
try { next.value } { |error| error.reportError; 1.exit };
)
