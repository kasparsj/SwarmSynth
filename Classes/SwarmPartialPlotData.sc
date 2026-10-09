SwarmPartialPlotData {
	*fromCapture { |capture, axis=\frequency, display=\generated, baseIndex=nil, variation=nil|
		var finite, count, records, sampleRate, nyquist, metadata, interpreter, defaultPolicy;
		var policyName, selected, transformed, grouped, axisValues;
		var axisMin, axisMax, padding, amplitudeMax, label, name;

		finite = { |value|
			value.isKindOf(SimpleNumber) and: {
				value.isNaN.not and: { value.abs != inf }
			}
		};
		count = { |value, field|
			if (value.isInteger.not or: { value < 0 }) {
				Error("Partial plot % must be a nonnegative integer".format(field)).throw;
			};
			value;
		};
		if (capture.isKindOf(Dictionary).not) {
			Error("Partial plot capture must be an Event or Dictionary").throw;
		};
		if ([\frequency, \partial].includes(axis).not) {
			Error("Partial plot axis must be \\frequency or \\partial").throw;
		};
		if ([\generated, \policy].includes(display).not) {
			Error("Partial plot display must be \\generated or \\policy").throw;
		};
		if (baseIndex.notNil) { baseIndex = count.(baseIndex, "baseIndex") };
		if (variation.notNil) { variation = count.(variation, "variation") };
		records = capture[\records];
		if (records.isSequenceableCollection.not) {
			Error("Partial plot capture requires snapshot records").throw;
		};
		name = capture[\name];
		if (name.isKindOf(Symbol).not) {
			Error("Partial plot capture requires an instrument name").throw;
		};
		sampleRate = capture[\sampleRate];
		if (finite.(sampleRate).not or: { sampleRate <= 0 }) {
			Error("Partial plot sampleRate must be a positive finite number").throw;
		};
		nyquist = sampleRate * 0.5;
		metadata = capture[\metadata] ? ();
		interpreter = metadata[\frequencyInterpretation] ? capture[\frequencyInterpretation];
		defaultPolicy = metadata[\defaultNyquistPolicy]
			? capture[\defaultNyquistPolicy] ? \none;
		if (interpreter.notNil and: { interpreter.isKindOf(Function).not }) {
			Error("Partial plot frequencyInterpretation must be a Function").throw;
		};
		if ([\none, \fold, \mute, \taper].includes(defaultPolicy).not) {
			Error("Partial plot has an invalid default Nyquist policy").throw;
		};
		policyName = { |values|
			var mode = values[\nyquistMode];
			if (mode.isNil or: { mode == -1 }) {
				mode = if (values[\foldNyquist].notNil) {
					if (values[\foldNyquist] > 0) { \fold } { \none }
				} { defaultPolicy };
			};
			if (mode.isNumber) {
				mode = [\none, \fold, \mute, \taper].at(mode.asInteger);
			};
			if ([\none, \fold, \mute, \taper].includes(mode).not) {
				Error("Partial plot has an invalid Nyquist policy").throw;
			};
			mode;
		};

		selected = records.select { |record|
			(baseIndex.isNil or: { record[\freqIndex] == baseIndex })
			and: { variation.isNil or: { record[\variation] == variation } }
		};
		transformed = selected.collect { |record, order|
			var values = record[\values], partialIndex, partial, generated, interpreted;
			var mode, policy, effective, gain, amplitude, shownAmplitude, db, x;
			if (values.isKindOf(Dictionary).not) {
				Error("Partial plot snapshot record requires values").throw;
			};
			partialIndex = record[\partial] ? (record[\index] ? order);
			count.(partialIndex, "record partial");
			partial = partialIndex + 1;
			count.(record[\freqIndex], "record freqIndex");
			count.(record[\variation], "record variation");
			generated = values[\freq];
			amplitude = values[\amp];
			if (finite.(generated).not or: { finite.(amplitude).not }) {
				Error("Partial plot frequency and amplitude must be finite numbers").throw;
			};
			interpreted = if (interpreter.notNil) { interpreter.value(values) } { generated };
			if (finite.(interpreted).not) {
				Error("Partial plot interpreted frequency must be finite").throw;
			};
			mode = policyName.(values);
			policy = SwarmMath.frequencyPolicy(interpreted, sampleRate, mode);
			effective = policy[0];
			gain = policy[1];
			shownAmplitude = if (display == \policy) { amplitude * gain } { amplitude };
			db = if (shownAmplitude == 0) { -100.0 } {
				shownAmplitude.abs.ampdb.max(-100)
			};
			x = if (axis == \partial) { partial } {
				if (display == \policy) { effective } { interpreted }
			};
			(
				index: record[\index] ? order,
				freqIndex: record[\freqIndex], partial: partial,
				variation: record[\variation], baseFrequency: record[\baseFrequency],
				ratio: record[\ratio], nominalRatio: if(generated == 0) { 1.0 } { interpreted / generated },
				phase: values[\phase], generatedFrequency: interpreted,
				effectiveFrequency: effective, frequencyGain: gain,
				frequency: if(display == \policy) { effective } { interpreted },
				amplitude: shownAmplitude, inputAmplitude: amplitude, amplitudeDb: db,
				x: x, y: db, policy: mode, policyLabel: mode.asString,
				zero: shownAmplitude == 0, negative: shownAmplitude < 0,
				order: order, coincidenceIndex: 0, coincidenceCount: 1
			)
		};
		grouped = Dictionary.new;
		transformed.do { |record|
			var coincident = grouped[record[\x]];
			if (coincident.isNil) {
				coincident = List.new;
				grouped[record[\x]] = coincident;
			};
			coincident.add(record);
		};
		grouped.values.do { |coincident|
			coincident.do { |record, index|
				record[\coincidenceIndex] = index;
				record[\coincidenceCount] = coincident.size;
			};
		};
		transformed = transformed.sort { |a, b|
			if (a[\x] == b[\x]) { a[\order] < b[\order] } { a[\x] < b[\x] }
		};
		axisValues = transformed.collect { |record| record[\x] };
		if (axisValues.isEmpty) {
			axisMin = 0.0; axisMax = 1.0; amplitudeMax = 0.0;
		} {
			axisMin = axisValues.minItem;
			axisMax = axisValues.maxItem;
			if (axisMin == axisMax) {
				padding = if (axisMin == 0) { 1.0 } { axisMin.abs * 0.01 };
				axisMin = axisMin - padding;
				axisMax = axisMax + padding;
			};
			amplitudeMax = transformed.collect { |record| record[\amplitudeDb] }.maxItem.max(0);
		};
		label = capture[\label] ? name.asString;
		^(
			records: transformed, axis: axis, display: display,
			axisLabel: if(axis == \frequency) { "Frequency" } { "Partial" },
			axisUnit: if(axis == \frequency) { "Hz" } { "number" },
			axisMin: axisMin, axisMax: axisMax,
			axisLog: axis == \frequency and: { axisMin > 0 },
			amplitudeLabel: "Amplitude (dB)", amplitudeMin: -100.0,
			amplitudeMax: amplitudeMax, nyquist: nyquist,
			nyquistVisible: axis == \frequency,
			nyquistOffscale: axis == \frequency and: { nyquist < axisMin or: { nyquist > axisMax } },
			nyquistSide: if(axis != \frequency or: { nyquist >= axisMin and: { nyquist <= axisMax } }) {
				\inside
			} { if(nyquist < axisMin) { \left } { \right } },
			nyquistLabel: "Nyquist " ++ nyquist.round(0.1).asString ++ " Hz",
			sampleRate: sampleRate,
			sampleRateLabel: capture[\sampleRateLabel] ? (sampleRate.asString ++ " Hz"),
			status: capture[\status] ? \preview, label: label, estimated: true,
			estimateLabel: if(label.toLower.contains("generated-input estimate")) {
				label
			} { label ++ " — generated-input estimate" },
			baseIndices: records.collect { |record| record[\freqIndex] }.asSet.asArray.sort,
			variations: records.collect { |record| record[\variation] }.asSet.asArray.sort,
			selectedBaseIndex: baseIndex, selectedVariation: variation,
			empty: transformed.isEmpty
		)
	}
}
