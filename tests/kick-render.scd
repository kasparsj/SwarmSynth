(
var directory = "SWARM_KICK_RENDER_DIR".getenv;
var capture = SwarmStandardScoreServer(\kickScore, NetAddr("127.0.0.1", 57999));
var originalServer = Server.default;
var definition = SwarmSynthDefs.kick(\swarm_kick).asBytes;
var specs, next;

Score.program = "SCSYNTH".getenv;
Server.default = capture;
specs = List[
	(name: \natural, label: "kick-natural"),
	(name: \rough, label: "kick-rough"),
	(name: \acoustic, label: "kick-acoustic"),
	(name: \natural, label: "kick-overlap", overlap: true),
	(name: \natural, label: "kick-repeated", repeated: true),
	(name: \rough, label: "kick-extremes", event: (
		duration: -2, attack: -1, detune: -3, sweepRatio: -5,
		sweepTime: -2, drive: -5, pan: 2
	)),
	(name: \natural, label: "kick-nyquist", event: (freq: 30000))
];

next = {
	var spec, instrument, events, score, options, addHit, length = 1.4;
	if (specs.isEmpty) {
		"PASS: Swarm kick NRT renders".postln;
		Server.default = originalServer;
		0.exit;
	} {
		spec = specs.removeAt(0);
		instrument = SwarmInstruments.make(\kick, variant: spec[\name]);
		capture.startCapture;
		addHit = { |time|
			capture.scoreTime = time;
			instrument.play(spec[\event] ? ());
		};
		addHit.(0.01);
		if (spec[\overlap] == true) { addHit.(0.266) };
		if (spec[\repeated] == true) { [0.21, 0.41, 0.61].do(addHit) };
		events = List[[0, [\d_recv, definition]]];
		events.addAll(capture.events);
		events.add([1.15, [\g_dumpTree, 1, 0]]);
		capture.startCapture;
		capture.scoreTime = 1.2;
		instrument.dispose;
		events.addAll(capture.events);
		events.add([1.25, [\g_dumpTree, 0, 0]]);
		events.add([length, [\c_set, 0, 0]]);
		("RENDER: " ++ spec[\label]).postln;
		score = Score(events.asArray.collect { |entry, index| [entry, index] }
			.sort { |a, b| if(a[0][0] == b[0][0]) { a[1] < b[1] } { a[0][0] < b[0][0] } }
			.collect { |entry| entry[0] });
		options = ServerOptions.new.numOutputBusChannels_(2)
			.numInputBusChannels_(0).blockSize_(64).loadDefs_(false);
		score.recordNRT(directory +/+ (spec[\label] ++ ".osc"),
			directory +/+ (spec[\label] ++ ".wav"), nil, 48000, "WAV", "float",
			options, "SWARM_KICK_NRT_OPTIONS".getenv ? "", nil, { |code|
				if (code != 0) { ("ERROR: render failed " ++ spec[\label]).postln; 1.exit };
				next.value;
			});
	};
};
try { next.value } { |error| error.reportError; 1.exit };
)
