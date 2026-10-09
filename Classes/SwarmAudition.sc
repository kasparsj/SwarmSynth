SwarmAudition {
    var <registry, <options, <facade, owner;
    *new { |registry, options| ^super.new.init(registry, options ? ()); }
    init { |aRegistry, settings|
        registry = aRegistry; options = settings.copy; owner = currentEnvironment;
        if(registry.isKindOf(SwarmInstrumentRegistry).not) { Error("SwarmAudition: registry must be a SwarmInstrumentRegistry").throw };
        if(options[\nodeLimit].notNil and: {
            options[\nodeLimit].isInteger.not or: { options[\nodeLimit] < 1 }
        }) { Error("SwarmAudition: nodeLimit must be a positive integer").throw };
        facade = (
            names: registry.names, selected: registry.names.first,
            registry: registry, options: options, owner: owner,
            nodeLimit: options[\nodeLimit] ? 2048,
            settings: IdentityDictionary.new, baselines: IdentityDictionary.new,
            variantDefinitions: IdentityDictionary.new, capturedVariants: IdentityDictionary.new,
            disposed: false, context: nil, run: nil, window: nil, status: "Ready — private auditions only",
            onStatus: nil, pendingUpdate: nil, partialCapture: nil, onPartials: nil,
    checkActive: { |self| if(self.disposed) { Error("SwarmAudition: audition has been disposed").throw };
    },
    notify: { |self, message|
        self.status = message;
        self[\onStatus] !? { |action| action.value(message) };
    },
    publishPartials: { |self, records, name, status|
        var server = Server.default, rate, rateLabel;
        if (server.serverRunning) { rate = server.sampleRate };
        if (rate.notNil and: { rate > 0 }) {
            rateLabel = "Running server: % Hz".format(rate);
        } {
            rate = server.options.sampleRate;
            if (rate.notNil and: { rate > 0 }) {
                rateLabel = "Preview assumption: configured % Hz".format(rate);
            } {
                rate = 48000;
                rateLabel = "Preview assumption: 48000 Hz (fallback)";
            };
        };
        self.partialCapture = (records: records, name: name, status: status,
            sampleRate: rate, sampleRateLabel: rateLabel,
            label: registry.metadata(name)[\label] ? name.asString,
            metadata: registry.metadata(name).copy);
        self[\onPartials] !? { |action| action.value(self.partialCapture) };
        self.partialCapture;
    },
    markPartials: { |self, status|
        if (self.partialCapture.notNil) {
            self.partialCapture = self.partialCapture.copy.put(\status, status);
            self[\onPartials] !? { |action| action.value(self.partialCapture) };
        };
    },
    previewPartials: { |self|
        var state, settings = self.settings[self.selected];
        self[\checkActive].value(self);
        if (settings.notNil and: { self.run.isNil }) {
            state = self[\prepare].value(self, self.selected, settings.freqs);
            self[\publishPartials].value(self,
                state.playbackSnapshot(20261009, true), self.selected, \preview);
        };
        self.partialCapture;
    },
    sampledPartials: { |self, run, state, createNew=true, excludeParams=nil|
        var records = state.playbackSnapshot, sampled, merged, displayed = List.new;
        sampled = records.collect { |record| record[\values].asPairs };
        run[\synth].setSampled(sampled, excludeParams: excludeParams, createNew: createNew);
        // Backend params contain the merged controls actually sent, including
        // retained phase/pan and defaults. Never reevaluate a timbre callback.
        merged = run[\synth].params;
        records.do { |record, index|
            if (merged[index].notNil) {
                var copy = record.copy;
                copy[\values] = Dictionary.newFrom(merged[index]).deepCopy;
                displayed.add(copy);
            };
        };
        self[\publishPartials].value(self, displayed.asArray, run[\name], \playing);
    },
    cloneState: { |self, state|
        SwarmMath.new(state.freqs.copy, state.partials, state.variations,
            state.args.deepCopy.asPairs, state.vol);
    },
    finite: { |self, value|
        value.isKindOf(SimpleNumber) and: { value.isNaN.not and: { value.abs != inf } };
    },
    bounded: { |self, value, low, high, integer=false|
        if (self[\finite].value(self, value).not or: { value < low or: { value > high } }
            or: { integer and: { value != value.asInteger } }) {
            Error("Expected % between % and %".format(if(integer, "whole number", "number"), low, high)).throw;
        };
        value;
    },
    modal: { |self, name| registry.metadata(name)[\modal] ? false;
    },
    gated: { |self, name| registry.metadata(name)[\auditionGate] ?? { registry.instrument(name, owner).hasGate };
    },
    variantKey: { |self, variant, preset| options[\variantKey] !? { |action| variant = action.value(variant, preset) }; variant;
    },
    definition: { |self, name|
        var settings = self.settings[name];
        var key = self[\variantKey].value(self, settings.variant, settings[\preset]);
        self.variantDefinitions[name][key];
    },
    descriptors: { |self, name|
        var source = registry.metadata(name)[\descriptors] ? #[];
        var result = if(source.isKindOf(Function)) { source.value(self, name) } { source.deepCopy };
        result.do { |descriptor|
            var baseline = self.baselines[name], settings = self.settings[name], definition, value;
            if (baseline.notNil) {
                value = baseline.args[descriptor.key];
                if (settings.notNil) {
                    definition = self[\definition].value(self, name);
                    if (self[\variantKey].value(self, settings.variant, settings[\preset])
                        != self.capturedVariants[name]) {
                        value = definition[\args][descriptor.key] ? value;
                    };
                };
                if (value.notNil) { descriptor[\default] = value };
            };
        };
        result.asArray;
    },
    capture: { |self|
        var context;
        self[\checkActive].value(self);
        owner.use {
            context = if(options[\captureContext].notNil) { options[\captureContext].value(self) } { () };
            context = context ? ();
            context[\routes] = context[\routes] ? options[\routes] ? (dry: 0);
            self.names = registry.names;
            if(self.names.isEmpty) { Error("SwarmAudition: register at least one instrument").throw };
            if(self.names.includes(self.selected).not) { self.selected = self.names.first };
            self.settings.clear; self.baselines.clear; self.variantDefinitions.clear; self.capturedVariants.clear;
            self.names.do { |name|
                var instrument = registry.instrument(name, owner), state = instrument.state;
                var selected = instrument.variant, selection;
                selection = if(options[\variantSettings].notNil) { options[\variantSettings].value(selected) } { (variant: selected) };
                self.variantDefinitions[name] = instrument.variants;
                self.capturedVariants[name] = selected;
                self.baselines[name] = self[\cloneState].value(self, state);
                self.settings[name] = (variant: selected,
                    freqs: state.freqs.copy, duration: 2, gap: 1,
                    tempo: context[\tempo] ? options[\tempo] ? 1, route: \dry, mode: \single, level: 1,
                    partials: state.partials, variations: state.variations,
                    ratioMode: \original, ratioPower: 1.5, stiffness: 0.001,
                    ampMode: \original, ampPower: 1, ampSlope: 0.1, nyquistMode: -1,
                    overrides: Dictionary.new).putAll(selection);
            };
        };
        self.context = context;
        self.partialCapture = nil;
    },
    refresh: { |self|
        self[\checkActive].value(self);
        self[\stopAudition].value(self);
        self[\capture].value(self);
        self[\notify].value(self, "Captured current project settings — stopped");
        self[\previewPartials].value(self);
    },
    select: { |self, name|
        self[\checkActive].value(self);
        if (self.names.includes(name).not) { Error("Unknown audition instrument: " ++ name).throw };
        self[\stopAudition].value(self);
        if (self.context.isNil) { self[\capture].value(self) };
        self.selected = name;
        self[\notify].value(self, "Selected " ++ name ++ " — stopped");
        self[\previewPartials].value(self);
    },
    nodeCount: { |self|
        var settings = self.settings[self.selected];
        if (settings.isNil) { 0 } { settings.freqs.size * settings.partials * settings.variations };
    },
    validate: { |self, settings, frequencies|
        self[\bounded].value(self, settings.partials, 1, self.nodeLimit, true);
        self[\bounded].value(self, settings.variations, 1, self.nodeLimit, true);
        if (frequencies.isSequenceableCollection.not or: { frequencies.isEmpty }) {
            Error("Enter one or more frequencies in Hz.").throw;
        };
        frequencies.do { |freq| self[\bounded].value(self, freq, 1, 20000) };
        if (frequencies.size * settings.partials * settings.variations > self.nodeLimit) {
            Error("This audition exceeds the %-node limit. Reduce partials, variations or chord size.".format(self.nodeLimit)).throw;
        };
    },
    update: { |self, key, value|
        var settings = self.settings[self.selected], proposed;
        self[\checkActive].value(self);
        if (settings.isNil) { Error("Refresh the audition settings first.").throw };
        proposed = settings.copy;
        switch(key,
            \variant, { if (self[\variantChoices].value(self).includes(value).not) { Error("Unknown timbre variant").throw } },
            \freqs, { },
            \partials, { self[\bounded].value(self, value, 1, self.nodeLimit, true) },
            \variations, { self[\bounded].value(self, value, 1, self.nodeLimit, true) },
            \duration, { self[\bounded].value(self, value, 0.01, 120) },
            \gap, { self[\bounded].value(self, value, 0, 120) },
            \tempo, { self[\bounded].value(self, value, 0.05, 10) },
            \level, { self[\bounded].value(self, value, 0, 2) },
            \ratioPower, { self[\bounded].value(self, value, 0.1, 4) },
            \stiffness, { self[\bounded].value(self, value, 0, 0.1) },
            \ampPower, { self[\bounded].value(self, value, 0, 4) },
            \ampSlope, { self[\bounded].value(self, value, 0, 2) },
            \nyquistMode, { self[\bounded].value(self, value, -1, 3, true) },
            \mode, { if ((if(options[\phrase].notNil) { [\single, \repeat, \phrase] } { [\single, \repeat] }).includes(value).not) { Error("Unknown playback mode").throw } },
            \route, { if (self.context.routes[value].isNil) { Error("This effect route is unavailable").throw } },
            \ratioMode, { if ([\original, \harmonic, \odd, \power, \stiffString].includes(value).not) { Error("Unknown ratio recipe").throw } },
            \ampMode, { if ([\original, \power, \exponential].includes(value).not) { Error("Unknown amplitude recipe").throw } },
            { Error("Unknown audition setting: " ++ key).throw });
        proposed[key] = value;
        self[\validate].value(self, proposed, proposed.freqs);
        if (key == \mode) { self[\stopAudition].value(self) };
        if (key == \tempo and: { self.run.notNil }) { self.run[\clock].tempo = value };
        settings[key] = if (key == \freqs) { value.copy } { value };
        self[\scheduleUpdate].value(self);
    },
    control: { |self, key, value|
        var descriptor = self[\descriptors].value(self, self.selected).detect { |item| item.key == key };
        self[\checkActive].value(self);
        if (descriptor.isNil) { Error("Inactive control: " ++ key).throw };
        self[\bounded].value(self, value, descriptor.min, descriptor.max);
        self.settings[self.selected].overrides[key] = value;
        self[\scheduleUpdate].value(self);
    },
    resetInstrument: { |self|
        var name = self.selected, baseline = self.baselines[name], settings = self.settings[name];
        self[\checkActive].value(self);
        self[\stopAudition].value(self);
        settings.putAll((freqs: baseline.freqs.copy, partials: baseline.partials,
            variations: baseline.variations, level: 1, ratioMode: \original,
            ampMode: \original, ratioPower: 1.5, stiffness: 0.001,
            ampPower: 1, ampSlope: 0.1, nyquistMode: -1, overrides: Dictionary.new));
        settings.putAll(if(options[\variantSettings].notNil) { options[\variantSettings].value(self.capturedVariants[name]) } { (variant: self.capturedVariants[name]) });
        self[\notify].value(self, "Restored captured " ++ name ++ " timbre");
        self[\previewPartials].value(self);
    },
    prepare: { |self, name, frequencies, event=nil|
        var settings = self.settings[name], state, definition, key, ratioMode, ratioPower, power, stiffness, ampMode, slope;
        self[\validate].value(self, settings, frequencies);
        state = self[\cloneState].value(self, self.baselines[name]);
        key = self[\variantKey].value(self, settings.variant, settings[\preset]);
        if (key != self.capturedVariants[name]) {
            definition = self[\definition].value(self, name);
            if (definition.isNil) { Error("Missing private timbre variant: " ++ key).throw };
            state.args = Dictionary.newFrom(definition[\args].deepCopy.asPairs);
        };
        state.freqs = frequencies.copy;
        state.partials = settings.partials;
        state.variations = settings.variations;
        state.vol = self.baselines[name].vol * settings.level;
        // Playback writes concrete Hz directly; it never asks putEvent to infer pitch.
        state.args.putAll(event ? ());
        state.args.putAll(settings.overrides);
        state.args[\out] = self.context.routes[settings.route];
        state.args[\nyquistMode] = settings.nyquistMode;
        ratioMode = settings.ratioMode; ratioPower = settings.ratioPower; stiffness = settings.stiffness;
        if (ratioMode != \original) {
            state.args[\ratio] = switch(ratioMode,
                \harmonic, { { |e| e.p1 } },
                \odd, { { |e| (e.p * 2) + 1 } },
                \power, { { |e| e.p1 ** ratioPower } },
                \stiffString, { { |e| e.p1 * ((1 + (stiffness * e.p1.squared)) / (1 + stiffness)).sqrt } });
            if(registry.metadata(name)[\spectrumAdaptation].notNil) {
                registry.metadata(name)[\spectrumAdaptation].value(state);
            } {
                state.args[\freq] = { |e| SwarmMath.freqRatio(e) };
            };
        };
        ampMode = settings.ampMode; power = settings.ampPower; slope = settings.ampSlope;
        // Separate captured power variables: ratio and amplitude closures must not alias.
        if (ampMode == \power) {
            state.args[\amp] = { |e| SwarmMath.ampPower(e, power, \index) * e.vol };
        };
        if (ampMode == \exponential) {
            state.args[\amp] = { |e| SwarmMath.ampExponential(e, slope, \index) * e.vol };
        };
        state;
    },
    ready: { |self|
        if(Server.default.serverRunning.not) { Error("Boot the audio server before Play.").throw };
        options[\ready] !? { |action| owner.use { action.value(self) } };
        true;
    },
    makeSynth: { |self, name|
        var instrument = registry.instrument(name, owner);
        var params = registry.metadata(name)[\auditionParams] ?? { instrument.defaultParams };
        SwarmSynth.new(instrument.synthDef, params.deepCopy, self[\gated].value(self, name));
    },
    emit: { |self, run, frequencies, seconds, event=nil|
        var params = (event ? ()).copy, state, preservePhasePan;
        if (run[\active]) {
            self[\bounded].value(self, seconds, 0.001, 240);
            params[\duration] = seconds; params[\dur] = seconds;
            state = self[\prepare].value(self, run[\name], frequencies, params);
            preservePhasePan = run[\sounding] and: {
                registry.metadata(run[\name])[\preservePhasePan] ? false
            };
            // Gated phrase notes retain continuity. Retriggers and density changes
            // clear all nodes, including tails, before allocating a fresh swarm.
            if (self[\gated].value(self, run[\name]).not
                or: { run[\sounding].not }
                or: { run[\state].isNil }
                or: { run[\state].size != state.size }) {
                run[\synth].release;
            };
            run[\state] = state; run[\frequencies] = frequencies.copy; run[\event] = params.copy;
            self[\sampledPartials].value(self, run, state, true,
                if(preservePhasePan, [\phase, \pan], nil));
        };
    },
    scheduleUpdate: { |self|
        if (self.pendingUpdate.isNil) {
            self.pendingUpdate = Routine {
                0.05.wait;
                self.pendingUpdate = nil;
                try {
                    var run = self.run;
                    if (run.notNil and: { run[\active] }) {
                        if (run[\sounding] and: { registry.instrument(run[\name], owner).liveSwitch == \sustained }) {
                            var frequencies = if(self.settings[run[\name]].mode == \phrase) {
                                run[\frequencies]
                            } { self.settings[run[\name]].freqs };
                            var state = self[\prepare].value(self, run[\name], frequencies, run[\event]);
                            if (state.partials == run[\state].partials
                                and: { state.variations == run[\state].variations }
                                and: { state.freqs.size == run[\state].freqs.size }) {
                                self[\sampledPartials].value(self, run, state, false, [\phase, \pan]);
                                run[\state] = state;
                            } {
                                self[\markPartials].value(self, \pending);
                            };
                        } {
                            self[\markPartials].value(self, \pending);
                        };
                    } {
                        self[\previewPartials].value(self);
                    };
                } { |error|
                    self[\stopAudition].value(self);
                    self[\notify].value(self, error.errorString);
                };
            }.play(AppClock);
        };
    },
    note: { |self, run, frequencies, beats, close=true, event=nil|
        self[\emit].value(self, run, frequencies, beats / run[\clock].tempo, event);
        run[\sounding] = true;
        beats.wait;
        if (run[\active] and: { close and: { self[\gated].value(self, run[\name]) } }) {
            run[\synth].closeGate;
            run[\sounding] = false;
        };
    },
    phrase: { |self, run| owner.use { options[\phrase].value(self, run, self.context) };
    },
    start: { |self|
        var run, settings;
        self[\checkActive].value(self);
        self[\stopAudition].value(self);
        try {
            self[\ready].value(self);
            if (self.context.isNil) { self[\capture].value(self) };
            settings = self.settings[self.selected];
            self[\validate].value(self, settings, settings.freqs);
            run = (name: self.selected, active: true, sounding: false,
                clock: TempoClock(settings.tempo), children: IdentitySet.new,
                synth: nil, routine: nil, state: nil, noteIndex: 0);
            self.run = run;
            run[\synth] = self[\makeSynth].value(self, run[\name]);
            run[\routine] = Routine {
                try {
                    if (settings.mode == \phrase) {
                        self[\phrase].value(self, run);
                    } {
                        while { run[\active] } {
                            self[\note].value(self, run, settings.freqs, settings.duration * run[\clock].tempo);
                            if (settings.mode == \single) {
                                // Allow the private release envelope before removing the group.
                                var metadata = registry.metadata(run[\name]);
                                var release = settings.overrides[metadata[\releaseKey] ? \release] ? metadata[\releaseTime] ? 0.01;
                                (release * run[\clock].tempo + 0.02).wait;
                                self[\stopAudition].value(self);
                            };
                            if (run[\active]) { (settings.gap.max(0.01) * run[\clock].tempo).wait };
                        };
                    };
                } { |error|
                    self[\stopAudition].value(self);
                    self[\notify].value(self, error.errorString);
                };
            };
            self[\notify].value(self, "Playing " ++ run[\name] ++ " / " ++ settings.mode
                ++ " — " ++ if(self[\gated].value(self, run[\name]), "timbre updates live; density on next attack", "changes on next attack"));
            run[\routine].play(run[\clock]);
        } { |error|
            self[\stopAudition].value(self);
            self[\notify].value(self, error.errorString);
        };
        run;
    },
    stopAudition: { |self|
        var run = self.run;
        self.pendingUpdate !? { |routine| routine.stop; self.pendingUpdate = nil };
        if (run.notNil) {
            run[\active] = false;
            (run[\children].asArray ++ [run[\routine]]).do { |routine|
                if (routine.notNil and: { routine !== thisThread }) { routine.stop };
            };
            run[\children].clear;
            run[\synth] !? { |synth|
                if(synth.respondsTo(\dispose)) { synth.dispose } {
                    synth.rampRoutine !? { |routine| routine.stop; synth.rampRoutine = nil };
                    synth.release;
                    if(synth.respondsTo(\group)) { synth.group.free };
                };
            };
            run[\clock].stop;
            self.run = nil;
        };
        self[\markPartials].value(self, \stopped);
        self[\notify].value(self, "Stopped — shared effect tails may decay");
    },
    dispose: { |self|
        self.disposed = true;
        self[\stopAudition].value(self);
        CmdPeriod.remove(self[\cmdPeriod]);
        self[\onStatus] = nil;
        self[\onPartials] = nil;
        self.window !? { |window| { window.close }.defer };
    },
    variantChoices: { |self| if(options[\variantChoices].notNil) { options[\variantChoices].value(self) } { self.variantDefinitions[self.selected].keys.asArray.sort };
    },
    variantLabels: { |self| if(options[\variantLabels].notNil) {
            if(options[\variantLabels].isKindOf(Function)) { options[\variantLabels].value(self) } { options[\variantLabels] }
        } { self[\variantChoices].value(self).collect(_.asString) };
    },
    open: { |self| self[\checkActive].value(self); SwarmAuditionGUI.new(self, options).open; self;
    }
        );
        facade[\core] = this;
        facade[\cmdPeriod] = { owner.use { facade[\stopAudition].value(facade) } };
        CmdPeriod.add(facade[\cmdPeriod]);
        ^this;
    }
    at { |key| ^facade[key]; }
    settings { ^facade[\settings]; }
    status { ^facade[\status]; }
    partialCapture { ^facade[\partialCapture]; }
    onStatus_ { |action| facade[\onStatus] = action; }
    onPartials_ { |action| facade[\onPartials] = action; }
    capture { ^facade[\capture].value(facade); }
    refresh { ^facade[\refresh].value(facade); }
    select { |name| ^facade[\select].value(facade, name); }
    update { |key, value| ^facade[\update].value(facade, key, value); }
    control { |key, value| ^facade[\control].value(facade, key, value); }
    resetInstrument { ^facade[\resetInstrument].value(facade); }
    start { ^facade[\start].value(facade); }
    stopAudition { ^facade[\stopAudition].value(facade); }
    dispose { ^facade[\dispose].value(facade); }
    open { ^facade[\open].value(facade); }
    previewPartials { ^facade[\previewPartials].value(facade); }
}
