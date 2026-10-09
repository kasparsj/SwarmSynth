// Register collection instruments with the private SwarmAudition GUI.
// The generic GUI isolates retriggers by clearing previous tails. Use the
// listening example to hear overlapping strikes through SwarmInstrument.play.
// All states, borrowed playback, registry, and audition objects are local to
// this example. Evaluate the whole block, then call the cleanup function.
(
~standardInstrumentAuditionCleanup !? { |cleanup| cleanup.value };

s.waitForBoot {
    var resources, registry;

    SwarmSynthDefs.install;
    s.sync;

    resources = (
        instruments: IdentityDictionary.new,
        playbacks: IdentityDictionary.new,
        registry: nil,
        audition: nil
    );
    registry = SwarmInstrumentRegistry.new;
    resources[\registry] = registry;
    ~standardInstrumentAuditionResources = resources;

    SwarmInstruments.names.do { |name|
        var instrument = SwarmInstruments.make(name);
        var playback = SwarmSynth.new(
            instrument.synthDef,
            instrument.defaultParams.deepCopy,
            instrument.hasGate
        );

        resources[\instruments][name] = instrument;
        resources[\playbacks][name] = playback;

        registry.register(name, { |environment|
            var local = environment[\standardInstrumentAuditionResources];
            (
                // The registry wrapper borrows this playback. The example's
                // cleanup function remains its explicit owner.
                synth: local[\playbacks][name],
                state: local[\instruments][name].state
            )
        }, (
            synthDef: instrument.synthDef,
            variant: instrument.variant,
            defaultParams: instrument.defaultParams.deepCopy,
            hasGate: instrument.hasGate,
            liveSwitch: instrument.liveSwitch
        ), instrument.variants, SwarmInstruments.metadata(name));
    };

    resources[\audition] = SwarmAudition.new(registry, (
        title: "SwarmSynth Standard Instruments",
        routes: (dry: 0),
        variantChoices: { #[natural, soft, bright] }
    ));

    ~standardInstrumentAuditionCleanup = {
        var local = ~standardInstrumentAuditionResources;
        if (local.notNil) {
            local[\audition] !? { |audition| audition.dispose };
            // Registry disposal detaches wrappers but does not dispose the
            // playback objects borrowed from this example.
            local[\registry] !? { |ownedRegistry| ownedRegistry.dispose };
            local[\playbacks].values.do { |playback| playback.dispose };
            local[\playbacks].clear;
            local[\instruments].values.do { |instrument| instrument.dispose };
            local[\instruments].clear;
        };
        ~standardInstrumentAuditionResources = nil;
        "Standard instrument audition disposed.".postln;
    };

    resources[\audition].open;
};
)

// Close the GUI and dispose private audition playback, borrowed registry
// playback, wrappers, states, and groups:
// ~standardInstrumentAuditionCleanup.value;
