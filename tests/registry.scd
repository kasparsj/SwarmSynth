(
var check, registry, replacementRegistry, changedRegistry, fallbackRegistry;
var variants, changedVariants, fallbackVariants, spec, first, second, rebuilt, raw, envA, envB;
var stateA, stateB, synthA, synthB, originalArgs, expectedRandom, actualRandom, error;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
variants = (
	original: (args: (
		freq: { |e| e.freq * e.p1 }, amp: { |e| e.vol / e.p1 }, phase: 0, pan: 0
	), partials: 3, variations: 1),
	revised: (args: (
		ratio: { |e| e.p1 }, freq: { |e| SwarmMath.freqRatio(e) },
		amp: { |e| e.vol / e.p1.squared }, phase: 0, pan: 0
	), partials: 3, variations: 1)
);
spec = (synthDef: \registryTest, hasGate: true, liveSwitch: \sustained);
registry = SwarmInstrumentRegistry.new;
registry.register(\alpha, { |environment|
	(synth: environment[\alphaSynth], state: environment[\alphaState])
}, spec, variants, (label: "Alpha"));
registry.register(\raw, { |environment|
	(synth: environment[\rawSynth], state: environment[\rawState])
}, spec, variants, ());

check.(registry.names == [\alpha, \raw], "registration order was not preserved");
check.(registry.instruments(Environment.new).isEmpty,
	"registration unexpectedly created a wrapper");
check.(registry.spec(\alpha) === spec, "spec lookup changed identity");
registry.metadata(\alpha)[\role] = \lead;
check.(registry.metadata(\alpha)[\role] == \lead, "metadata was not mutable");

envA = Environment.new;
envB = Environment.new;
stateA = SwarmMath.new([110], 3, 1, variants[\original][\args].deepCopy, 0.1);
stateB = SwarmMath.new([220], 3, 1, variants[\original][\args].deepCopy, 0.2);
synthA = SwarmRegistryTestPlayback.new;
synthB = SwarmRegistryTestPlayback.new;
envA.put(\alphaState, stateA); envA.put(\alphaSynth, synthA);
envB.put(\alphaState, stateB); envB.put(\alphaSynth, synthB);

originalArgs = stateA.args.deepCopy;
thisThread.randSeed = 4815;
first = registry.instrument(\alpha, envA);
actualRandom = 100000.rand;
thisThread.randSeed = 4815;
expectedRandom = 100000.rand;
check.(actualRandom == expectedRandom, "first lookup advanced the random stream");
check.(stateA.args == originalArgs, "wrapper construction changed production state");
check.(registry.instrument(\alpha, envA) === first, "same Environment missed its wrapper cache");
second = registry.instrument(\alpha, envB);
check.(second !== first, "different Environments shared a wrapper");

first.setVariant(\revised, preserveDimensions: true, applyLive: false);
stateA = SwarmMath.new([330], 3, 1, variants[\original][\args].deepCopy, 0.3);
synthA = SwarmRegistryTestPlayback.new;
envA.put(\alphaState, stateA); envA.put(\alphaSynth, synthA);
check.(registry.instrument(\alpha, envA) === first, "replacement binding rebuilt its wrapper");
check.(first.state === stateA and: { first.synth === synthA }, "replacement binding was not rebound");
check.(first.variant == \revised, "replacement binding lost its selected variant");

replacementRegistry = SwarmInstrumentRegistry.new;
replacementRegistry.register(\alpha, { |environment|
	(synth: environment[\alphaSynth], state: environment[\alphaState])
}, spec, variants, (label: "Alpha"));
replacementRegistry.register(\raw, { |environment|
	(synth: environment[\rawSynth], state: environment[\rawState])
}, spec, variants, ());
replacementRegistry.adoptCaches(registry);
error = try { registry.names; nil } { |caught| caught };
check.(error.notNil and: { error.what.contains("disposed") },
	"cache adoption did not invalidate the replaced registry");
registry = replacementRegistry;
check.(registry.instrument(\alpha, envA) === first,
	"cache adoption did not preserve the Environment wrapper");
check.(first.variant == \revised, "cache adoption lost the selected variant");

// A cache transfer may retain identity only while the complete constructor
// contract is unchanged. Changed variants/specs rebuild on the next lookup,
// preserve a still-valid selection, and leave live state/playback untouched.
changedVariants = variants.deepCopy;
changedVariants[\revised][\args][\amp] = { |e| e.vol / (e.p1 ** 3) };
changedVariants[\revised][\partials] = 5;
changedRegistry = SwarmInstrumentRegistry.new;
changedRegistry.register(\alpha, { |environment|
	(synth: environment[\alphaSynth], state: environment[\alphaState])
}, (synthDef: \changedRegistryTest, hasGate: false, liveSwitch: \nextTrigger),
	changedVariants, (label: "Changed Alpha"));
changedRegistry.register(\raw, { |environment|
	(synth: environment[\rawSynth], state: environment[\rawState])
}, spec, variants, ());
changedRegistry.adoptCaches(registry);
registry = changedRegistry;
originalArgs = stateA.args.deepCopy;
rebuilt = registry.instrument(\alpha, envA);
check.(rebuilt !== first, "changed registration silently reused a stale wrapper");
check.(rebuilt.variant == \revised, "changed registration lost a still-valid selection");
check.(rebuilt.synthDef == \changedRegistryTest and: {
	 rebuilt.hasGate.not and: { rebuilt.liveSwitch == \nextTrigger }
}, "rebuilt wrapper did not adopt the changed spec");
check.(rebuilt.state === stateA and: { rebuilt.synth === synthA },
	"changed registration replaced live state or playback");
check.(stateA.args == originalArgs, "changed registration modified live state while rebuilding");
error = try { first.setVariant(\original); nil } { |caught| caught };
check.(error.notNil and: { error.what.contains("disposed") },
	"stale wrapper remained active after a contract-aware rebuild");

// When the selected variant no longer exists, use the new explicit default.
fallbackVariants = (fallback: variants[\original].deepCopy);
fallbackRegistry = SwarmInstrumentRegistry.new;
fallbackRegistry.register(\alpha, { |environment|
	(synth: environment[\alphaSynth], state: environment[\alphaState])
}, (synthDef: \fallbackRegistryTest, variant: \fallback,
	hasGate: true, liveSwitch: \sustained), fallbackVariants, ());
fallbackRegistry.register(\raw, { |environment|
	(synth: environment[\rawSynth], state: environment[\rawState])
}, spec, variants, ());
fallbackRegistry.adoptCaches(registry);
registry = fallbackRegistry;
rebuilt = registry.instrument(\alpha, envA);
check.(rebuilt.variant == \fallback,
	"removed selected variant did not fall back to the new registered default");
check.(rebuilt.state === stateA and: { rebuilt.synth === synthA },
	"variant fallback replaced live state or playback");

envA.put(\rawState, (value: 42)); envA.put(\rawSynth, SwarmRegistryTestPlayback.new);
raw = registry.at(\raw, envA);
check.(raw[\state][\value] == 42 and: { raw[\instrument].isNil },
	"raw lookup rejected a non-SwarmMath state");
error = try { registry.instrument(\raw, envA); nil } { |caught| caught };
check.(error.notNil and: { error.what.contains("SwarmMath") },
	"strict lookup did not reject a non-SwarmMath state descriptively");

error = try { registry.at(\missing, envA); nil } { |caught| caught };
check.(error.notNil and: { error.what.contains("missing") }, "unknown-name error was not descriptive");

registry.dispose;
check.(synthA.releaseCount == 0 and: { synthA.disposeCount == 0 and: { synthA.cancelCount == 0 } },
	"registry disposal operated on borrowed playback");
check.(synthB.releaseCount == 0 and: { synthB.disposeCount == 0 and: { synthB.cancelCount == 0 } },
	"registry disposal operated on another Environment's playback");

"PASS: SwarmInstrumentRegistry isolation and lifecycle".postln;
0.exit;
)
