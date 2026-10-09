SwarmInstrumentRegistry {
	var entries, order, caches, cacheContracts, disposed = false;

	*new {
		^super.new.init;
	}

	init {
		entries = IdentityDictionary.new;
		order = List.new;
		caches = IdentityDictionary.new;
		cacheContracts = IdentityDictionary.new;
		^this;
	}

	prCheckActive {
		if (disposed) {
			Error("SwarmInstrumentRegistry: registry has been disposed").throw;
		};
	}

	prEntry { |name|
		var entry;
		this.prCheckActive;
		entry = entries[name];
		if (entry.isNil) {
			Error("SwarmInstrumentRegistry: unknown instrument %".format(name)).throw;
		};
		^entry;
	}

	register { |name, resolver, spec, variants, metadata|
		this.prCheckActive;
		if (name.isKindOf(Symbol).not) {
			Error("SwarmInstrumentRegistry: instrument names must be symbols").throw;
		};
		if (resolver.isKindOf(Function).not) {
			Error("SwarmInstrumentRegistry: resolver for % must be a Function".format(name)).throw;
		};
		if (spec.isKindOf(Dictionary).not) {
			Error("SwarmInstrumentRegistry: spec for % must be a dictionary or Event".format(name)).throw;
		};
		if (spec[\synthDef].isNil) {
			Error("SwarmInstrumentRegistry: spec for % requires synthDef".format(name)).throw;
		};
		if (variants.isKindOf(Dictionary).not or: { variants.isEmpty }) {
			Error("SwarmInstrumentRegistry: variants for % must be a nonempty dictionary or Event"
				.format(name)).throw;
		};
		if (metadata.isNil) { metadata = IdentityDictionary.new };
		if (metadata.isKindOf(Dictionary).not) {
			Error("SwarmInstrumentRegistry: metadata for % must be a dictionary or Event"
				.format(name)).throw;
		};
		if (entries[name].notNil) {
			Error("SwarmInstrumentRegistry: instrument % is already registered".format(name)).throw;
		};
		entries[name] = (
			resolver: resolver,
			spec: spec,
			variants: variants,
			metadata: metadata
		);
		order.add(name);
		^this;
	}

	names {
		this.prCheckActive;
		^order.asArray;
	}

	spec { |name|
		^this.prEntry(name)[\spec];
	}

	metadata { |name|
		// Metadata is deliberately mutable so a composition can enrich the
		// generic registration before constructing its audition controller.
		^this.prEntry(name)[\metadata];
	}

	prResolve { |name, environment|
		var entry = this.prEntry(name), resolved, synth, state;
		if (environment.isNil) { environment = currentEnvironment };
		if (environment.isKindOf(Environment).not) {
			Error("SwarmInstrumentRegistry: lookup environment must be an Environment").throw;
		};
		resolved = entry[\resolver].value(environment);
		if (resolved.isKindOf(Dictionary).not) {
			Error("SwarmInstrumentRegistry: resolver for % must return an Event or dictionary"
				.format(name)).throw;
		};
		synth = resolved[\synth];
		state = resolved[\state];
		if (synth.isNil) {
			Error("SwarmInstrumentRegistry: missing synth for instrument %".format(name)).throw;
		};
		if (state.isNil) {
			Error("SwarmInstrumentRegistry: missing state for instrument %".format(name)).throw;
		};
		^(entry: entry, synth: synth, state: state, environment: environment);
	}

	prCacheFor { |environment|
		var cache = caches[environment];
		if (cache.isNil) {
			cache = IdentityDictionary.new;
			caches[environment] = cache;
		};
		^cache;
	}

	prContractsFor { |environment|
		var contracts = cacheContracts[environment];
		if (contracts.isNil) {
			contracts = IdentityDictionary.new;
			cacheContracts[environment] = contracts;
		};
		^contracts;
	}

	prContractFor { |entry|
		var spec = entry[\spec];
		^(
			synthDef: spec[\synthDef],
			defaultParams: spec[\defaultParams].deepCopy,
			hasGate: spec[\hasGate] ? true,
			liveSwitch: spec[\liveSwitch] ? \sustained,
			variants: entry[\variants].deepCopy
		);
	}

	prDetachAndDispose { |wrapper|
		wrapper.bind(wrapper.state, nil);
		wrapper.dispose;
	}

	prInstrumentFor { |name, resolved|
		var entry = resolved[\entry], state = resolved[\state];
		var synth = resolved[\synth], cache, contracts, wrapper, replacement;
		var template, spec, selected, contract;
		if (state.isKindOf(SwarmMath).not) {
			Error("SwarmInstrumentRegistry: instrument % state must be a SwarmMath"
				.format(name)).throw;
		};
		cache = this.prCacheFor(resolved[\environment]);
		contracts = this.prContractsFor(resolved[\environment]);
		wrapper = cache[name];
		contract = this.prContractFor(entry);
		if (wrapper.notNil and: { contracts[name] != contract }) {
			// Construct the replacement before invalidating the old wrapper. A bad
			// changed contract therefore fails atomically and leaves the cache usable.
			spec = entry[\spec];
			selected = if (entry[\variants][wrapper.variant].notNil) {
				wrapper.variant
			} { spec[\variant] ? \original };
			template = SwarmMath.new(state.freqs.copy, state.partials, state.variations,
				state.args.deepCopy, state.vol);
			replacement = SwarmInstrument.new(spec[\synthDef], template, entry[\variants],
				selected, spec[\defaultParams], spec[\hasGate] ? true,
				spec[\liveSwitch] ? \sustained, synth);
			replacement.bind(state, synth);
			this.prDetachAndDispose(wrapper);
			wrapper = replacement;
			cache[name] = wrapper;
			contracts[name] = contract;
		};
		if (wrapper.isNil) {
			spec = entry[\spec];
			selected = spec[\variant] ? \original;
			// SwarmInstrument validates and applies the selected variant during
			// construction. Do that work on a private clone, then bind the
			// untouched production objects supplied by the composition.
			template = SwarmMath.new(state.freqs.copy, state.partials, state.variations,
				state.args.deepCopy, state.vol);
			wrapper = SwarmInstrument.new(spec[\synthDef], template, entry[\variants],
				selected, spec[\defaultParams], spec[\hasGate] ? true,
				spec[\liveSwitch] ? \sustained, synth);
			wrapper.bind(state, synth);
			cache[name] = wrapper;
			contracts[name] = contract;
		} {
			// Resolve on every lookup so live-coded replacements take effect.
			// bind retains the selected variant while leaving new state untouched.
			wrapper.bind(state, synth);
		};
		^wrapper;
	}

	at { |name, environment|
		var resolved, wrapper;
		if (environment.isNil) { environment = currentEnvironment };
		resolved = this.prResolve(name, environment);
		wrapper = if (resolved[\state].isKindOf(SwarmMath)) {
			this.prInstrumentFor(name, resolved)
		} { nil };
		^(synth: resolved[\synth], state: resolved[\state], instrument: wrapper);
	}

	instrument { |name, environment|
		var resolved;
		if (environment.isNil) { environment = currentEnvironment };
		resolved = this.prResolve(name, environment);
		^this.prInstrumentFor(name, resolved);
	}

	instruments { |environment|
		this.prCheckActive;
		if (environment.isNil) { environment = currentEnvironment };
		if (environment.isKindOf(Environment).not) {
			Error("SwarmInstrumentRegistry: lookup environment must be an Environment").throw;
		};
		^this.prCacheFor(environment);
	}

	adoptCaches { |other|
		this.prCheckActive;
		if (other === this) { ^this };
		if (other.isKindOf(SwarmInstrumentRegistry).not) {
			Error("SwarmInstrumentRegistry: caches can only be adopted from another registry").throw;
		};
		if (caches.isEmpty.not) {
			Error("SwarmInstrumentRegistry: caches can only be adopted into an unused registry").throw;
		};
		other.prRelinquishCacheState.keysValuesDo { |key, value|
			if (key == \caches) { caches = value } { cacheContracts = value };
		};
		^this;
	}

	prRelinquishCacheState {
		var transferred;
		this.prCheckActive;
		transferred = (caches: caches, contracts: cacheContracts);
		caches = IdentityDictionary.new;
		cacheContracts = IdentityDictionary.new;
		disposed = true;
		^transferred;
	}

	dispose {
		if (disposed.not) {
			caches.values.do { |cache|
				cache.values.do { |wrapper|
					// Detach the borrowed playback first. SwarmInstrument.dispose then
					// invalidates only the wrapper and cannot release composition nodes.
					this.prDetachAndDispose(wrapper);
				};
				cache.clear;
			};
			caches.clear;
			cacheContracts.clear;
			disposed = true;
		};
		^this;
	}
}
