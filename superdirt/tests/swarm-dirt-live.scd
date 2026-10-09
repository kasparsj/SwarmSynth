(
var root = "SWARM_DIRT_ROOT".getenv;
var recording = "SWARM_DIRT_LIVE_RECORDING".getenv;
var server = Server(\swarmDirtLive, NetAddr("127.0.0.1", 57995));
var check = { |condition, message| if (condition.not) { Error(message).throw } };
var sawOverlap = false, sawVoice = false, sawStableUpdate = false;
var sawGrowth = false, sawVariationReduction = false;
var sawTimeout = false, sawPanicFixture = false;
var firstIds, lastHeldIds, started;
var receivedPitches = Set.new, adapter;
var rehearsalDuration = ("SWARM_DIRT_LIVE_DURATION".getenv ? "13.5").asFloat;

server.options.numBuffers = 4096;
server.options.maxNodes = 16384;
server.options.numOutputBusChannels = 2;
server.options.numInputBusChannels = 0;
server.waitForBoot {
    try {
        Server.default = server;
        thisProcess.interpreter.executeFile(root +/+ "superdirt/SwarmDirt.scd");
        ~dirt = SuperDirt(2, server);
        ~dirt.start(57220, [0]);
        server.sync;
        if ("SWARM_DIRT_LIVE_TRACE".getenv == "1") { server.dumpOSC(1) };
        ~swDirt = ~installSwarmDirt.(~dirt);
        ~swDirt.registerStandardInstruments;
        adapter = ~swDirt;
        {
            var registration = ~dirt.soundLibrary.at(\swMarimba).first;
            var original = registration[\playInside];
            registration[\playInside] = { |dirtEvent|
                var expected = ((~n ? 0) + 60).midicps;
                var prepared = adapter.prepare(\swMarimba, currentEnvironment.copy);
                check.(~freq.isNumber and: { (~freq - expected).abs < 0.0001 },
                    "Tidal UDP n did not reach Dirt as a numeric pitch");
                check.((prepared[\state].freqs.first - expected).abs < 0.0001,
                    "Tidal UDP pitch did not reach the sampled instrument state");
                receivedPitches.add(~n.asInteger);
                ["UDP_PITCH", ~n, ~freq, prepared[\state].freqs.first].postln;
                original.value(dirtEvent);
            };
        }.value;
        server.recHeaderFormat = "wav";
        server.recSampleFormat = "float";
        server.prepareForRecord(recording);
        server.sync;
        server.record;
        started = Main.elapsedTime;
        "READY: SwarmDirt live rehearsal".postln;
        Routine {
            while { (Main.elapsedTime - started) < rehearsalDuration } {
                var elapsed = Main.elapsedTime - started;
                var voice = ~swDirt.voices.values.first;
                if (~swDirt.notes.size >= 2) { sawOverlap = true };
                if (voice.notNil and: { voice[\key].contains("42") }) {
                    var heldIds = voice[\playback].synths.collect(_.nodeID);
                    if (heldIds != lastHeldIds) {
                        "HELD_IDS % %".format(elapsed.round(0.001), heldIds).postln;
                        lastHeldIds = heldIds.copy;
                    };
                    if (firstIds.isNil) {
                        firstIds = heldIds.copy;
                        sawVoice = true;
                    };
                    if (voice[\count] >= 5 and: {
                        voice[\playback].synths.copyRange(0, firstIds.size - 1)
                            .collect(_.nodeID) == firstIds
                    }) { sawStableUpdate = true };
                    if (voice[\state].partials >= 8) { sawGrowth = true };
                    if (voice[\state].partials >= 8 and: {
                        voice[\state].variations == 1 and: { voice[\count] == 8 }
                    }) { sawVariationReduction = true };
                };
                if (elapsed > 6.2 and: { sawGrowth and: { ~swDirt.voices.isEmpty } }) {
                    sawTimeout = true;
                };
                if (voice.notNil and: { voice[\key].contains("43") }) {
                    sawPanicFixture = true;
                };
                0.05.wait;
            };
            try {
                server.stopRecording;
                0.5.wait;
                check.(sawOverlap, "live Tidal transport did not create overlapping notes");
                check.([0, 4, 7].every { |note| receivedPitches.includes(note) },
                    "live Tidal n pattern did not resolve all three pitches: %".format(receivedPitches));
                check.(sawVoice, "live Tidal transport did not create a held voice");
                check.(sawStableUpdate, "held update did not preserve initial node identities");
                check.(sawGrowth, "live held voice did not reach its growth target");
                check.(sawVariationReduction,
                    "live held voice did not complete delayed variation reduction");
                check.(sawTimeout, "silenced hold did not expire through its heartbeat timeout");
                check.(sawPanicFixture, "panic fixture voice was never created");
                check.(~swDirt.generation > 0 and: { ~swDirt.voices.isEmpty and: {
                    ~swDirt.nodeCount == 0 and: { ~swDirt.pendingCount == 0 }
                } }, "swPanic did not clear live adapter ownership");
                ~swDirt.dispose;
                ~dirt.free;
                server.quit;
                "PASS: SwarmDirt live Tidal transport rehearsal".postln;
                0.exit;
            } { |error|
                error.reportError;
                ~swDirt.freeAll;
                server.stopRecording;
                server.quit;
                "FAIL: SwarmDirt live Tidal transport rehearsal".postln;
                1.exit;
            };
        }.play(SystemClock);
    } { |error|
        error.reportError;
        "FAIL: SwarmDirt live Tidal transport rehearsal".postln;
        server.quit;
        1.exit;
    };
};
server.boot;
)
