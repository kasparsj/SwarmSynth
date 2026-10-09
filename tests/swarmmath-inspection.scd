// Run with python3 tests/run-swarmmath-inspection.py. No audio server is started.
(
var check, checkNear, checkThrows, makeState, state, actual, snapshot;
var trace, calls, identities, mutable, first, second, before, error, observed, update;
var plotSnapshot, plotData, constantData, foldedData, empty;

check = { |condition, message|
	if (condition.not) { Error(message).throw };
};
checkNear = { |actualValue, expected, message, tolerance = 0.000001|
	check.((actualValue - expected).abs <= tolerance,
		message ++ " (expected %, got %)".format(expected, actualValue));
};
checkThrows = { |action, message|
	var caught = try { action.value; nil } { |caughtError| caughtError };
	check.(caught.notNil, message);
	caught;
};
makeState = {
	SwarmMath.new([100, 200], 3, 2, [
		\freq, { |e| e.freq + (e.partial * 10) + e.variation },
		\amp, { |e| (e.freq / 1000) + e.partial + (e.variation / 10) }
	]);
};

try {
	state = makeState.();
	actual = state.get(\freq, 0);
	check.(actual == [[100, 110, 120], [101, 111, 121]],
		"get did not preserve variation-by-partial shape for frequency 0");
	actual = state.get(\freq, 1);
	check.(actual == [[200, 210, 220], [201, 211, 221]],
		"get did not use the selected base-frequency block");
	state = SwarmMath.new([100], 3, 1, [
		\freq, { |e| e.freq + (e.partial * 10) }
	]);
	check.(state.get(\freq, 0) == [[100, 110, 120]],
		"get changed its single-variation channel shape");

	state = makeState.();
	snapshot = state.snapshot([\freq, \amp]);
	check.(snapshot.size == 12, "snapshot did not include all 12 nodes");
	snapshot.do { |record, index|
		check.(record[\index] == index, "snapshot index order changed at %".format(index));
		check.(record[\freqIndex] == (index / 6).floor,
			"snapshot freqIndex changed at %".format(index));
		check.(record[\partial] == ((index / 2).floor % 3),
			"snapshot partial changed at %".format(index));
		check.(record[\variation] == (index % 2),
			"snapshot variation changed at %".format(index));
		check.(record[\values].isKindOf(Dictionary),
			"snapshot values are not a Dictionary at %".format(index));
	};
	check.(snapshot[6][\values][\freq] == 200,
		"snapshot second-frequency values are misindexed");

	trace = List.new;
	calls = IdentityDictionary.new;
	identities = Dictionary.new;
	state = SwarmMath.new([100], 2, 2, [
		\zeta, { |e|
			trace.add([e.i, \zeta]);
			calls[\zeta] = (calls[\zeta] ? 0) + 1;
			identities[[e.i, \zeta]] = e.identityHash;
			e.i + 30;
		},
		\alpha, { |e|
			trace.add([e.i, \alpha]);
			calls[\alpha] = (calls[\alpha] ? 0) + 1;
			identities[[e.i, \alpha]] = e.identityHash;
			e.i + 10;
		},
		\middle, { |e|
			trace.add([e.i, \middle]);
			calls[\middle] = (calls[\middle] ? 0) + 1;
			identities[[e.i, \middle]] = e.identityHash;
			e.i + 20;
		}
	]);
	state.snapshot;
	check.(trace.asArray == (0..3).collect { |i|
		[[i, \alpha], [i, \middle], [i, \zeta]]
	}.flatten(1), "default snapshot parameters were not evaluated alphabetically");
	check.(calls[\alpha] == 4 and: { calls[\middle] == 4 and: { calls[\zeta] == 4 } },
		"default snapshot did not evaluate each value exactly once");
	(0..3).do { |i|
		check.(identities[[i, \alpha]] == identities[[i, \middle]]
			and: { identities[[i, \middle]] == identities[[i, \zeta]] },
			"snapshot did not share one SwarmEvent at node %".format(i));
	};
	trace.clear;
	state.snapshot([\zeta, \alpha, \zeta]);
	check.(trace.asArray == (0..3).collect { |i| [[i, \zeta], [i, \alpha]] }.flatten(1),
		"explicit snapshot parameter order/deduplication changed");
	observed = nil;
	state = SwarmMath.new([100], 1, 1, [
		\mutate, { |e| e.partial = 99; \mutated },
		\observe, { |e| observed = e.partial; e.partial }
	]);
	snapshot = state.snapshot([\mutate, \observe]);
	check.(snapshot[0][\partial] == 0,
		"snapshot callback mutation changed canonical record metadata");
	check.(observed == 99 and: { snapshot[0][\values][\observe] == 99 },
		"snapshot callbacks did not receive the same mutable SwarmEvent");

	mutable = [1, [2]];
	state = SwarmMath.new([100], 1, 1, [\payload, { mutable }]);
	snapshot = state.snapshot([\payload]);
	mutable[0] = 99;
	mutable[1][0] = 88;
	check.(snapshot[0][\values][\payload] == [1, [2]],
		"snapshot retained mutable evaluated data");

	state = SwarmMath.new([100], 2, 1, [\random, { 1.0.rand }]);
	first = state.snapshot([\random], 8128).collect { |record| record[\values][\random] };
	second = state.snapshot([\random], 8128).collect { |record| record[\values][\random] };
	check.(first == second, "seeded snapshots are not reproducible");
	thisThread.randSeed = 24680;
	before = thisThread.randData.copy;
	state.snapshot([\random], 1234);
	check.(thisThread.randData == before, "snapshot did not restore random state after success");
	state = SwarmMath.new([100], 1, 1, [\bad, { Error("snapshot probe").throw }]);
	thisThread.randSeed = 13579;
	before = thisThread.randData.copy;
	checkThrows.({ state.snapshot([\bad], 1234) }, "snapshot did not propagate evaluation error");
	check.(thisThread.randData == before, "snapshot did not restore random state after error");

	plotSnapshot = [
		(index: 0, freqIndex: 0, partial: 0, variation: 0, values: (freq: 200, amp: 2)),
		(index: 1, freqIndex: 0, partial: 0, variation: 1, values: (freq: 100, amp: 3)),
		(index: 2, freqIndex: 0, partial: 1, variation: 0, values: (freq: 100, amp: 4)),
		(index: 3, freqIndex: 0, partial: 1, variation: 1, values: (freq: -5, amp: 5)),
		(index: 4, freqIndex: 1, partial: 0, variation: 0, values: (freq: 999, amp: 9))
	];
	plotData = makeState.().plotData(plotSnapshot, 0);
	check.(plotData[\domain] == [-5, 100, 100, 200],
		"plotData did not stably sort selected records and preserve duplicates");
	check.(plotData[\variations] == [0, 1], "plotData variation channels changed");
	check.(plotData[\values] == [[0, 0, 4, 2], [5, 3, 0, 0]],
		"plotData did not preserve frequency/amplitude pairs with zero-filled channels");
	check.(plotData[\domainSpec].warp.isKindOf(LinearWarp),
		"plotData used a logarithmic axis with nonpositive frequencies");
	check.(plotData[\folded] == false, "plotData incorrectly marked raw data as folded");
	plotData = makeState.().plotData(plotSnapshot, 0, 1);
	check.(plotData[\domain] == [-5, 100]
		and: { plotData[\variations] == [1] }
		and: { plotData[\values] == [[5, 3]] },
		"plotData explicit variation selection changed");
	constantData = makeState.().plotData([
		(index: 0, freqIndex: 0, partial: 0, variation: 0, values: (freq: 100, amp: 1))
	], 0);
	check.(constantData[\domain] == [100], "constant plot data was changed");
	check.(constantData[\domainSpec].minval < 100
		and: { constantData[\domainSpec].maxval > 100 },
		"constant plot range was not expanded");
	check.(constantData[\domainSpec].warp.isKindOf(ExponentialWarp),
		"positive-only plotData did not use a logarithmic axis");
	plotData = makeState.().plotData([
		(index: 0, freqIndex: 0, partial: 0, variation: 0, values: (freq: 0, amp: 1))
	], 0);
	check.(plotData[\domain] == [0], "zero-only plotData changed its domain value");
	check.(plotData[\domainSpec].minval < 0
		and: { plotData[\domainSpec].maxval > 0 }
		and: { plotData[\domainSpec].warp.isKindOf(LinearWarp) },
		"zero-only plotData did not receive a padded linear range");
	foldedData = makeState.().plotData([
		(index: 0, freqIndex: 0, partial: 0, variation: 0, values: (freq: 30000, amp: 1))
	], 0, nil, 48000, true);
	check.(foldedData[\domain] == [18000], "folded plotData frequency changed");
	check.(foldedData[\folded] == true, "folded plotData was not labelled folded");
	checkThrows.({ makeState.().plotData(plotSnapshot, 0, nil, nil, true) },
		"folded plotData accepted a missing sample rate");
	state = makeState.();
	snapshot = state.snapshot([\freq, \amp]);
	plotData = state.plotData(snapshot, 0);
	state.freqs[0] = 9999;
	state.args[\freq] = { 7777 };
	check.(state.plotData(snapshot, 0)[\domain] == plotData[\domain]
		and: { state.plotData(snapshot, 0)[\values] == plotData[\values] },
		"plotData re-evaluated state instead of using the supplied snapshot");

	empty = SwarmMath.new([], 0, 0, [\freq, 100, \amp, 1]);
	check.(empty.snapshot.isEmpty, "empty state snapshot is not empty");
	check.(empty.get(\freq, 0) == [], "empty state get did not return empty channels");
	plotData = empty.plotData;
	check.(plotData[\domain].isEmpty and: { plotData[\values].isEmpty }
		and: { plotData[\label] == "no data" },
		"empty plotData did not report empty data");
	error = checkThrows.({ empty.plot }, "empty plot did not reject missing data");
	check.(error.errorString.toLower.contains("no data"),
		"empty plot error did not explain that there is no data");
	empty = SwarmMath.new([100], 0, 2, [\freq, 100, \amp, 1]);
	check.(empty.snapshot.isEmpty, "zero-partials snapshot is not empty");
	check.(empty.get(\freq, 0) == [[], []],
		"zero-partials get did not preserve variation channels");
	empty = SwarmMath.new([100], 3, 0, [\freq, 100, \amp, 1]);
	check.(empty.snapshot.isEmpty, "zero-variations snapshot is not empty");
	check.(empty.get(\freq, 0) == [], "zero-variations get is not empty");
	empty = SwarmMath.new([], 3, 2, [\freq, 100, \amp, 1]);
	check.(empty.snapshot.isEmpty, "empty-frequencies snapshot is not empty");
	check.(empty.get(\freq, 0) == [[], []],
		"empty-frequencies get did not preserve variation channels");

	checkThrows.({ SwarmMath.new([100], -1, 1) }, "negative partial count was accepted");
	checkThrows.({ SwarmMath.new([100], 1.5, 1) }, "fractional partial count was accepted");
	checkThrows.({ SwarmMath.new([100], 1, -1) }, "negative variation count was accepted");
	checkThrows.({ SwarmMath.new([100], 1, 1.5) }, "fractional variation count was accepted");
	checkThrows.({ SwarmMath.new(100, 1, 1) }, "non-collection frequencies were accepted");
	state = makeState.();
	checkThrows.({ state.get(\freq, -1) }, "negative frequency index was accepted");
	checkThrows.({ state.get(\freq, 2) }, "out-of-range frequency index was accepted");
	checkThrows.({ state.val(-1, \freq) }, "val accepted a negative event index");
	checkThrows.({ state.val(state.size, \freq) }, "val accepted an out-of-range event index");
	checkThrows.({ state.calc(-1) }, "calc accepted a negative event index");
	checkThrows.({ state.calc(state.size) }, "calc accepted an out-of-range event index");
	first = [state.partials, state.variations, state.freqs.copy];
	checkThrows.({ state.putEvent((partials: 1.5)) }, "putEvent accepted fractional partials");
	check.([state.partials, state.variations, state.freqs] == first,
		"rejected putEvent partially mutated the state");
	checkThrows.({ state.putEvent((freq: 330), 2) }, "putEvent accepted invalid frequency index");
	check.([state.partials, state.variations, state.freqs] == first,
		"invalid-index putEvent partially mutated the state");
	state = makeState.();
	update = (freq: 330, amp: 0.5, phase: 0.25);
	state.putEvent(update, 0);
	check.(update[\freq] == 330 and: { update[\amp] == 0.5 },
		"putEvent stopped preserving a literal Event after asDict conversion");
	check.(update[\phase] == 0.25,
		"valid putEvent consumed an unrelated key from the original Event");
	check.(state.freqs[0] == 330 and: { state.vol == 0.5 }
		and: { state.args[\phase] == 0.25 },
		"valid putEvent did not apply Event values");
	update = IdentityDictionary.newFrom([\freq, 440, \amp, 0.6, \phase, 0.3]);
	state.putEvent(update, 0);
	check.(update[\freq].isNil and: { update[\amp].isNil },
		"putEvent stopped consuming frequency/amplitude keys from an IdentityDictionary");
	check.(update[\phase] == 0.3,
		"putEvent consumed an unrelated IdentityDictionary key");
	check.(state.freqs[0] == 440 and: { state.vol == 0.6 }
		and: { state.args[\phase] == 0.3 },
		"valid putEvent did not apply IdentityDictionary values");
	state.partials = 1.5;
	checkThrows.({ state.snapshot }, "snapshot accepted a mutated fractional partial count");
	state.partials = first[0];
	state.variations = -1;
	checkThrows.({ state.get(\freq, 0) }, "get accepted a mutated negative variation count");
	state.variations = first[1];
	state.freqs = 100;
	checkThrows.({ state.calc(0) }, "calc accepted mutated non-collection frequencies");

	checkThrows.({ SwarmMath.foldFrequency(100, nil) }, "missing sample rate was accepted");
	checkThrows.({ SwarmMath.foldFrequency(100, "48000") }, "nonnumeric sample rate was accepted");
	checkThrows.({ SwarmMath.foldFrequency(100, 0) }, "zero sample rate was accepted");
	checkThrows.({ SwarmMath.foldFrequency(100, -48000) }, "negative sample rate was accepted");
	checkThrows.({ SwarmMath.foldFrequency(100, inf) }, "infinite sample rate was accepted");
	checkThrows.({ SwarmMath.foldFrequency(100, 0.0 / 0.0) }, "NaN sample rate was accepted");
	SynthDef(\swarmmathFoldUGenContract, {
		ReplaceOut.kr(0, SwarmMath.foldFrequency(30000, SampleRate.ir));
	});

	checkNear.(SwarmMath.freqPartial((freq: 100, partial: 2), 1, 2, 0, 1), 900,
		"freqPartial 100 Hz / partial 2 / power 2 contract changed");
	checkNear.(SwarmMath.freqPartial((freq: 80, partial: 1), 2, 3, 1, 0.5),
		80 * ((0.5 + ((1 + 1).abs * 2)) ** 3),
		"freqPartial offset/power contract changed");
	checkNear.(SwarmMath.freqPartial((freq: 50, partial: -3), 0.5, 1.5, -1, 2),
		50 * ((2 + ((-3 - 1).abs * 0.5)) ** 1.5),
		"freqPartial negative-partial contract changed");

	"PASS: SwarmMath indexing, snapshots, plotting data, formula, and validation".postln;
	0.exit;
} { |caught|
	caught.reportError;
	1.exit;
};
)
