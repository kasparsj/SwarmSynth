// Standalone phrases and natural/soft/bright comparisons.
// Evaluate the whole block. Use ~standardInstrumentCleanup.value to stop.
(
~standardInstrumentCleanup !? { |cleanup| cleanup.value };

s.waitForBoot {
    var names = SwarmInstruments.names;
    var pitches = (
        flute: [76, 79, 81],
        clarinet: [55, 58, 62],
        organ: [[48, 55, 60, 64], [50, 57, 62, 65], [43, 55, 59, 62]],
        marimba: [57, 64, 60],
        bell: [72, 79, 76]
    );
    var levels = (flute: 0.055, clarinet: 0.045, organ: 0.022,
        marimba: 0.07, bell: 0.05);

    SwarmSynthDefs.install;
    // Do not play until \swarm_partial is installed on the running server.
    s.sync;

    ~standardInstrumentVoices = IdentityDictionary.new;
    names.do { |name|
        ~standardInstrumentVoices[name] = SwarmInstruments.make(
            name, #[440], levels[name], \natural
        );
    };

    ~standardInstrumentCleanup = {
        if (~standardInstrumentPhrase.notNil
            and: { ~standardInstrumentPhrase !== thisThread }) {
            ~standardInstrumentPhrase.stop;
        };
        ~standardInstrumentPhrase = nil;
        ~standardInstrumentVoices !? { |voices|
            voices.values.do { |voice| voice.dispose };
            voices.clear;
        };
        ~standardInstrumentVoices = nil;
        "Standard instrument example stopped and disposed.".postln;
    };

    ~standardInstrumentPhrase = Routine {
        var held = { |voice, notes, beats=0.6|
            // closeGate resets playback handles, so every articulation
            // explicitly reopens the partial envelopes with gate 1.
            voice.play((freqs: notes.asArray.midicps, gate: 1));
            beats.wait;
            voice.closeGate;
            0.18.wait;
        };
        var struck = { |voice, note, beats=0.32|
            // nextTrigger forgets handles without cutting self-freeing tails.
            voice.play((midinote: note));
            beats.wait;
        };

        // Each variant gets the same short phrase for direct comparison.
        [\natural, \soft, \bright].do { |variant|
            ("SwarmInstruments variant: " ++ variant).postln;
            names.do { |name|
                var voice = ~standardInstrumentVoices[name];
                voice.setVariant(variant);
                if (SwarmInstruments.metadata(name)[\auditionGate]) {
                    pitches[name].do { |notes| held.value(voice, notes, 0.55) };
                } {
                    pitches[name].do { |note| struck.value(voice, note, 0.3) };
                    // Leave time for the final strike while earlier tails overlap.
                    (SwarmInstruments.metadata(name)[\releaseTime]
                        * TempoClock.default.tempo).wait;
                };
                0.2.wait;
            };
            0.6.wait;
        };

        ~standardInstrumentVoices.values.do { |voice| voice.dispose };
        ~standardInstrumentVoices.clear;
        ~standardInstrumentVoices = nil;
        ~standardInstrumentPhrase = nil;
        "Standard instrument comparison finished and disposed.".postln;
    }.play(TempoClock.default);
};
)

// Stop early and release all owned groups:
// ~standardInstrumentCleanup.value;
