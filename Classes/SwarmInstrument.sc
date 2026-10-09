SwarmInstrument {
	var <synthDef, <state, variantDefinitions, <variant, <defaultParams;
	var <hasGate, <liveSwitch, playback, ownsPlayback = false, disposed = false;

	*new { |synthDef, state, variants, variant=\original, defaultParams=nil,
		hasGate=true, liveSwitch=\sustained, synth=nil|
		^super.new.init(synthDef, state, variants, variant, defaultParams,
			hasGate, liveSwitch, synth);
	}

	*prDefinition { |name, definition|
		var normalized, args, partials, variations;
		if (definition.isKindOf(Dictionary).not) {
			Error("SwarmInstrument: variant % must be a dictionary or Event".format(name)).throw;
		};
		args = definition[\args];
		if (args.isNil) {
			Error("SwarmInstrument: variant % requires a complete args definition".format(name)).throw;
		};
		args = if (args.isKindOf(Dictionary)) {
			args.deepCopy
		} {
			if (args.isSequenceableCollection.not) {
				Error("SwarmInstrument: variant % args must be a dictionary or flat pairs".format(name)).throw;
			};
			Dictionary.newFrom(args.asPairs.deepCopy);
		};
		partials = definition[\partials];
		variations = definition[\variations];
		if (partials.notNil) { partials = SwarmMath.prCount(partials, "variant partials") };
		if (variations.notNil) { variations = SwarmMath.prCount(variations, "variant variations") };
		normalized = IdentityDictionary.new;
		normalized[\args] = args;
		if (partials.notNil) { normalized[\partials] = partials };
		if (variations.notNil) { normalized[\variations] = variations };
		^normalized;
	}

	init { |aSynthDef, aState, variants, selected, params, gate, switchMode, synth|
		var copied = IdentityDictionary.new;
		if (aState.isKindOf(SwarmMath).not) {
			Error("SwarmInstrument: state must be a SwarmMath").throw;
		};
		if (variants.isKindOf(Dictionary).not or: { variants.isEmpty }) {
			Error("SwarmInstrument: variants must be a nonempty dictionary or Event").throw;
		};
		if ([\sustained, \nextTrigger].includes(switchMode).not) {
			Error("SwarmInstrument: liveSwitch must be \\sustained or \\nextTrigger").throw;
		};
		variants.keysValuesDo { |name, definition|
			if (name.isKindOf(Symbol).not) {
				Error("SwarmInstrument: variant names must be symbols").throw;
			};
			copied[name] = SwarmInstrument.prDefinition(name, definition);
		};
		if (copied[selected].isNil) {
			Error("SwarmInstrument: unknown variant %".format(selected)).throw;
		};
		synthDef = aSynthDef;
		state = aState;
		variantDefinitions = copied;
		defaultParams = params.deepCopy;
		hasGate = gate;
		liveSwitch = switchMode;
		playback = synth;
		ownsPlayback = synth.isNil;
		variant = selected;
		this.prCompleteDefinitions;
		this.prCommitState(this.cloneStateForVariant(selected, false));
		^this;
	}

	variantNames {
		^variantDefinitions.keys.asArray.sort { |a, b| a.asString < b.asString };
	}

	variants {
		^variantDefinitions.deepCopy;
	}

	synth {
		^playback;
	}

	// Dictionary-style access keeps existing composition registry call sites usable.
	at { |key|
		^switch(key,
			\state, { state },
			\synth, { playback },
			\instrument, { this },
			\variant, { variant },
			{ nil }
		);
	}

	variant_ { |name|
		this.setVariant(name);
		^name;
	}

	prCheckActive {
		if (disposed) { Error("SwarmInstrument: instrument has been disposed").throw };
	}

	prDefinitionFor { |name|
		var definition = variantDefinitions[name];
		if (definition.isNil) {
			Error("SwarmInstrument: unknown variant %".format(name)).throw;
		};
		^definition;
	}

	prControlDefaults {
		var result = Dictionary.new, desc;
		desc = try { SynthDescLib.global.at(synthDef) } { nil };
		desc !? {
			desc.controls.do { |control|
				result[control.name] = control.defaultValue.deepCopy;
			};
		};
		if (defaultParams.isKindOf(Dictionary)) {
			result.putAll(defaultParams);
		} {
			if (defaultParams.isSequenceableCollection) {
				result.putAll(Dictionary.newFrom(defaultParams.asPairs));
			};
		};
		^result;
	}

	prCompleteDefinitions {
		var keys = Set.new, defaults = this.prControlDefaults;
		variantDefinitions.values.do { |definition|
			definition[\args].keys.do { |key|
				if (key != \ratio) { keys.add(key) };
			};
		};
		variantDefinitions.keysValuesDo { |name, definition|
			keys.do { |key|
				if (definition[\args][key].isNil) {
					if (defaults[key].isNil) {
						Error("SwarmInstrument: variant % omits control % without a SynthDef or defaultParams default"
							.format(name, key)).throw;
					};
					definition[\args][key] = defaults[key].deepCopy;
				};
			};
		};
	}

	cloneStateForVariant { |name, preserveDimensions=true|
		var definition = this.prDefinitionFor(name), args, partials, variations, defaults;
		var runtimeKeys = [\out, \duration, \dur, \gate];
		args = definition[\args].deepCopy;
		if (defaultParams.isKindOf(Dictionary)) {
			defaults = defaultParams;
		} {
			if (defaultParams.isSequenceableCollection) {
				defaults = Dictionary.newFrom(defaultParams.asPairs);
			};
		};
		defaults !? { |values|
			values.keysValuesDo { |key, value|
				if (args[key].isNil) { args[key] = value.deepCopy };
			};
		};
		runtimeKeys.do { |key|
			if (state.args[key].notNil) { args[key] = state.args[key].deepCopy };
		};
		partials = if (preserveDimensions or: { definition[\partials].isNil }) {
			state.partials
		} {
			definition[\partials]
		};
		variations = if (preserveDimensions or: { definition[\variations].isNil }) {
			state.variations
		} {
			definition[\variations]
		};
		^SwarmMath.new(state.freqs.copy, partials, variations, args, state.vol);
	}

	prCommitState { |target|
		state.freqs = target.freqs;
		state.partials = target.partials;
		state.variations = target.variations;
		state.args = target.args;
		state.vol = target.vol;
	}

	prSampleTarget { |target|
		var sampled = Array.fill(target.size, { |index|
			var pairs = target.calc(index), values = pairs.asDict;
			var frequency = values[\freq], amplitude = values[\amp];
			if (frequency.notNil and: {
				SwarmMath.prFiniteNumber(frequency).not or: { frequency <= 0 }
			}) {
				Error("SwarmInstrument: generated frequencies must be positive finite numbers").throw;
			};
			if (amplitude.isKindOf(SimpleNumber) and: {
				SwarmMath.prFiniteNumber(amplitude).not
			}) {
				Error("SwarmInstrument: generated numeric amplitudes must be finite").throw;
			};
			pairs;
		});
		^this.prPreserveNodeRuntime(sampled);
	}

	prValidateTarget { |target|
		var savedRandom = thisThread.randData.copy;
		{ this.prSampleTarget(target) }.protect {
			thisThread.randData = savedRandom;
		};
		^this;
	}

	prSampleTargetForPlayback { |target|
		var savedRandom = thisThread.randData.copy, sampled;
		sampled = try {
			this.prSampleTarget(target)
		} { |caught|
			thisThread.randData = savedRandom;
			caught.throw;
		};
		^sampled;
	}

	prPreserveNodeRuntime { |sampled|
		var runtimeKeys = [\out, \duration, \dur, \gate];
		if (playback.notNil and: { playback.respondsTo(\params) }) {
			playback.params.do { |oldPairs, index|
				if (oldPairs.notNil and: { index < sampled.size }) {
					var old = oldPairs.asDict, target = sampled[index].asDict;
					runtimeKeys.do { |key|
						if (old[key].notNil) { target[key] = old[key].deepCopy };
					};
					sampled[index] = target.asPairs;
				};
			};
		};
		^sampled;
	}

	prEnsureSynth {
		this.prCheckActive;
		if (playback.isNil) {
			playback = SwarmSynth.new(synthDef, defaultParams.deepCopy, hasGate);
			ownsPlayback = true;
		};
		^playback;
	}

	bind { |aState, synth|
		var oldPlayback = playback, oldOwned = ownsPlayback;
		var samePlayback;
		this.prCheckActive;
		if (aState.isKindOf(SwarmMath).not) {
			Error("SwarmInstrument: bound state must be a SwarmMath").throw;
		};
		samePlayback = oldPlayback === synth;
		if (oldOwned and: { oldPlayback.notNil and: { samePlayback.not } }) {
			oldPlayback.dispose;
		};
		state = aState;
		playback = synth;
		ownsPlayback = if (samePlayback) { oldOwned } { synth.isNil };
		^this;
	}

	setVariant { |name, transitionTime=0, preserveDimensions=false, applyLive=true|
		var target, wasPlaying, sampled;
		this.prCheckActive;
		this.prDefinitionFor(name);
		if (SwarmMath.prFiniteNumber(transitionTime).not or: { transitionTime < 0 }) {
			Error("SwarmInstrument: transitionTime must be a nonnegative finite number").throw;
		};
		if (name == variant) { ^this };
		// Build and validate everything before changing selection, state, or playback.
		target = this.cloneStateForVariant(name, preserveDimensions);
		wasPlaying = playback.notNil and: { playback.isPlaying };
		if (wasPlaying and: { applyLive and: { liveSwitch == \sustained } }) {
			sampled = this.prSampleTargetForPlayback(target);
		} {
			this.prValidateTarget(target);
		};
		this.prCommitState(target);
		variant = name;
		if (wasPlaying and: { applyLive and: { liveSwitch == \sustained } }) {
			if (transitionTime > 0) {
				playback.rampToSampled(sampled, transitionTime, \lin, [\phase, \pan]);
			} {
				playback.setSampled(sampled, excludeParams: [\phase, \pan]);
			};
		};
		^this;
	}

	reapplyVariant { |preserveDimensions=true, applyLive=false, transitionTime=0|
		var target, wasPlaying, sampled;
		this.prCheckActive;
		if (SwarmMath.prFiniteNumber(transitionTime).not or: { transitionTime < 0 }) {
			Error("SwarmInstrument: transitionTime must be a nonnegative finite number").throw;
		};
		target = this.cloneStateForVariant(variant, preserveDimensions);
		wasPlaying = playback.notNil and: { playback.isPlaying };
		if (wasPlaying and: { applyLive and: { liveSwitch == \sustained } }) {
			sampled = this.prSampleTargetForPlayback(target);
		} {
			this.prValidateTarget(target);
		};
		this.prCommitState(target);
		if (wasPlaying and: { applyLive and: { liveSwitch == \sustained } }) {
			if (transitionTime > 0) {
				playback.rampToSampled(sampled, transitionTime, \lin, [\phase, \pan]);
			} {
				playback.setSampled(sampled, excludeParams: [\phase, \pan]);
			};
		};
		^this;
	}

	play { |event=nil|
		this.prCheckActive;
		state.putEvent(event ? ());
		if (playback.notNil and: { liveSwitch == \nextTrigger }) {
			// Forget handles without releasing one-shot tails; the next set creates
			// fresh nodes with the newly selected definition.
			playback.reset;
		};
		this.prEnsureSynth.set(state);
		^this;
	}

	closeGate {
		this.prCheckActive;
		if (playback.notNil) { playback.closeGate };
		^this;
	}

	release {
		this.prCheckActive;
		if (playback.notNil) { playback.release };
		^this;
	}

	dispose {
		if (disposed.not) {
			if (playback.notNil) {
				if (ownsPlayback) { playback.dispose } { playback.cancelRamp };
			};
			playback = nil;
			disposed = true;
		};
		^this;
	}
}
