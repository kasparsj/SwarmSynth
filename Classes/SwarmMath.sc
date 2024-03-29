SwarmMath {
	var <>freqs, <>partials, <>variations, <>args, <>vol;

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

	*new { |freqs, partials=0, variations=1, args=#[], vol=1|
		^super.newCopyArgs(freqs, partials, variations, Dictionary.newFrom(args.asPairs), vol);
	}

	size {
		^(freqs.size * partials * variations);
	}

	val { |i, param, event=nil|
		^args[param].(event ?? { SwarmEvent.new(i, this) });
	}

	calc { |i, params=nil, excludeParams=nil|
		var event = SwarmEvent.new(i, this), result = [];
		((params ?? args.keys).asSet -- (excludeParams ? []).asSet).do { |param|
			if (args[param].notNil) {
				result = result.addAll([param, this.val(i, param, event)]);
			};
		};
		^result;
	}

	get { |param|
		^{ |i| { |j| this.val(i*partials + j, param); }.dup(partials); }.dup(variations);
	}

	putEvent { |event, freqIndex=nil|
		event = event.asDict;
		if (event[\partials].notNil) {
			partials = event[\partials];
		};
		if (event[\variations].notNil) {
			variations = event[\variations];
		};
		if (args[\amp].isFunction and: { event[\amp].notNil }) {
			vol = event[\amp];
			event.removeAt(\amp);
		};
		if (args[\freq].isFunction) {
			if (event[\freqs].notNil) {
				freqs = event[\freqs];
				event.removeAt(\freqs);
			};
			if (event[\freq].notNil) {
				freqs[freqIndex ? 0] = event[\freq];
				event.removeAt(\freq);
			};
		};
		args.putAll(event);
		if (event.respondsTo(\use) and: { freqIndex.notNil }) {
			event.use { freqs[freqIndex] = ~freq.value };
		};
	}

	plot { |name, bounds, discrete=false, variation=nil|
		// todo: plot variations inside one graph, but using different colors
		var freqs, amps, order, plt;
		freqs = this.get(\freq)[variation ? 0];
		amps = this.get(\amp);
		order = freqs.order;
		amps = if (variation.notNil) {
			amps = amps[variation];
			amps.collect({ |v, i| amps[order[i]] });
		} {
			// multi-channel
			amps.collect { |v, i|
				v.collect({ |v2, i2| v[order[i2]] });
			};
		};
		plt = amps.plot(name, bounds, discrete);
		plt.domain = freqs.sort;
		plt.domainSpecs = [freqs.minItem, freqs.maxItem, \exp].asSpec;
		plt.plotMode = \plines;
		^plt;
	}
}

SwarmEvent {
	var <i, <n, <>freq, <freqs, <>partial, <>partial1, <partials, <variation, <variations, <size;
	var <f, <p, <ps, <p1, <v, <vs, <sz, <nf, <nf, <np, <nv, <vol;

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
	}
}