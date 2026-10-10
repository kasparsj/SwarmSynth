(
var root = "SWARM_DIRT_ROOT".getenv;
var check, approx, expectError, capture, originalServer, library, dirt;
var clock = 0.0, queue = List.new, runtime, advance, manager, previous;
var orbit, dirtEvent, messages, noteEvent, secondNote, tokens, voiceEvent, voice, ids, oldCount;
var growthKey, growthPartials, rampEvent, rampRoutine, kickDefinition, kickRegistration, prepared;

check = { |condition, message| if (condition.not) { Error(message).throw } };
approx = { |actual, wanted, tolerance=0.0001| (actual - wanted).abs <= tolerance };
expectError = { |action, fragment, message|
    var error = try { action.value; nil } { |caught| caught };
    check.(error.notNil and: {
        fragment.isNil or: { error.what.asString.toLower.contains(fragment.asString.toLower) }
    }, message);
};

try {
    check.(thisProcess.interpreter.compileFile(root +/+ "superdirt/examples/standard-instruments.scd")
        .isKindOf(Function), "standard-instruments example failed to compile");
    check.(thisProcess.interpreter.executeFile(root +/+ "superdirt/SwarmDirt.scd").notNil,
        "SwarmDirt adapter failed to compile");
    check.(~installSwarmDirt.isKindOf(Function), "installer was not defined");
    expectError.({ ~installSwarmDirt.(SwarmDirtTestDirt(4), 8, 16) }, "stereo",
        "installer accepted a non-stereo Dirt instance");

    capture = SwarmStandardScoreServer(\swarmDirtCapture, NetAddr("127.0.0.1", 57998));
    originalServer = Server.default;
    Server.default = capture;
    library = SwarmDirtTestLibrary.new;
    dirt = SwarmDirtTestDirt(2, library);
    runtime = (
        now: { clock },
        schedule: { |delay, action| queue.add((due: clock + delay, action: action)) }
    );
    advance = { |target|
        var ready, item;
        while {
            ready = queue.select { |entry| entry.due <= target }
                .sort { |a, b| a.due < b.due };
            ready.notEmpty
        } {
            item = ready.first;
            queue.remove(item);
            clock = item.due;
            item.action.value;
        };
        clock = target;
    };

    manager = ~installSwarmDirt.(dirt, 2048, 8192, runtime);
    check.(manager.active and: { library.at(\swVoice).notNil and: { library.at(\swPanic).notNil } },
        "installer did not register command sounds");
    manager.registerStandardInstruments;
    check.([\swFlute, \swClarinet, \swOrgan, \swMarimba, \swBell, \swKick].every { |name|
        manager.definitions[name].notNil and: { library.at(name).notNil }
    }, "standard registrations were incomplete");
    check.(manager.definitions.size == 6,
        "standard registration unexpectedly depended on project instruments");
    check.(manager.definitions[\swKick].instrument.variantNames
        == [\acoustic, \natural, \rough], "kick variants were not registered canonically");
    prepared = manager.prepare(\swKick, (swVariant: "rough", swDetune: 0.03,
        swKickSweepRatio: 7, swKickSweepTime: 0.02, swKickAttack: 0.003,
        swKickDrive: 1.8));
    check.(prepared.variant == \rough and: {
        prepared.state.args[\detune] == 0.03 and: {
        prepared.state.args[\sweepRatio] == 7 and: {
        prepared.state.args[\sweepTime] == 0.02 and: {
        prepared.state.args[\attack] == 0.003 and: {
        prepared.state.args[\drive] == 1.8 } } } } },
        "kick controls did not map to SynthDef arguments");
    check.(manager.prepare(\swKick, (swVariant: "acoustic")).variant == \acoustic,
        "kick acoustic variant did not prepare");

    // Standard installation is additive on an existing manager. A project may
    // own swKick and its catalog before asking for the other standard sounds.
    manager.removeInstrument(\swKick);
    voice = SwarmInstruments.make(\flute);
    manager.registerInstrument(\swKick, voice, 0.4);
    voice.dispose;
    kickDefinition = manager.definitions[\swKick];
    kickRegistration = manager.registrations[\swKick];
    manager.registerStandardInstruments;
    check.(manager.definitions[\swKick] === kickDefinition and: {
        manager.registrations[\swKick] === kickRegistration and: {
        manager.definitions[\swKick].instrument.variantNames == [\bright, \natural, \soft] }
    }, "standard registration replaced an existing project swKick catalog");

    // Registration owns independent copies of the instrument and mutable state.
    voice = SwarmInstruments.make(\flute);
    manager.registerInstrument(\swTestClone, voice, 0.4);
    check.(manager.definitions[\swTestClone].instrument !== voice and: {
        manager.definitions[\swTestClone].instrument.state !== voice.state
    }, "registration borrowed instrument or state identity");
    voice.state.partials = 1;
    check.(manager.definitions[\swTestClone].instrument.state.partials != 1,
        "registration shared caller state after installation");
    voice.dispose;

    orbit = (
        server: capture,
        orbitIndex: 0,
        group: Group.basicNew(capture, 100),
        dryBus: (index: 16),
        globalEffects: []
    );
    dirtEvent = (orbit: orbit);

    // Match DirtEvent.calcTimeSpan: resolve freq using the registration proto
    // before the callback. Tidal n must change pitch, rather than sound index only.
    [\swFlute, \swVoice].do { |sound|
        var pitches = [0, 2, 4, 7].collect { |note|
            var event = (n: note, octave: 5);
            event.proto = library.at(sound);
            event[\freq] = event.use { ~freq.value };
            manager.prepare(\swFlute, event)[\state].freqs.first;
        };
        check.(pitches == [60, 62, 64, 67].midicps,
            "Tidal n/octave did not resolve four distinct pitches for %".format(sound));
    };

    // Independent notes are placed in Dirt's synth group and preserve timestamp.
    capture.startCapture;
    capture.scoreTime = 1.25;
    noteEvent = (midinote: 69, out: 4, synthGroup: 120, sustain: 0.5,
        latency: 0.1, fadeTime: 0, gain: 0.5, swSeed: 19);
    noteEvent.use { library.at(\swFlute)[\playInside].value(dirtEvent) };
    messages = capture.events.collect { |entry| entry[1] }
        .select { |message| message[0] == \s_new };
    check.(messages.notEmpty and: { messages.every { |message|
        message[4] == 120 and: { message.copyRange(5, message.size - 1).asDict[\out] == 4 }
    } }, "note messages missed Dirt output or synth group");
    check.(capture.events.select { |entry| entry[1][0] == \s_new }
        .every { |entry| entry[0] == 1.25 }, "note messages lost Dirt bundle time");
    check.(manager.notes.size == 1 and: { manager.nodeCount == messages.size },
        "note allocation accounting changed");
    check.(approx.(noteEvent[\sustain], 0.5 + manager.definitions[\swFlute][\releaseTime]),
        "playInside did not extend Dirt's event lifetime by the recipe tail");
    // Raw partials retain the normalized recipe budget. Dirt's gate synth
    // applies amp*gain once after playInside and the remaining modules.
    check.(approx.(messages.collect { |message|
        message.copyRange(5, message.size - 1).asDict[\amp]
    }.sum, 0.1), "playInside scaled partial amps before Dirt's gate synth");
    secondNote = noteEvent.copy.putAll((midinote: 72, sustain: 0.5,
        swPartials: 3, swSeed: 20));
    capture.scoreTime = 1.3;
    secondNote.use { library.at(\swFlute)[\playInside].value(dirtEvent) };
    tokens = manager.notes.asArray;
    check.(tokens.size == 2 and: { tokens.collect { |token| token[\count] }.sort == [3, 5] },
        "overlapping note events did not retain independent dimensions");
    check.(tokens.collect { |token| token.ids }.flatten.asSet.size == 8,
        "overlapping note events reused node identifiers");
    advance.(1.0);
    check.(manager.notes.isEmpty and: { manager.nodeCount == 0 },
        "independent note cleanup did not release accounting");

    // Persistent holds update one stable voice; resizing preserves existing ids.
    voiceEvent = (swInstrument: \swOrgan, swVoiceId: 7, midinote: 48,
        swPartials: 4, swVariations: 1, swOp: \hold, delta: 0.25,
        latency: 0, gain: 0.6, pan: 0.2);
    manager.applyVoice(dirtEvent, voiceEvent, clock);
    voice = manager.voices.values.first;
    ids = voice.playback.synths.collect(_.nodeID);
    check.(manager.voices.size == 1 and: { voice[\count] == 4
        and: { manager.nodeCount == 7 } },
        "first persistent hold did not create one four-node voice");
    rampEvent = voiceEvent.copy.putAll((swDetune: 0.02, swRampSeconds: 2));
    manager.applyVoice(dirtEvent, rampEvent, clock + 0.001);
    rampRoutine = voice[\playback].rampRoutine;
    check.(rampRoutine.notNil, "ramped persistent update did not start a ramp");
    manager.applyVoice(dirtEvent, rampEvent, clock + 0.002);
    check.(voice[\playback].rampRoutine === rampRoutine,
        "unchanged heartbeat restarted or cancelled the sampled ramp");
    voice[\playback].cancelRamp;
    manager.applyVoice(dirtEvent, voiceEvent.copy.put(\swPartials, 6), clock + 0.01);
    check.(manager.voices.values.first === voice and: {
        voice.playback.synths.copyRange(0, 3).collect(_.nodeID) == ids
    }, "persistent update retriggered the voice instead of resizing it");
    check.(voice[\count] == 6 and: { manager.nodeCount == 9 },
        "persistent growth accounting changed");
    manager.applyVoice(dirtEvent, voiceEvent.copy.put(\swPartials, 3), clock + 0.02);
    check.(voice[\count] == 3 and: { manager.nodeCount == 9
        and: { manager.tails.size == 1 } },
        "persistent shrink did not account for releasing surplus nodes");
    advance.(clock + 0.5);
    check.(manager.tails.isEmpty and: { manager.nodeCount == 6
        and: { manager.voices.values.first === voice } },
        "persistent shrink tail did not settle independently");

    // Explicit release retains a tail and timeout release behaves the same way.
    oldCount = manager.nodeCount;
    manager.applyVoice(dirtEvent, (swVoiceId: 7, swOp: \release), clock + 0.02);
    check.(manager.voices.isEmpty and: { manager.tails.size == 1
        and: { manager.nodeCount == oldCount } }, "release did not retain an accounted tail");
    advance.(clock + 1);
    check.(manager.tails.isEmpty and: { manager.nodeCount == 0 },
        "release tail did not finish cleanup");
    manager.applyVoice(dirtEvent, voiceEvent, clock + 0.01);
    check.(manager.voices.size == 1, "hold did not recreate a retired voice");
    advance.(clock + 0.8);
    check.(manager.voices.isEmpty and: { manager.tails.size == 1 },
        "heartbeat timeout did not release the persistent voice");
    advance.(clock + 1);
    check.(manager.nodeCount == 0 and: { manager.tails.isEmpty },
        "timeout tail did not finish cleanup");

    // Free cuts an already released tail, and release invalidates older queued holds.
    manager.applyVoice(dirtEvent, voiceEvent, clock + 0.01);
    manager.applyVoice(dirtEvent, (swVoiceId: 7, swOp: \release), clock + 0.02);
    check.(manager.tails.size == 1 and: { manager.nodeCount > 0 },
        "release did not create a tail for explicit-free coverage");
    manager.applyVoice(dirtEvent, (swVoiceId: 7, swOp: \free), clock + 0.03);
    check.(manager.tails.isEmpty and: { manager.nodeCount == 0 },
        "explicit free did not cut the already released tail");
    manager.dispatchVoice(dirtEvent, voiceEvent.copy.put(\latency, 0.5));
    manager.applyVoice(dirtEvent, (swVoiceId: 7, swOp: \release), clock + 0.04);
    advance.(clock + 0.6);
    check.(manager.voices.isEmpty and: { manager.nodeCount == 0 },
        "queued pre-release hold recreated the released voice");

    // Queued holds cannot recreate state after panic/freeAll.
    oldCount = manager.pendingCount;
    manager.dispatchVoice(dirtEvent, voiceEvent.copy.put(\latency, 0.5));
    check.(manager.pendingCount == (oldCount + 1), "delayed hold was not queued");
    manager.freeAll;
    check.(manager.pendingCount == 0 and: { manager.nodeCount == 0 },
        "panic did not synchronously clear adapter accounting");
    advance.(clock + 0.6);
    check.(manager.voices.isEmpty and: { manager.nodeCount == 0 },
        "stale queued hold recreated a voice after panic");

    // Growth reaches its explicit target and honors allocation limits.
    voiceEvent = voiceEvent.copy.putAll((swPartials: 2, swVariations: 2, swGrowSeconds: 0.3,
        swGrowPartials: 8, swGrowVariations: 1));
    manager.applyVoice(dirtEvent, voiceEvent, clock + 0.01);
    advance.(clock + 0.11);
    voice = manager.voices.values.first;
    growthKey = voice[\growthKey];
    growthPartials = voice[\state].partials;
    manager.applyVoice(dirtEvent, voiceEvent, clock + 0.01);
    check.(voice[\growing] and: { voice[\growthKey] == growthKey
        and: { voice[\state].partials == growthPartials } },
        "unchanged heartbeat restarted or interrupted active density growth");
    advance.(clock + 0.45);
    check.(voice[\state].partials == 8 and: { voice[\state].variations == 2
        and: { voice[\count] == 16 } },
        "density growth did not reach the requested partial target before variation reduction");
    manager.applyVoice(dirtEvent, voiceEvent, clock + 0.01);
    advance.(clock + 0.5);
    manager.applyVoice(dirtEvent, voiceEvent, clock + 0.01);
    advance.(clock + 0.5);
    check.(voice[\state].partials == 8 and: { voice[\state].variations == 1
        and: { voice[\count] == 8 and: { voice[\growing].not } } },
        "density growth did not perform its delayed variation reduction");
    manager.freeAll;

    // CmdPeriod invokes the installed cleanup callback without uninstalling sounds.
    manager.applyVoice(dirtEvent, voiceEvent.copy.putAll((swVoiceId: 12,
        swPartials: 3, swVariations: 1, swGrowSeconds: nil, swGrowPartials: nil,
        swGrowVariations: nil)), clock + 0.01);
    check.(manager.voices.size == 1 and: { manager.nodeCount == 6 },
        "CmdPeriod fixture did not create a persistent voice");
    CmdPeriod.run;
    check.(manager.active and: { manager.voices.isEmpty and: {
        manager.tails.isEmpty and: { manager.notes.isEmpty and: {
            manager.nodeCount == 0 and: { manager.pendingCount == 0 }
        } }
    } }, "CmdPeriod did not synchronously clear adapter-owned resources");
    check.([\swVoice, \swPanic, \swFlute, \swClarinet, \swOrgan, \swMarimba, \swBell, \swKick]
        .every { |name| library.at(name).notNil },
        "CmdPeriod uninstalled reusable Dirt registrations");

    // Scheduling delay is not silence: the watchdog starts at playback time.
    manager.dispatchVoice(dirtEvent, voiceEvent.copy.putAll((latency: 0.5,
        swPartials: 3, swGrowSeconds: nil)));
    advance.(clock + 0.2);
    check.(manager.voices.isEmpty, "delayed hold began before its playback time");
    advance.(clock + 0.31);
    check.(manager.voices.size == 1, "delayed hold failed to start at playback time");
    advance.(clock + 0.5);
    check.(manager.voices.size == 1, "latency incorrectly consumed the watchdog interval");
    manager.freeAll;
    expectError.({ manager.applyVoice(dirtEvent, (swInstrument: \swMarimba,
        swVoiceId: 1, swOp: \hold), clock + 0.01) }, "gated",
        "a self-freeing transient was accepted as a persistent recipe");
    check.(manager.voices.isEmpty and: { manager.nodeCount == 0 },
        "invalid hold allocated resources");

    previous = manager;
    manager = ~installSwarmDirt.(dirt, 4, 16, runtime);
    check.(previous.active.not and: { manager !== previous },
        "reinstallation did not dispose the previous manager");
    manager.registerStandardInstruments;
    expectError.({ manager.applyVoice(dirtEvent,
        (swInstrument: \swOrgan, swVoiceId: 1, swPartials: 5,
            swVariations: 1, swOp: \hold), clock + 0.01) }, "limit",
        "per-voice node limit was not enforced before allocation");
    check.(manager.nodeCount == 0 and: { manager.voices.isEmpty },
        "failed allocation mutated adapter ownership state");
    manager.dispose;
    check.(manager.active.not and: { manager.registrations.isEmpty },
        "dispose did not remove owned sound registrations");

    manager = ~installSwarmDirt.(dirt, 8, 10, runtime);
    manager.registerStandardInstruments;
    manager.applyVoice(dirtEvent, (swInstrument: \swOrgan, swVoiceId: 1,
        swPartials: 4, swVariations: 1, swOp: \hold), clock + 0.01);
    expectError.({ manager.applyVoice(dirtEvent, (swInstrument: \swOrgan,
        swVoiceId: 2, swPartials: 4, swVariations: 1, swOp: \hold), clock + 0.02) },
        "limit", "total adapter node limit was not enforced");
    check.(manager.nodeCount == 7 and: { manager.voices.size == 1 },
        "failed total-limit allocation mutated existing ownership state");
    manager.dispose;
    manager = ~installSwarmDirt.(dirt, 10, 32, runtime);
    manager.registerStandardInstruments;
    manager.applyVoice(dirtEvent, (swInstrument: \swOrgan, swVoiceId: 1,
        swPartials: 7, swVariations: 1), clock + 0.01);
    manager.applyVoice(dirtEvent, (swInstrument: \swOrgan, swVoiceId: 1,
        swPartials: 3, swVariations: 1), clock + 0.02);
    expectError.({ manager.applyVoice(dirtEvent, (swInstrument: \swOrgan,
        swVoiceId: 1, swPartials: 7, swVariations: 1), clock + 0.03) }, "limit",
        "per-voice budget omitted the releasing surplus nodes");
    check.(manager.nodeCount == 10, "failed regrowth changed live accounting");
    manager.freeAll;
    check.(manager.nodeCount == 0 and: { manager.tails.isEmpty }, "cleanup failed at full budget");
    manager.dispose;
    // Exercise the actual explicit installer, including relative-root resolution.
    ~dirt = dirt;
    (root +/+ "superdirt/examples/standard-instruments.scd").load;
    check.(~swDirt.definitions.size == 6, "standard installer path or registrations failed");
    ~swDirt.dispose;
    Server.default = originalServer;
    "PASS: SwarmDirt adapter contracts".postln;
    0.exit;
} { |error|
    error.reportError;
    "FAIL: SwarmDirt adapter contracts".postln;
    1.exit;
};
)
