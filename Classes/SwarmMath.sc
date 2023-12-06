SwarmMath {
	var <>freqs, <>partials, <>variations, <>args;

	*freqPartial { |e, mul=1, pow=1, offset=0, add=1|
		^(e.freq * (add+((e.partial+offset).abs*mul)**pow));
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

	*new { |freqs, partials=0, variations=1, args|
		^super.newCopyArgs(freqs, partials, variations, Dictionary.newFrom(args.asPairs));
	}

	size {
		^(freqs.size * partials * variations);
	}

	calc { |i, params=nil, excludeParams=nil|
		var event = (), result = [];
		event.n = (i / (partials * variations)).floor;
		event.freq = freqs[event.n];
		event.freqs = freqs;
		event.partial = (i / variations).floor % partials;
		event.partial1 = event.partial + 1;
		event.partials = partials;
		event.variation = i % variations;
		event.variations = variations;
		event.f = event.freq;
		event.p = event.partial;
		event.ps = event.partials;
		event.p1 = event.p + 1;
		event.v = event.variation;
		event.vs = event.variations;
		event.sz = this.size; // can't call it size
		event.nf = freqs.size;
		event.np = event.partials;
		event.nv = event.variations;
		((params ?? args.keys).asSet -- (excludeParams ?? []).asSet).do { |param|
			if (args[param].notNil) {
				result = result.addAll([param, args[param].(event)]);
			};
		};
		^result;
	}
}
