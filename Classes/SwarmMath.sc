SwarmMath {
	var <>freqs, <>partials, <>variations, <>args, <>vol;

	*prFiniteNumber { |value|
		^value.isKindOf(SimpleNumber) and: {
			value.isNaN.not and: { value.abs != inf }
		};
	}

	*prCount { |value, name|
		if (this.prFiniteNumber(value).not or: {
			(value < 0) or: { value != value.asInteger }
		}) { Error("SwarmMath: % must be a nonnegative whole number".format(name)).throw };
		^value.asInteger;
	}

	*prIndex { |value, limit, name|
		var index = this.prCount(value, name);
		if (index >= limit) {
			Error("SwarmMath: % index % is outside 0..%".format(name, index, limit - 1)).throw;
		};
		^index;
	}

	*prDimensions { |freqs, partials, variations|
		if (freqs.isSequenceableCollection.not) {
			Error("SwarmMath: freqs must be a sequenceable collection").throw;
		};
		this.prCount(partials, "partials");
		this.prCount(variations, "variations");
	}

	*prSampleRate { |sampleRate|
		if (this.prFiniteNumber(sampleRate).not or: { sampleRate <= 0 }) {
			Error("SwarmMath: sampleRate must be a positive finite number").throw;
		};
		^sampleRate;
	}

	*prFrequencies { |values|
		if (values.isSequenceableCollection.not) {
			Error("SwarmMath: frequencies must be a sequenceable collection").throw;
		};
		values.do { |value|
			if (this.prFiniteNumber(value).not or: { value <= 0 }) {
				Error("SwarmMath: frequencies must be positive finite numbers").throw;
			};
		};
		^values;
	}

	*prRatioBasis { |e, basis|
		if (basis == \index) { ^e.p1 };
		if (basis == \ratio) { ^e.ratio };
		Error("SwarmMath: amplitude basis must be \\index or \\ratio").throw;
	}

	*prIsPrime { |value|
		var divisor = 2;
		if (value < 2) { ^false };
		while { divisor * divisor <= value } {
			if ((value % divisor) == 0) { ^false };
			divisor = divisor + 1;
		};
		^true;
	}

	*prPolicyMode { |mode|
		if (mode.isKindOf(UGen)) { ^mode };
		if (mode.isKindOf(Symbol)) {
			^[\none, \fold, \mute, \taper].indexOf(mode) ?? {
				Error("SwarmMath: unknown frequency policy %".format(mode)).throw
			};
		};
		if (this.prFiniteNumber(mode).not or: {
			(mode < 0) or: { (mode > 3) or: { mode != mode.asInteger } }
		}) { Error("SwarmMath: frequency policy must be none/fold/mute/taper or 0..3").throw };
		^mode.asInteger;
	}

	// Numeric calculations require a sample rate; SynthDefs use SampleRate.ir.
	*foldFrequency { |freq, sampleRate|
		if (sampleRate.isKindOf(UGen).not) { this.prSampleRate(sampleRate) };
		// Numeric constants need a UGen when their fold boundary is server-side.
		if (freq.isKindOf(SimpleNumber) and: { sampleRate.isKindOf(UGen) }) {
			^Fold.kr(freq, 0, sampleRate * 0.5);
		};
		^freq.fold(0, sampleRate * 0.5);
	}

	// Returns [effectiveFrequency, amplitudeGain]. UGen modes use Select at freq's rate.
	*frequencyPolicy { |freq, sampleRate, mode=\none|
		var policy = this.prPolicyMode(mode), nyquist, folded, magnitude, muteGain, taperGain;
		var frequencies, gains;
		if (sampleRate.isKindOf(UGen).not) { this.prSampleRate(sampleRate) };
		nyquist = sampleRate * 0.5;
		folded = this.foldFrequency(freq, sampleRate);
		magnitude = freq.abs;
		muteGain = if (magnitude.isKindOf(SimpleNumber) and: {
			nyquist.isKindOf(SimpleNumber)
		}) { if (magnitude < nyquist) { 1.0 } { 0.0 } } { magnitude < nyquist };
		taperGain = ((nyquist - magnitude) / (nyquist * 0.1)).clip(0, 1);
		frequencies = [freq, folded, freq, freq];
		gains = [1, 1, muteGain, taperGain];
		if (policy.isKindOf(UGen)) {
			if (freq.rate == \audio) {
				^[Select.ar(policy.clip(0, 3), frequencies.asAudioRateInput),
					Select.ar(policy.clip(0, 3), gains.asAudioRateInput)];
			};
			^[Select.kr(policy.clip(0, 3), frequencies),
				Select.kr(policy.clip(0, 3), gains)];
		};
		^[frequencies[policy], gains[policy]];
	}

	*ratios { |kind, count, options=nil|
		var result, ratio, exponent, offset, divisions, stiffness, custom;
		var a = 1, b = 2, candidate = 2;
		count = this.prCount(count, "ratio count");
		options = options ? ();
		if (options.isKindOf(Dictionary).not) {
			Error("SwarmMath: ratio options must be a dictionary or Event").throw;
		};
		if ([\harmonic, \odd, \even, \power, \geometric, \equalTemperament,
			\subharmonic, \fibonacci, \prime, \stiffString, \custom].includes(kind).not) {
			Error("SwarmMath: unknown ratio family %".format(kind)).throw;
		};
		if (kind == \power) {
			exponent = options[\exponent] ? 1;
			offset = options[\offset] ? 0;
			if (this.prFiniteNumber(exponent).not or: { this.prFiniteNumber(offset).not }) {
				Error("SwarmMath: power exponent and offset must be finite numbers").throw;
			};
			if ((1 + offset) <= 0) {
				Error("SwarmMath: power index plus offset must stay positive").throw;
			};
		};
		if (kind == \geometric) {
			ratio = options[\ratio] ? 2;
			if (this.prFiniteNumber(ratio).not or: { ratio <= 0 }) {
				Error("SwarmMath: geometric ratio must be a positive finite number").throw;
			};
		};
		if (kind == \equalTemperament) {
			divisions = options[\divisions] ? 12;
			if (this.prFiniteNumber(divisions).not or: { divisions <= 0 }) {
				Error("SwarmMath: equal-temperament divisions must be positive").throw;
			};
		};
		if (kind == \stiffString) {
			stiffness = options[\B] ? (options[\stiffness] ? 0);
			if (this.prFiniteNumber(stiffness).not or: { stiffness < 0 }) {
				Error("SwarmMath: stiff-string B must be a nonnegative finite number").throw;
			};
		};
		if (kind == \custom) {
			custom = options[\values] ? options[\ratios];
			if (custom.isNil.not) {
				if (custom.isSequenceableCollection.not) {
					Error("SwarmMath: custom ratios must be a sequenceable collection").throw;
				};
				custom.do { |value|
					if (this.prFiniteNumber(value).not or: { value <= 0 }) {
						Error("SwarmMath: ratios must be positive finite numbers").throw;
					};
				};
			};
			if (count > 0 and: { custom.isNil or: { custom.size < count } }) {
				Error("SwarmMath: custom ratios require at least count explicit values").throw;
			};
		};
		if (count == 0) { ^[] };
		result = switch(kind,
			\harmonic, { Array.series(count, 1, 1) },
			\odd, { Array.series(count, 1, 2) },
			\even, { Array.series(count, 2, 2) },
			\power, {
				Array.fill(count, { |index| (index + 1 + offset) ** exponent });
			},
			\geometric, {
				Array.fill(count, { |index| ratio ** index });
			},
			\equalTemperament, {
				Array.fill(count, { |index| 2 ** (index / divisions) });
			},
			\subharmonic, { Array.fill(count, { |index| 1.0 / (index + 1) }) },
			\fibonacci, {
				Array.fill(count, { |index|
					var value;
					if (index == 0) { 1 } {
						if (index == 1) { 2 } {
							value = a + b; a = b; b = value; value
						}
					}
				});
			},
			\prime, {
				Array.fill(count, { |index|
					if (index == 0) { 1 } {
						while { this.prIsPrime(candidate).not } { candidate = candidate + 1 };
						ratio = candidate; candidate = candidate + 1; ratio;
					};
				});
			},
			\stiffString, {
				Array.fill(count, { |index|
					var n = index + 1;
					n * (((1 + (stiffness * n.squared)) / (1 + stiffness)).sqrt);
				});
			},
			\custom, {
				custom.copyRange(0, count - 1);
			},
			{ Error("SwarmMath: unknown ratio family %".format(kind)).throw }
		);
		result.do { |value|
			if (this.prFiniteNumber(value).not or: { value <= 0 }) {
				Error("SwarmMath: ratios must be positive finite numbers").throw;
			};
		};
		^result;
	}

	*waveformRecipe { |kind, count|
		var ratios, amplitudes, phases;
		count = this.prCount(count, "waveform partial count");
		ratios = switch(kind,
			\saw, { this.ratios(\harmonic, count) },
			\square, { this.ratios(\odd, count) },
			\triangle, { this.ratios(\odd, count) },
			{ Error("SwarmMath: unknown waveform recipe %".format(kind)).throw }
		);
		amplitudes = if (kind == \triangle) {
			ratios.collect { |value| 1.0 / value.squared }
		} { ratios.collect { |value| 1.0 / value } };
		phases = Array.fill(count, { |index|
			if (kind == \triangle and: { index.odd }) { pi } { 0.0 };
		});
		^(ratios: ratios, amplitudes: amplitudes, phases: phases);
	}

	*normalizeWeights { |weights, mode=\none|
		var divisor;
		if (weights.isSequenceableCollection.not) {
			Error("SwarmMath: weights must be a sequenceable collection").throw;
		};
		weights.do { |value|
			if (this.prFiniteNumber(value).not) {
				Error("SwarmMath: weights must be finite numbers").throw;
			};
		};
		if (mode == \peakBound) { mode = \peak };
		if ([\none, \peak, \energy].includes(mode).not) {
			Error("SwarmMath: normalization mode must be none, peak, or energy").throw;
		};
		if (weights.isEmpty or: { mode == \none }) { ^weights.copy };
		divisor = if (mode == \peak) {
			weights.sum { |value| value.abs }
		} { weights.sum { |value| value.squared }.sqrt };
		if (divisor == 0) { ^weights.copy };
		^weights.collect { |value| value / divisor };
	}

	*freqRatio { |e| ^e.freq * e.ratio }

	*ampPower { |e, exponent=1, basis=\ratio|
		if (this.prFiniteNumber(exponent).not) {
			Error("SwarmMath: amplitude exponent must be a finite number").throw;
		};
		^(1.0 / (this.prRatioBasis(e, basis) ** exponent));
	}

	*ampGaussian { |e, center, width, basis=\index|
		var position = this.prRatioBasis(e, basis);
		if (this.prFiniteNumber(center).not) {
			Error("SwarmMath: Gaussian center must be a finite number").throw;
		};
		if (this.prFiniteNumber(width).not or: { width <= 0 }) {
			Error("SwarmMath: Gaussian width must be a positive finite number").throw;
		};
		^exp(0 - (((position - center).squared) / (2 * width.squared)));
	}

	*ampExponential { |e, rate, basis=\index|
		var position = this.prRatioBasis(e, basis);
		if (this.prFiniteNumber(rate).not) {
			Error("SwarmMath: exponential rate must be a finite number").throw;
		};
		^exp(0 - (rate * (position - 1)));
	}

	*partialDecay { |e, base, exponent=1, minimum=0.01|
		if (this.prFiniteNumber(base).not or: { base < 0 }) {
			Error("SwarmMath: decay base must be a nonnegative finite number").throw;
		};
		if (this.prFiniteNumber(exponent).not) {
			Error("SwarmMath: decay exponent must be a finite number").throw;
		};
		if (this.prFiniteNumber(minimum).not or: { minimum < 0 }) {
			Error("SwarmMath: decay minimum must be a nonnegative finite number").throw;
		};
		^minimum.max(base / (e.ratio ** exponent));
	}

	// The sum (add + partialTerm) is raised to pow, then scaled by e.freq.
	*freqPartial { |e, mul=1, pow=1, offset=0, add=1|
		^(e.freq * ((add + ((e.partial + offset).abs * mul)) ** pow));
	}

	*ampPartial { |e, value, offset=0|
		e = e.copy;
		e.partial = (e.partial+offset).abs;
		e.partial1 = e.partial+1;
		e.p = e.partial;
		e.p1 = e.p+1;
		^value.value(e);
	}

	*ampPartialRec { |e, offset=0, pow=1|
		^(1.0 / ((1 + (e.p+offset).abs)) ** pow);
	}

	*ampPartialRecMod { |e, mod=2, offset=0, pow=1|
		^(1.0 / (1 + ((e.p+offset).abs % mod) ** pow));
	}

	*new { |freqs, partials=0, variations=1, args=#[], vol=1|
		this.prDimensions(freqs, partials, variations);
		^super.newCopyArgs(freqs, partials.asInteger, variations.asInteger,
			Dictionary.newFrom(args.asPairs), vol);
	}

	size {
		SwarmMath.prDimensions(freqs, partials, variations);
		^(freqs.size * partials * variations).asInteger;
	}

	val { |i, param, event=nil|
		i = SwarmMath.prIndex(i, this.size, "event");
		event = event ?? { SwarmEvent.new(i, this) };
		if (param == \ratio) { ^event.ratio };
		^args[param].(event);
	}

	prCalcEvent { |event, params=nil, excludeParams=nil|
		var result = [];
		// Keep playback's existing Set iteration and evaluation order.
		((params ?? args.keys).asSet -- ((excludeParams ? []).asSet.add(\ratio))).do { |param|
			if (args[param].notNil) {
				result = result.addAll([param, this.val(event.i, param, event)]);
			};
		};
		^result;
	}

	calc { |i, params=nil, excludeParams=nil|
		var event;
		i = SwarmMath.prIndex(i, this.size, "event");
		event = SwarmEvent.new(i, this);
		^this.prCalcEvent(event, params, excludeParams);
	}

	get { |param, freqIndex=0|
		var count = this.size;
		freqIndex = SwarmMath.prCount(freqIndex, "freqIndex");
		if (freqs.notEmpty) {
			SwarmMath.prIndex(freqIndex, freqs.size, "freqIndex");
		} {
			if (freqIndex != 0) { Error("SwarmMath: freqIndex has no base frequency").throw };
		};
		if (count == 0) { ^Array.fill(variations.asInteger, { [] }) };
		^Array.fill(variations.asInteger, { |variationIndex|
			Array.fill(partials.asInteger, { |partialIndex|
				this.val((freqIndex * partials * variations)
					+ (partialIndex * variations) + variationIndex, param);
			});
		});
	}

	snapshot { |params=nil, seed=nil|
		var keys, savedRandom, result;
		var count = this.size;
		if (seed.notNil and: { seed.isInteger.not }) {
			Error("SwarmMath: snapshot seed must be an integer or nil").throw;
		};
		keys = if (params.isNil) {
			args.keys.reject { |key| key == \ratio }.asArray.sort { |a, b| a.asString < b.asString };
		} {
			params.asArray.inject([], { |ordered, key|
				if (key == \ratio or: { ordered.includes(key) }) { ordered } { ordered.add(key) };
			});
		};
		savedRandom = thisThread.randData.copy;
		{
			if (seed.notNil) { thisThread.randSeed = seed };
			result = Array.fill(count, { |index|
				var event = SwarmEvent.new(index, this);
				var values = Dictionary.new;
				// Capture node identity before callbacks can mutate the shared event.
				var record = (index: index, freqIndex: event.n.asInteger,
					partial: event.partial.asInteger, variation: event.variation.asInteger,
					baseFrequency: event.freq, ratio: event.ratio, values: values);
				keys.do { |key| values[key] = this.val(index, key, event).deepCopy };
				record;
			});
		}.protect { thisThread.randData = savedRandom };
		^result;
	}

	playbackSnapshot { |seed=nil, preserveRandom=false|
		var savedRandom, result, action;
		var count = this.size;
		if (seed.notNil and: { seed.isInteger.not }) {
			Error("SwarmMath: playbackSnapshot seed must be an integer or nil").throw;
		};
		savedRandom = if (preserveRandom) { thisThread.randData.copy } { nil };
		action = {
			if (seed.notNil) { thisThread.randSeed = seed };
			result = Array.fill(count, { |index|
				var event = SwarmEvent.new(index, this), values;
				// Capture identity before callbacks can mutate the shared event.
				var record = (index: index, freqIndex: event.n.asInteger,
					partial: event.partial.asInteger, variation: event.variation.asInteger,
					baseFrequency: event.freq, ratio: event.ratio, values: nil);
				values = this.prCalcEvent(event).asDict.deepCopy;
				record[\values] = values;
				record;
			});
		};
		if (preserveRandom) {
			action.protect { thisThread.randData = savedRandom };
		} {
			action.value;
		};
		^result;
	}

	putEvent { |event, freqIndex=nil|
		var original = event, proposedFreqs, proposedPartials, proposedVariations;
		var pitchEvent, resolvedFreq, hasPitch, targetIndex;
		var changesFreqs = args[\freq].isFunction;
		event = event.asDict;
		targetIndex = freqIndex ? 0;
		hasPitch = [\freq, \note, \midinote, \degree, \scale, \root, \octave,
			\transpose, \mtranspose, \gtranspose, \ctranspose, \stepsPerOctave,
			\octaveRatio, \harmonic].any { |key|
			event[key].notNil
		};
		proposedFreqs = if (changesFreqs) { (event[\freqs] ? freqs).copy } { freqs };
		proposedPartials = event[\partials] ? partials;
		proposedVariations = event[\variations] ? variations;
		SwarmMath.prDimensions(proposedFreqs, proposedPartials, proposedVariations);
		if (changesFreqs and: { hasPitch }) {
			SwarmMath.prIndex(targetIndex, proposedFreqs.size, "freqIndex");
			// Preserve a literal Event's custom parent/defaults; dictionaries get Event defaults.
			pitchEvent = if (original.isKindOf(Event)) { original.copy } {
				Event.default.putAll(event)
			};
			if (pitchEvent.parent.isNil) { pitchEvent.parent = Event.default.parent };
			// Accept the common \transpose spelling as a chromatic transpose alias.
			if (event[\transpose].notNil and: { event[\ctranspose].isNil }) {
				pitchEvent[\ctranspose] = event[\transpose];
			};
			resolvedFreq = pitchEvent.use { ~freq.value };
			proposedFreqs[targetIndex] = resolvedFreq;
		} {
			if (freqIndex.notNil) { SwarmMath.prIndex(targetIndex, proposedFreqs.size, "freqIndex") };
		};
		SwarmMath.prFrequencies(proposedFreqs);
		if (event[\partials].notNil) {
			partials = event[\partials].asInteger;
		};
		if (event[\variations].notNil) {
			variations = event[\variations].asInteger;
		};
		if (args[\amp].isFunction and: { event[\amp].notNil }) {
			vol = event[\amp];
			event.removeAt(\amp);
		};
		if (args[\freq].isFunction) {
			if (event[\freqs].notNil) {
				event.removeAt(\freqs);
			};
			if (hasPitch) {
				event.removeAt(\freq);
			};
			freqs = proposedFreqs;
		};
		args.putAll(event);
	}

	spectrumReport { |snapshot, sampleRate, mode=nil|
		SwarmMath.prSampleRate(sampleRate);
		if (snapshot.isSequenceableCollection.not) {
			Error("SwarmMath: spectrumReport snapshot must be a sequenceable collection").throw;
		};
		^snapshot.collect { |record|
			var values = record[\values], policy, report, resolvedMode = mode;
			if (values.isKindOf(Dictionary).not) {
				Error("SwarmMath: spectrumReport records require a values dictionary").throw;
			};
			if (resolvedMode.isNil) {
				resolvedMode = values[\nyquistMode];
				if (resolvedMode.isNil or: { resolvedMode == -1 }) {
					resolvedMode = if ((values[\foldNyquist] ? 0) > 0) { \fold } { \none };
				};
			};
			policy = SwarmMath.frequencyPolicy(values[\freq], sampleRate, resolvedMode);
			report = (
				label: "generated-input estimate",
				baseFrequency: record[\baseFrequency], ratio: record[\ratio],
				frequency: values[\freq], amplitude: values[\amp], phase: values[\phase],
				effectiveFrequency: policy[0], frequencyGain: policy[1]
			);
			[\attack, \decay, \sustain, \release, \duration, \fadeTime, \att, \rel].do { |key|
				if (values[key].notNil) { report[key] = values[key] };
			};
			report;
		};
	}

	plotData { |snapshot=nil, freqIndex=0, variation=nil, sampleRate=nil, folded=false|
		var records, selected, entries, channelIndices, domain, values, lo, hi, padding, warp;
		var label = if (folded) { "Nyquist-folded generated-frequency estimate" }
			{ "Generated frequency inputs" };
		freqIndex = SwarmMath.prCount(freqIndex, "freqIndex");
		if (variation.notNil) { variation = SwarmMath.prCount(variation, "variation") };
		if (folded) { SwarmMath.prSampleRate(sampleRate) };
		records = snapshot ?? { this.snapshot([\freq, \amp]) };
		if (records.isSequenceableCollection.not) {
			Error("SwarmMath: plotData snapshot must be a sequenceable collection").throw;
		};
		if (records.isEmpty) {
			^(domain: [], values: [], variations: [], domainSpec: ControlSpec(0, 1, \lin),
				folded: folded, label: "no data");
		};
		records.do { |record|
			if (record.isKindOf(Dictionary).not) {
				Error("SwarmMath: plotData snapshot records must be dictionaries").throw;
			};
		};
		selected = records.select { |record| record[\freqIndex] == freqIndex };
		if (selected.isEmpty) { Error("SwarmMath: freqIndex has no snapshot records").throw };
		if (variation.notNil) {
			selected = selected.select { |record| record[\variation] == variation };
			if (selected.isEmpty) { Error("SwarmMath: variation has no snapshot records").throw };
		};
		entries = selected.collect { |record, order|
			var parameters = record[\values], frequency, amplitude;
			if (parameters.isKindOf(Dictionary).not) {
				Error("SwarmMath: plotData records require a values dictionary").throw;
			};
			frequency = parameters[\freq];
			amplitude = parameters[\amp];
			if (SwarmMath.prFiniteNumber(frequency).not or: {
				SwarmMath.prFiniteNumber(amplitude).not
			}) { Error("SwarmMath: plotData requires finite numeric freq and amp values").throw };
			SwarmMath.prCount(record[\variation], "variation");
			if (folded) { frequency = SwarmMath.foldFrequency(frequency, sampleRate) };
			(frequency: frequency, amplitude: amplitude,
				variation: record[\variation], order: order);
		};
		// Preserve separate coincident records and their frequency/amplitude pairs.
		entries = entries.sort { |a, b|
			if (a[\frequency] == b[\frequency]) { a[\order] < b[\order] }
				{ a[\frequency] < b[\frequency] };
		};
		channelIndices = entries.collect { |entry| entry[\variation] }.asSet.asArray.sort;
		domain = entries.collect { |entry| entry[\frequency] };
		values = channelIndices.collect { |channel|
			entries.collect { |entry|
				if (entry[\variation] == channel) { entry[\amplitude] } { 0 };
			};
		};
		lo = domain.minItem;
		hi = domain.maxItem;
		warp = if (lo > 0) { \exp } { \lin };
		if (lo == hi) {
			padding = if (lo == 0) { 1.0 } { lo.abs * 0.01 };
			lo = lo - padding;
			hi = hi + padding;
		};
		^(domain: domain, values: values, variations: channelIndices,
			domainSpec: ControlSpec(lo, hi, warp), folded: folded, label: label);
	}

	plot { |name, bounds, discrete=false, variation=nil, freqIndex=0,
		snapshot=nil, sampleRate=nil, folded=false|
		var data = this.plotData(snapshot, freqIndex, variation, sampleRate, folded);
		var plotter, title = name ? "SwarmMath";
		if (data[\domain].isEmpty) { Error("SwarmMath: plot has no data").throw };
		if (folded) { title = title ++ " — " ++ data[\label] };
		plotter = data[\values].plot(title, bounds, discrete);
		plotter.domain = data[\domain];
		plotter.domainSpecs = data[\domainSpec];
		plotter.plotMode = \stems;
		^plotter;
	}

}

SwarmEvent {
	var <i, <n, <>freq, <freqs, <>partial, <>partial1, <partials, <variation, <variations, <size;
	var <f, <p, <ps, <p1, <v, <vs, <sz, <nf, <nf, <np, <nv, <vol, <ratio;

	*new { |i, parent|
		var inst = super.newCopyArgs(i);
		inst.init(parent);
		^inst;
	}

	init { |m|
		n = (i / (m.partials * m.variations)).floor;
		freq = m.freqs[n];
		freqs = m.freqs;
		partial = (i / m.variations).floor % m.partials;
		partial1 = partial + 1;
		partials = m.partials;
		variation = i % m.variations;
		variations = m.variations;
		size = m.size;
		vol = m.vol;
		f = freq;
		p = partial;
		ps = partials;
		p1 = p + 1;
		v = variation;
		vs = variations;
		nf = freqs.size;
		np = partials;
		nv = variations;
		ratio = if (m.args[\ratio].notNil) { m.args[\ratio].value(this) } { p1 };
		if (SwarmMath.prFiniteNumber(ratio).not or: { ratio <= 0 }) {
			Error("SwarmMath: resolved ratio must be a positive finite number").throw;
		};
	}
}
