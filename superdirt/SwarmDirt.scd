/* Optional SuperDirt companion. Loading defines only the installer.
   ~swDirt = ~installSwarmDirt.(~dirt);
   No SuperDirt class reference is required in the core SwarmSynth library.
   runtime is an optional test clock: (now: Function, schedule: Function).
*/
(
~installSwarmDirt = { |dirt, maxPerVoice=2048, maxTotal=8192, runtime=nil|
    var manager, managers, now, schedule, callback, midiPitch;
    // SuperDirt's parent midinote expression does not evaluate a note Function.
    // Resolve the alias here, before calcTimeSpan caches freq. Explicit numeric
    // note wins over n; explicit midinote/freq still override this proto default.
    midiPitch = {
        var note = if (currentEnvironment.keys.includes(\note)) { ~note.value } { ~n.value };
        if (note.isNumber.not) { note = ~n.value };
        if (note.isNumber.not) { note = 0 };
        note + ((~octave.value ? 5) * 12);
    };
    if (dirt.numChannels != 2) { Error("SwarmDirt requires stereo SuperDirt orbits").throw };
    [maxPerVoice, maxTotal].do { |limit| SwarmDensityAutomation.prPositiveCount(limit, \nodeLimit) };
    managers = Library.at(\swarmDirtManagers) ?? { IdentityDictionary.new };
    Library.put(\swarmDirtManagers, managers);
    managers[dirt] !? { |previous| previous.dispose };
    now = (runtime !? { runtime[\now] }) ?? { { Main.elapsedTime } };
    schedule = (runtime !? { runtime[\schedule] }) ?? { { |delay, action| SystemClock.sched(delay.max(0), { action.value; nil }) } };
    manager = (
        dirt: dirt, active: true, generation: 0, barrier: (-inf),
        definitions: IdentityDictionary.new, registrations: IdentityDictionary.new,
        voices: Dictionary.new, tails: IdentitySet.new, notes: IdentitySet.new,
        watchers: IdentityDictionary.new, latest: Dictionary.new, epochs: Dictionary.new, maxPerVoice: maxPerVoice, maxTotal: maxTotal,
        // A held voice owns two groups and one router in addition to partials.
        nodeCount: 0, pendingCount: 0,
        now: { |self| now.value },
        later: { |self, delay, action|
            var generation = self.generation;
            self.pendingCount = self.pendingCount + 1;
            schedule.(delay.max(0), {
                if (self.active and: { self.generation == generation }) {
                    self.pendingCount = (self.pendingCount - 1).max(0);
                    action.value;
                };
            });
        },
        ready: { |self| if (self.active.not) { Error("SwarmDirt adapter is disposed").throw } },
        number: { |self, value, name, minimum=0|
            if (SwarmMath.prFiniteNumber(value).not or: { value < minimum }) {
                Error("SwarmDirt: invalid %".format(name)).throw;
            }; value;
        },
        reserve: { |self, count|
            if (count > self.maxPerVoice or: { (self.nodeCount + count) > self.maxTotal }) {
                Error("SwarmDirt node limit exceeded").throw;
            };
            self.nodeCount = self.nodeCount + count;
        },
        addSound: { |self, name, event|
            var library = self.dirt.soundLibrary;
            if (library.at(name).notNil and: { self.registrations[name].isNil }) {
                Error("SwarmDirt sound name already registered: %".format(name)).throw;
            };
            library.addSynth(name, event);
            self.registrations[name] = event;
        },
        registerInstrument: { |self, name, instrument, releaseTime=0.2|
            var copied, state, event;
            self.ready; name = name.asSymbol;
            self.number(releaseTime, \releaseTime);
            state = SwarmMath.new(instrument.state.freqs.copy, instrument.state.partials,
                instrument.state.variations, instrument.state.args.deepCopy, instrument.state.vol);
            copied = SwarmInstrument.new(instrument.synthDef, state, instrument.variants,
                instrument.variant, instrument.defaultParams, instrument.hasGate, instrument.liveSwitch);
            event = (midinote: midiPitch, playInside: { |dirtEvent|
                self.playNote(dirtEvent, currentEnvironment.copy, name);
            });
            self.addSound(name, event);
            self.definitions[name] = (instrument: copied, releaseTime: releaseTime);
        },
        removeInstrument: { |self, name|
            var registration, library = self.dirt.soundLibrary;
            name = name.asSymbol;
            self.notes.copy.do { |token| if(token[\name] == name) { self.retireNote(token) } };
            self.voices.values.copy.do { |voice| if (voice[\name] == name) { self.retire(voice, true) } };
            registration = self.registrations.removeAt(name);
            if (registration.notNil and: { library.synthEvents[name].notNil }
                and: { library.synthEvents[name].includes(registration) }) { library.freeSynths(name) };
            self.definitions.removeAt(name);
        },
        registerStandardInstruments: { |self|
            SwarmSynthDefs.partial(\swarm_partial).add;
            SwarmInstruments.names.do { |name|
                var sound = ("sw" ++ (name.asString[0].toUpper.asString ++ name.asString.drop(1))).asSymbol;
                var instrument = SwarmInstruments.make(name);
                self.registerInstrument(sound, instrument, SwarmInstruments.metadata(name)[\releaseTime]);
            }; self;
        },
        prepare: { |self, name, event, previous=nil|
            var definition = self.definitions[name.asSymbol], instrument, state, variant, pitch;
            var mapping = (swPartials: \partials, swVariations: \variations,
                swDetune: \detune, swMod: \mod, swModFreq: \modf,
                swPhase: \phase, swPhaseFreq: \phasef, swPanFreq: \panf,
                swNyquist: \nyquistMode, swVowel: \vowel, swVibratoSpeed: \vibratoSpeed,
                swVibratoDepth: \vibratoDepth, swLPF: \lpf, swHPF: \hpf,
                swSweepRatio: \f2mul, swComb1: \comb1, swComb2: \comb2,
                swPulse: \pulse, swPulseFreq: \pulsef, swSaw: \saw, swSawFreq: \sawf);
            if (definition.isNil) { Error("Unknown SwarmDirt instrument: %".format(name)).throw };
            instrument = definition.instrument;
            variant = (event[\swVariant] ?? { previous !? { previous.variant } }) ?? { instrument.variant };
            variant = variant.asSymbol;
            state = if (previous.notNil and: { previous.variant == variant }) {
                SwarmMath.new(previous.state.freqs.copy, previous.state.partials,
                    previous.state.variations, previous.state.args.deepCopy, previous.state.vol)
            } { instrument.cloneStateForVariant(variant) };
            instrument.defaultParams !? { |params| state.args.putAll(params.asDict) };
            mapping.keysValuesDo { |control, key|
                event[control] !? { |value|
                    if (key == \nyquistMode) { value = SwarmMath.prPolicyMode(value.asSymbol) };
                    self.number(value, control, if ([\phase].includes(key), -inf, 0));
                    if ([\partials, \variations].includes(key)) {
                        SwarmDensityAutomation.prPositiveCount(value, key);
                        state.perform(key.asSetter, value.asInteger);
                    } { state.args[key] = value };
                };
            };
            if (event[\n].isNumber or: { event[\note].isNumber }
                or: { event[\midinote].isNumber } or: { event[\freq].isNumber }) {
                pitch = event.use { ~freq.value };
                if (pitch.isNumber.not) {
                    pitch = event.use { ~midinote.value };
                    if (pitch.isNumber.not) { pitch = (event[\n] ? 0) + ((event[\octave] ? 5) * 12) };
                    pitch = pitch.midicps;
                };
                state.putEvent((freq: pitch));
            };
            if (state.size > self.maxPerVoice) { Error("SwarmDirt per-voice node limit exceeded").throw };
            (state: state, variant: variant, definition: definition, name: name.asSymbol);
        },
        sample: { |self, prepared, event, out, duration=nil|
            var state = prepared[\state], seed = event[\swSeed], sampled;
            if (seed.notNil and: { seed.isInteger.not }) { Error("swSeed must be an integer").throw };
            state.args[\out] = out;
            if (duration.notNil) { state.args[\duration] = duration; state.args[\dur] = duration };
            sampled = state.snapshot(seed: seed).collect { |record| record[\values].asPairs };
            sampled.do { |pairs|
                pairs.asDict.values.do { |value|
                    if (SwarmMath.prFiniteNumber(value).not) { Error("SwarmDirt generated nonnumeric/nonfinite control").throw };
                };
            }; sampled;
        },
        watchServer: { |self, server|
            if(self.watchers[server].isNil) {
                self.watchers[server] = OSCFunc({ |message|
                    var id = message[1];
                    self.notes.copy.do { |token|
                        if(token[\server] === server and: { token[\ids].includes(id) }) {
                            token[\ids] = token[\ids].reject { |node| node == id };
                            token[\count] = token[\count] - 1;
                            self.nodeCount = (self.nodeCount - 1).max(0);
                            if(token[\count] == 0) { self.notes.remove(token) };
                        };
                    };
                }, '/n_end', server.addr);
            };
        },
        playNote: { |self, dirtEvent, event, name|
            var prepared, sampled, token, server = dirtEvent.orbit.server;
            var hold = self.number(event[\sustain] ? 1, \sustain);
            var latency = event[\latency] ? 0, tail, ids, duration;
            self.ready;
            prepared = self.prepare(name, event);
            tail = prepared[\definition].releaseTime;
            duration = hold + tail;
            sampled = self.sample(prepared, event, event[\out].asControlInput, hold);
            self.reserve(sampled.size);
            ids = sampled.collect { server.nextNodeID };
            token = (name: name, count: sampled.size, ids: ids, server: server, due: self.now + latency.max(0));
            self.notes.add(token); self.watchServer(server);
            // playInside is already inside DirtEvent's timestamped makeBundle.
            sampled.do { |pairs, index|
                server.sendMsg(\s_new, prepared[\definition].instrument.synthDef,
                    ids[index], 1, event[\synthGroup], *pairs);
            };
            // Do not forward Dirt sustain seconds into the per-partial sustain level.
            if (prepared[\definition].instrument.hasGate) {
                self.later(latency.max(0) + hold, {
                    if(self.notes.includes(token)) {
                        server.makeBundle(0, { token[\ids].do { |id| server.sendMsg(\n_set, id, \gate, 0) } });
                    };
                });
            };
            currentEnvironment[\sustain] = duration;
            self.later(latency.max(0) + duration + (event[\fadeTime] ? 0) + 0.01, {
                if (self.notes.includes(token)) { self.notes.remove(token); self.nodeCount = (self.nodeCount - token[\count]).max(0) };
            });
        },
        freeTails: { |self, key|
            self.tails.copy.do { |token|
                if (token[\key] == key) {
                    self.tails.remove(token);
                    token[\voice] !? { |released|
                        released[\playback].dispose; released[\router].free;
                        released[\group].free; released[\bus].free;
                    };
                    self.nodeCount = (self.nodeCount - token[\count]).max(0);
                };
            };
        },
        retire: { |self, voice, immediate=false|
            var tail = voice[\definition].releaseTime, token;
            self.epochs[voice[\key]] = (self.epochs[voice[\key]] ? 0) + 1;
            voice[\watch] = voice[\watch] + 1;
            voice[\growing] = false;
            self.voices.removeAt(voice[\key]);
            if (immediate) {
                self.freeTails(voice[\key]);
                voice[\playback].dispose; voice[\router].free; voice[\group].free; voice[\bus].free;
                self.nodeCount = (self.nodeCount - voice[\count] - 3).max(0);
            } {
                voice[\playback].closeGate;
                token = (voice: voice, key: voice[\key], count: voice[\count] + 3);
                self.tails.add(token);
                self.later(tail + 0.05, {
                    if (self.tails.includes(token)) { self.tails.remove(token);
                        voice[\playback].dispose; voice[\router].free; voice[\group].free; voice[\bus].free;
                        self.nodeCount = (self.nodeCount - token[\count]).max(0);
                    };
                });
            };
        },
        applyVoice: { |self, dirtEvent, event, due|
            var orbit = dirtEvent.orbit, id, key, action, voice, name, prepared, sampled;
            var ramp, count, extra, oldCount, token, timeout, watch, gain, controls, growthKey, signature, changed, retained;
            self.ready;
            id = event[\swVoiceId] ? 1; SwarmMath.prCount(id, \swVoiceId);
            key = [orbit.orbitIndex, id].asCompileString;
            if (due <= self.barrier or: { due < (self.latest[key] ? -inf) }) { nil } {
                self.latest[key] = due;
                action = (event[\swOp] ? "hold").asSymbol;
                voice = self.voices[key];
                if ([\release, \free].includes(action)) {
                    if (voice.notNil) { self.retire(voice, action == \free) } {
                        self.epochs[key] = (self.epochs[key] ? 0) + 1;
                    };
                    if (action == \free) { self.freeTails(key) };
                } {
                    if (action != \hold) { Error("Unknown SwarmDirt voice operation").throw };
                    name = (event[\swInstrument] ?? { voice !? { voice[\name] } });
                    if (name.isNil) { Error("swHold requires swInstrument").throw };
                    name = name.asSymbol;
                    ramp = self.number(event[\swRampSeconds] ? 0, \swRampSeconds);
                    controls = event.copy;
                    growthKey = if(event[\swGrowSeconds].notNil) {
                        [event[\swGrowSeconds], event[\swGrowPartials] ? 50, event[\swGrowVariations] ? 1]
                    } { nil };
                    if (voice.notNil) {
                        if (growthKey.notNil and: { voice[\growthKey] == growthKey }) {
                            controls.removeAt(\swPartials); controls.removeAt(\swVariations);
                        } {
                            voice[\growing] = false; voice[\growthKey] = nil;
                        };
                    };
                    signature = controls.select { |value, key|
                        key.asString.beginsWith("sw") or: { [\n, \note, \midinote, \octave, \freq].includes(key) }
                    }.asCompileString;
                    changed = voice.isNil or: { voice[\signature] != signature };
                    prepared = self.prepare(name, controls, if (voice.notNil and: { voice[\name] == name }, voice, nil));
                    growthKey !? { |request|
                        self.number(request[0], \swGrowSeconds, 0.001);
                        SwarmDensityAutomation.prPositiveCount(request[1], \swGrowPartials);
                        SwarmDensityAutomation.prPositiveCount(request[2], \swGrowVariations);
                        if(request[1] * prepared[\state].variations.max(request[2]) + 3 > self.maxPerVoice) {
                            Error("SwarmDirt growth exceeds node limit").throw;
                        };
                    };
                    if(prepared[\definition].instrument.hasGate.not) {
                        Error("swHold requires a gated instrument recipe").throw;
                    };
                    sampled = self.sample(prepared, event, 0);
                    gain = (event[\amp] ? 0.4) * (event[\gain] ? 1);
                    self.number(gain, \gain);
                    count = prepared[\state].size;
                    oldCount = voice !? { voice[\count] } ? 0;
                    extra = (count - oldCount).max(0);
                    retained = if (voice.isNil) { 0 } {
                        self.tails.select { |entry| entry[\owner] === voice }.collect { |entry| entry[\count] }.sum
                    };
                    if ((count.max(oldCount) + retained + 3) > self.maxPerVoice) {
                        Error("SwarmDirt per-voice node limit includes releasing nodes, groups and router").throw;
                    };
                    if (voice.notNil and: { voice[\name] != name }) {
                        self.reserve(count + 3); self.retire(voice, false); voice = nil; oldCount = 0;
                    } { self.reserve(extra + if(voice.isNil, 3, 0)) };
                    if (voice.isNil) {
                        var orbitGroup = if(orbit.isKindOf(Event)) { orbit[\group] } { orbit.group };
                        var target = if(orbitGroup.isKindOf(Node)) { orbitGroup } { Group.basicNew(orbit.server, orbitGroup) };
                        var group = Group.head(target), bus = Bus.audio(orbit.server, 2), playback;
                        playback = SwarmSynth.new(prepared[\definition].instrument.synthDef,
                            prepared[\definition].instrument.defaultParams, true, group);
                        voice = (key: key, name: name, state: prepared[\state], variant: prepared[\variant],
                            definition: prepared[\definition], playback: playback, count: count,
                            group: group, bus: bus, router: nil, watch: 0, growing: false);
                        voice[\router] = Synth.tail(group, \swDirtRouter,
                            [\in, bus.index, \out, orbit.dryBus.index, \amp, 1]);
                        self.voices[key] = voice;
                    };
                    voice[\state] = prepared[\state]; voice[\variant] = prepared[\variant];
                    voice[\definition] = prepared[\definition];
                    sampled = sampled.collect { |pairs| pairs.asDict.put(\out, voice[\bus].index).asPairs };
                    voice[\state].args[\out] = voice[\bus].index;
                    voice[\router].set(\amp, gain, \pan, event[\pan] ? 0);
                    orbit.globalEffects.do { |effect| effect.set(event) };
                    if (changed) {
                        if (ramp > 0 and: { voice[\playback].isPlaying }) {
                            voice[\playback].rampToSampled(sampled, ramp, \lin,
                                if (event[\swPhase].notNil, [\pan], [\phase, \pan]));
                        } {
                            voice[\playback].setSampled(sampled,
                                excludeParams: if (event[\swPhase].notNil, [\pan], [\phase, \pan]));
                        };
                    };
                    voice[\signature] = signature;
                    voice[\count] = count;
                    if (oldCount > count) {
                        token = (key: voice[\key], owner: voice, count: oldCount - count);
                        self.tails.add(token);
                        self.later(ramp.max(voice[\definition].releaseTime) + 0.05, {
                            if (self.tails.includes(token)) { self.tails.remove(token); self.nodeCount = (self.nodeCount - token[\count]).max(0) };
                        });
                    };
                    voice[\watch] = voice[\watch] + 1; watch = voice[\watch];
                    timeout = 0.75.max((2 * (event[\delta] ? 0.25)) + (event[\latency] ? 0).max(0) + 0.1);
                    self.later(timeout, {
                        if (self.voices[key] === voice and: { voice[\watch] == watch }) { self.retire(voice, false) };
                    });
                    event[\swGrowSeconds] !? { |seconds|
                        if (voice[\growthKey] != growthKey) {
                            voice[\growthKey] = growthKey; self[\grow].value(self, voice, event, seconds);
                        };
                    };
                };
            };
        },
        grow: { |self, voice, event, seconds|
            var target = event[\swGrowPartials] ? 50;
            var variations = event[\swGrowVariations] ? 1;
            var start = self.now, from = voice[\state].partials, step, applyDensity, finish;
            var request = voice[\growthKey];
            self.number(seconds, \swGrowSeconds, 0.001);
            SwarmDensityAutomation.prPositiveCount(target, \swGrowPartials);
            SwarmDensityAutomation.prPositiveCount(variations, \swGrowVariations);
            if ((target * voice[\state].variations.max(variations) + 3) > self.maxPerVoice) {
                Error("SwarmDirt growth exceeds node limit").throw;
            };
            voice[\growing] = true;
            applyDensity = { |partials, variationCount|
                var old = voice[\count], state, prepared, sampled, count, retained;
                state = SwarmMath.new(voice[\state].freqs.copy, partials, variationCount,
                    voice[\state].args.deepCopy, voice[\state].vol);
                count = state.size;
                if(count != old) {
                    retained = self.tails.select { |entry| entry[\owner] === voice }
                        .collect { |entry| entry[\count] }.sum;
                    if(count.max(old) + retained + 3 > self.maxPerVoice) {
                        Error("SwarmDirt growth exceeds live per-voice node limit").throw;
                    };
                    prepared = (state: state, definition: voice[\definition]);
                    sampled = self.sample(prepared, event, voice[\bus].index);
                    self.reserve((count - old).max(0));
                    voice[\playback].rampToSampled(sampled, 0.3, \lin, [\phase, \pan]);
                    voice[\state] = state; voice[\count] = count;
                    if(old > count) {
                        var token = (key: voice[\key], owner: voice, count: old - count);
                        self.tails.add(token); self.later(0.35, {
                            if(self.tails.includes(token)) {
                                self.tails.remove(token); self.nodeCount = (self.nodeCount - token[\count]).max(0);
                            };
                        });
                    };
                };
            };
            finish = {
                if(self.voices[voice[\key]] === voice and: { voice[\growing] }
                    and: { voice[\growthKey] == request }) {
                    applyDensity.(target, variations);
                    voice[\growing] = false;
                };
            };
            step = {
                if(self.voices[voice[\key]] === voice and: { voice[\growing] }
                    and: { voice[\growthKey] == request }) {
                    var progress = ((self.now - start) / seconds).clip(0, 1);
                    // A failed budget check leaves the last valid density intact.
                    try {
                        applyDensity.(if(progress >= 1, target, progress.linexp(0, 1, from, target).floor), voice[\state].variations);
                        if(progress >= 1) { self.later(1, finish) } { self.later(0.1, step) };
                    } { |error| voice[\growing] = false; error.reportError };
                };
            };
            self.later(0, step);
        },
        dispatchVoice: { |self, dirtEvent, event|
            var due = self.now + (event[\latency] ? 0), generation = self.generation;
            var key = [dirtEvent.orbit.orbitIndex, event[\swVoiceId] ? 1].asCompileString;
            var epoch = self.epochs[key] ? 0;
            self.ready;
            self.later((due - self.now).max(0), {
                if (self.active and: { self.generation == generation } and: { (self.epochs[key] ? 0) == epoch }) {
                    dirtEvent.orbit.server.makeBundle(nil, { self.applyVoice(dirtEvent, event, due) });
                };
            }); true;
        },
        retireNote: { |self, token|
            var messages = token[\ids].collect { |id| [\n_free, id] };
            if(token[\due] > self.now) {
                // Dirt already submitted this future note bundle. Retire its
                // IDs immediately after that bundle, even after disposal.
                token[\server].sendBundle(token[\due] - self.now + 0.001, *messages);
            } { messages.do { |message| token[\server].sendMsg(*message) } };
            self.notes.remove(token);
            self.nodeCount = (self.nodeCount - token[\count]).max(0);
        },
        freeAll: { |self|
            self.generation = self.generation + 1; self.barrier = self.now;
            self.pendingCount = 0;
            self.watchers.values.do(_.free); self.watchers.clear;
            self.voices.values.copy.do { |voice| self.retire(voice, true) };
            self.tails.copy.do { |token|
                token[\voice] !? { |voice| voice[\playback].dispose; voice[\router].free; voice[\group].free; voice[\bus].free };
            };
            self.notes.copy.do { |token| self.retireNote(token) };
            self.tails.clear; self.notes.clear; self.latest.clear; self.nodeCount = 0;
        },
        dispose: { |self|
            if (self.active) {
                self.freeAll;
                self.registrations.keys.copy.do { |name| self.removeInstrument(name) };
                CmdPeriod.remove(self[\cmdPeriod]);
                self.active = false;
                if (managers[self.dirt] === self) { managers.removeAt(self.dirt) };
            };
        }
    );
    SynthDef(\swDirtRouter, { |in=0, out=0, amp=1, pan=0|
        var sig = In.ar(in, 2);
        Out.ar(out, Balance2.ar(sig[0], sig[1], Lag.kr(pan, 0.02), Lag.kr(amp, 0.02)));
    }).add;
    manager.addSound(\swVoice, (midinote: midiPitch, play: { |event| manager.dispatchVoice(event, currentEnvironment.copy) }));
    manager.addSound(\swPanic, (play: { manager.freeAll; true }));
    callback = { manager.freeAll };
    manager[\cmdPeriod] = callback; CmdPeriod.add(callback);
    managers[dirt] = manager;
    manager;
};
)
