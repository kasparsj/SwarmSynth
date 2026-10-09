(
var root = "SWARM_DIRT_ROOT".getenv;
var capture, originalServer, dirt, manager, check, orbit;

check = { |condition, message| if (condition.not) { Error(message).throw } };

try {
    thisProcess.interpreter.executeFile(root +/+ "superdirt/SwarmDirt.scd");
    capture = SwarmStandardScoreServer(\swarmDirtReal, NetAddr("127.0.0.1", 57997));
    originalServer = Server.default;
    Server.default = capture;
    dirt = SuperDirt(2, capture);
    manager = ~installSwarmDirt.(dirt);
    manager.registerStandardInstruments;
    check.([\swVoice, \swPanic, \swFlute, \swClarinet, \swOrgan, \swMarimba, \swBell]
        .every { |name| dirt.soundLibrary.at(name).notNil },
        "real DirtSoundLibrary missed an adapter registration");
    orbit = DirtOrbit.newCopyArgs(dirt, 0, 0);
    orbit.makeDefaultParentEvent;
    [\swFlute, \swVoice].do { |sound|
        [0, 2, 4, 7].do { |note|
            var event = (s: sound, n: note, octave: 5), freq;
            event.parent = orbit.defaultParentEvent;
            event.proto = dirt.soundLibrary.at(sound).first;
            freq = event.use { ~freq.value };
            check.(freq.isNumber and: { (freq - (60 + note).midicps).abs < 0.0001 },
                "real Dirt parent resolved n=% to % for %".format(note, freq, sound));
        };
        [(n: 99, note: 2, octave: 5), (n: 99, midinote: 62),
            (n: 99, freq: 62.midicps)].do { |event|
            var freq;
            event.parent = orbit.defaultParentEvent;
            event.proto = dirt.soundLibrary.at(sound).first;
            freq = event.use { ~freq.value };
            check.(freq.isNumber and: { (freq - 62.midicps).abs < 0.0001 },
                "explicit pitch did not override n for %".format(sound));
        };
    };
    manager.dispose;
    check.([\swVoice, \swPanic, \swFlute, \swClarinet, \swOrgan, \swMarimba, \swBell]
        .every { |name| dirt.soundLibrary.at(name).isNil },
        "adapter disposal left registrations in real DirtSoundLibrary");
    dirt.free;
    Server.default = originalServer;
    "PASS: SwarmDirt real SuperDirt registration smoke".postln;
    0.exit;
} { |error|
    error.reportError;
    "FAIL: SwarmDirt real SuperDirt registration smoke".postln;
    1.exit;
};
)
