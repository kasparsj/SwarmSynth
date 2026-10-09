(
var root = "SWARM_DIRT_ROOT".getenv;
var directory = "SWARM_DIRT_RENDER_DIR".getenv;
var capture = SwarmDirtRenderServer(\swarmDirtRender, NetAddr("127.0.0.1", 57996));
var originalServer = Server.default, library, dirt, manager, orbit, dirtEvent;
var definition, options, names, sounds, durations, render;

try {
    Score.program = "SCSYNTH".getenv;
    Server.default = capture;
    thisProcess.interpreter.executeFile(root +/+ "superdirt/SwarmDirt.scd");
    library = SwarmDirtTestLibrary.new;
    dirt = SwarmDirtTestDirt(2, library);
    manager = ~installSwarmDirt.(dirt, 2048, 8192,
        (now: { 0 }, schedule: { |delay, action| nil }));
    manager.registerStandardInstruments;
    orbit = (server: capture, orbitIndex: 0, group: Group.basicNew(capture, 1),
        dryBus: (index: 0), globalEffects: []);
    dirtEvent = (orbit: orbit);
    definition = SwarmSynthDefs.partial(\swarm_partial).asBytes;
    options = ServerOptions.new.numOutputBusChannels_(2)
        .numInputBusChannels_(0).blockSize_(64);
    names = [\flute, \clarinet, \organ, \marimba, \bell];
    sounds = [\swFlute, \swClarinet, \swOrgan, \swMarimba, \swBell];
    durations = [2.0, 2.0, 2.0, 3.0, 7.0];

    render = { |index|
        var event, events, score, basename, held, ids;
        if (index >= names.size) {
            manager.dispose;
            Server.default = originalServer;
            "PASS: SwarmDirt standard-instrument NRT renders".postln;
            0.exit;
        } {
            capture.startCapture;
            capture.scoreTime = 0.01;
            event = (midinote: 69, out: 0, synthGroup: 1, sustain: 0.4,
                latency: 0, fadeTime: 0, gain: 1, swSeed: 4312 + index);
            event.use { library.at(sounds[index])[\playInside].value(dirtEvent) };
            held = manager.definitions[sounds[index]][\instrument].hasGate;
            if (held) {
                ids = capture.events.select { |entry| entry[1][0] == \s_new }
                    .collect { |entry| entry[1][2] };
                ids.do { |id| capture.events.add([0.41, [\n_set, id, \gate, 0]]) };
            };
            events = List[[0, [\d_recv, definition]]];
            events.addAll(capture.events);
            events.add([durations[index], [\c_set, 0, 0]]);
            score = Score(events.asArray.collect { |entry, order| [entry, order] }
                .sort { |a, b| if (a[0][0] == b[0][0]) { a[1] < b[1] } { a[0][0] < b[0][0] } }
                .collect { |entry| entry[0] });
            basename = "swarm-dirt-" ++ names[index].asString;
            score.recordNRT(directory +/+ (basename ++ ".osc"),
                directory +/+ (basename ++ ".wav"), nil, 48000, "WAV", "float",
                options, "", nil, { |code|
                    if (code != 0) {
                        "ERROR: SwarmDirt % NRT render failed".format(names[index]).postln;
                        Server.default = originalServer;
                        1.exit;
                    };
                    render.value(index + 1);
                });
        };
    };
    render.value(0);
} { |error|
    error.reportError;
    Server.default = originalServer;
    "FAIL: SwarmDirt standard-instrument NRT renders".postln;
    1.exit;
};
)
