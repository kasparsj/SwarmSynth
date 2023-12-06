SwarmSynth {
    var <>synthDef, <>defaultParams, <>synths, <>params, <>rampRoutine;

    *new { |synthDef, defaultParams|
		^super.newCopyArgs(synthDef, defaultParams, [], []);
    }

	parseParams { |i, params, j|
		if (params.isFunction) {
			^params.(i, this.params[i], j);
		} {
			^if (params.notNil, params, []);
		}
	}

	mergePairs { |p1, p2|
		var dict = Dictionary.newFrom(p1 ?? []);
		(p2 ?? []).pairsDo { |key, value|
			dict.put(key, value);
		};
		^dict.asPairs;
	}

	mergeParams { |params, from=nil, to=nil|
		var merged;
		if (from.isNil) {
			from = 0;
			to = this.size-1;
		};
		if (to.isNil) {
			merged = this.mergePairs(this.params[from], this.parseParams(from, params, 0));

		} {
			var mergedParams = Array.newClear(to-from+1);
			(from..to).do { |i, j|
				mergedParams[j] = this.mergePairs(this.params[i], this.parseParams(i, params, j));
			};
			merged = { |i, p, j|
				mergedParams[j];
			};
		};
		^merged;
	}

	mapPairs { |start, end, progress, curve=\exp|
		var in = Dictionary.newFrom(start);
		var out = Dictionary.new;
		(end ?? []).pairsDo { |key, value|
			var func = ("lin" ++ curve.asString).asSymbol;
			var def = if (curve == \exp, value, 0);
			var v = progress.perform(func, 0, 1, in[key] ?? def, value);
			if (v.isNaN) {
				v = value;
			};
			out.put(key, v);
		};
		^out.asPairs;
	}

	mapParams { |startParams, endParams, progress, curve=\exp, from=nil, to=nil|
		var mapped;
		if (from.isNil) {
			from = 0;
			to = this.size-1;
		};
		if (to.isNil) {
			mapped = this.mapPairs(startParams[from], endParams, progress, curve);

		} {
			var mappedParams = Array.newClear(to-from+1);
			(from..to).do { |i, j|
				mappedParams[j] = this.mapPairs(startParams[i], endParams.value(i, params, j), progress, curve);
			};
			mapped = { |i, p, j|
				mappedParams[j];
			};
		};
		^mapped;
	}

	prResizeSynths { |i|
		var size = synths.size;
		if (i >= size) {
			synths = synths.addAll(Array.fill(i+1-size, nil));
		};
	}

	prResizeParams { |i|
		var size = params.size;
		if (i >= size) {
			params = params.addAll(Array.fill(i+1-size, nil));
		};
	}

    prCreateSynth { |i, pairs|
		var dict, synth, merged;
		dict = pairs.asDict;
		synth = dict.removeAt(\instrument) ?? synthDef;
		merged = this.mergePairs(params[i], dict.asPairs);
		this.prClose(i);
		this.prResizeParams(i);
		params[i] = merged;
		this.prResizeSynths(i);
		synths[i] = Synth(synthDef, merged);
		// synths[i] = Synth.basicNew(synth);
		NodeWatcher.register(synths[i]);
		// ^synths[i].newMsg(nil, merged);
		^nil;
    }

	prUpdateSynth { |i, pairs|
		this.prResizeParams(i);
		this.params[i] = this.mergePairs(this.params[i], pairs);
		synths[i].set(*pairs);
		// todo: bundle has issues with late and size
		// ^synths[i].setMsg(*pairs);
		^nil;
	}

	prSet { |i, params, j=0, createNew=true, fadeTime=nil|
		var parsed;
		^if (synths[i].isNil or: { synths[i].isPlaying.not }) {
			if (createNew) {
				parsed = this.mergePairs(this.parseParams(i, this.defaultParams, j), this.parseParams(i, params, j));
				if (fadeTime.notNil) {
					parsed = this.mergePairs(parsed, [\fadeTime, fadeTime]);
				};
				this.prCreateSynth(i, parsed);
			} {
				nil;
			}
		} {
			parsed = this.parseParams(i, params, j);
			this.prUpdateSynth(i, parsed);
		};
	}

	size {
		^synths.size;
	}

	add { |params, num=1, at=nil|
		if (at.isNil) {
			at = this.size;
		};
		num.do { |i|
			this.set(params, (at + i));
		};
	}

	prResize { |params, to, fadeTime=nil|
		if (to > (this.size-1)) {
			var toCreate = to;
			to = this.size-1;
			// make sure from/to won't be replaced
			if (params.isKindOf(SwarmMath)) {
				var m = params;
				params = { |i, p, j| m.calc(i) };
			};
			this.set(params, this.size, toCreate, createNew: true, fadeTime: fadeTime);
		} {
			to = this.prShrink(to, fadeTime);
		};
		^to;
	}

	prShrink { |to, fadeTime=nil|
		if (to < (this.size-1)) {
			this.closeGate(to+1, this.size-1, fadeTime);
			^(this.size-1);
		};
		^to;
	}

    set { |params, from=nil, to=nil, createNew=true, fadeTime=nil|
		var bundle, parsed, msg;
		if (params.isKindOf(SwarmMath)) {
			var m = params;
			from = 0;
			to = m.size-1;
			to = this.prShrink(to, fadeTime);
			params = { |i, p, j| m.calc(i) };
		};
		if (from.isNil) {
			from = 0;
			to = this.size-1;
		};
		bundle = OSCBundle.new;
		if (to.isNil) {
			msg = this.prSet(from, params, 0, createNew: createNew, fadeTime: fadeTime);
			if (msg.notNil) {
				bundle.add(msg);
			};
		} {
			(from..to).do { |i, j|
				msg = this.prSet(i, params, j, createNew: createNew, fadeTime: fadeTime);
				if (msg.notNil) {
					bundle.add(msg);
				};
			};
		};
		// bundle.messages.postln;
		//Server.default.sendBundle(Server.default.latency, bundle);
		//bundle.schedSend(nil, TempoClock.default, 1);
		// Server.default.addr.sendClumpedBundles(Server.default.latency, *bundle.messages);
		// todo: fix error bundle too long
		bundle.send;
	}

	xset { |params, from=nil, to=nil, fadeTime=nil|
		var mergedParams;
		if (params.isKindOf(SwarmMath)) {
			var m = params;
			from = 0;
			to = m.size-1;
			to = this.prShrink(to, fadeTime);
			params = { |i, p, j| m.calc(i) };
		};
		mergedParams = this.mergeParams(params, from, to);
		this.closeGate(from, to);
		this.set(mergedParams, from, to, fadeTime: fadeTime);
	}

	rampTo { |params, duration=1, curve = \exp, from=nil, to=nil, excludeParams=nil|
		var startParams, mergedParams;
		if (params.isKindOf(SwarmMath)) {
			var m = params;
			from = 0;
			to = m.size-1;
			to = this.prResize(params, to, duration);
			params = { |i, p, j| m.calc(i, nil, (excludeParams ?? [\phase, \pan])) };
		};
		startParams = this.params.copy;
		mergedParams = this.mergeParams(params, from, to);
		if (rampRoutine.notNil) {
			rampRoutine.stop;
		};
		rampRoutine = {
			var startTime = thisThread.seconds;
			block {|break|
				inf.do {
					var time = thisThread.seconds;
					var delta = time - startTime;
					if (delta >= duration) {
						this.set(params, from, to);
						break.value;
					} {
						var progress = delta / duration;
						var rampParams = this.mapParams(startParams, mergedParams, progress, curve, from, to);
						this.set(rampParams, from, to);
					};
					(1.0/30.0).wait;
				};
			};
		}.fork;
	}

	linRampTo { |params, duration, from=nil, to=nil, excludeParams=nil|
		this.rampTo(params, duration, \lin, from, to, excludeParams);
	}

	expRampTo { |params, duration, from=nil, to=nil, excludeParams=nil|
		this.rampTo(params, duration, \exp, from, to, excludeParams);
	}

	fadeIn { |amp=1, from=nil, to=nil|
		this.set([\amp, amp], from, to, createNew: false);
	}

	fadeOut { |from=nil, to=nil|
		this.set([\amp, 0], from, to, createNew: false);
	}

	prClose { |i|
		if (i >= 0 and: { i < this.size }) {
			if (synths[i].notNil) {
				NodeWatcher.unregister(synths[i]);
			};
			synths[i] = nil;
			params[i] = nil;
		};
	}

    closeGate { |from=nil, to=nil, fadeTime=nil|
		var params = [\gate, 0];
		if (fadeTime.notNil) {
			params = params.addAll([\fadeTime, fadeTime]);
		};
		this.set(params, from, to, createNew: false);
		if (from.isNil) {
			from = 0;
			to = this.size-1;
		};
		// release will happen automatically after fadeTime
		if (to.isNil) {
			this.prClose(from);
		} {
			(from..to).do { |i, j|
				this.prClose(i);
			};
		};
		this.prCleanUp;
    }

	prRelease { |i|
		if (i >= 0 and: { i < this.size }) {
			synths[i].free;
			this.prClose(i);
		}
	}

	release { |from=nil, to=nil|
		if (from.isNil) {
			from = 0;
			to = this.size-1;
		};
		if (to.isNil) {
			this.prRelease(from);
		} {
			(from..to).do { |i|
				this.prRelease(i);
			};
		};
		this.prCleanUp;
	}

	prRemove { |i|
		synths.removeAt(i);
		params.removeAt(i);
	}

	prCleanUp {
		var i = this.size - 1;
		while ({ i >= 0 and: { synths[i].isNil } }) {
			this.prRemove(i);
			i = i - 1;
		};
	}

	removeNil {
		var i = this.size - 1;
		while ({ i >= 0 }) {
			if (synths[i].isNil) {
				this.prRemove(i);
			};
			i = i - 1;
		};
	}

	asString {
        ^params.asString;
	}

	param { |key|
		^params.collect { |sp|
			if (sp.notNil) {
				Dictionary.newFrom(sp)[key];
			};
		};
	}
}

/* additive synth example
(
SynthDef(\harmonic, {|out=0, freq=440, detune=0.3, lfo=0.1, fadeTime=1, gate=1, amp=1|
	var amp2 = amp, detune2 = detune, freq2 = freq, phase, sig, pan, lfo2 = lfo, env;
	env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
	lfo2 = LFNoise0.kr(lfo2, 1.0);
	amp2 = LFNoise1.kr(lfo2, amp2);
	amp2 = LFNoise1.kr(lfo2, amp2);
	detune2 = LFNoise1.kr(lfo2, detune2).bipolar.midiratio;
	freq2 = freq2 * detune2;
	phase = LFNoise1.kr(lfo2).range(-2pi, 2pi);
	sig = SinOsc.ar(freq2, phase, amp2);
	sig = HPF.ar(sig, 100);
	sig = RLPF.ar(sig, 10000, 50);
	pan = LFNoise1.kr(lfo2).range(-1, 1);
	sig = Pan2.ar(sig, pan);
	Out.ar(0, sig * env);
}).add;
)
(
var root = 36.midicps;
var harmonics = 10;
harmonics.do { |i|
	var bf = 20;
	bf.do { |j|
		var freq, amp, phase, pan;
		freq = root * ((1+i*0.75)**2)+exprand(0.1, 2);
		amp = 1/(i+1)*0.1;
		phase = rrand(-2pi, 2pi);
		pan = rrand(-1, 1);
		~swarm.xset({[freq: freq, amp: amp, phase: phase, pan: pan]}, i*bf+j);
	};
}
)
*/