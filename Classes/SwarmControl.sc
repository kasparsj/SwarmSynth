SwarmControl {
	var <ndef, <numOscs, <>params;

    *new { |ndef, numOscs|
		^super.newCopyArgs(ndef, numOscs, Dictionary.new);
    }

	getPairs { |i|
		var params = [];
		this.params.keys.do { |key|
			params = params.addAll([key, this.params.at(key)[i]]);
		}
		^params;
	}

	getDict { |i|
		var dict = Dictionary.new;
		this.params.keys.do { |key|
			dict.put(key, this.params.at(key)[i]);
		}
		^dict;
	}

	parseParams { |i, params, j|
		if (params.isFunction) {
			^params.(i, this.getPairs(i), j);
		} {
			^if (params.notNil, params, []);
		}
	}

	prSetParams { |i, params|
		^params.pairsDo { |key, value|
			if (this.params[key].isNil) {
				this.params.put(key, Array.fill(numOscs, 0));
			};
			this.params.at(key)[i] = value;
		};
	}

	prSet { |params|
		params.pairsDo { |key, value|
			ndef.set(key, this.params.at(key));
		};
	}

	prXset { |params|
		params.pairsDo { |key, value|
			ndef.xset(key, this.params.at(key));
		};
	}

    set { |params, from, to|
		var parsed;
		if (from.isNil) {
			from = 0;
			to = numOscs-1;
		};
		if (to.isNil) {
			if (from < (numOscs-1)) {
				parsed = this.parseParams(from, params, 0);
				this.prSetParams(from, parsed);
			}
		} {
			(from..to.min(numOscs-1)).do { |i, j|
				parsed = this.parseParams(i, params, j);
				this.prSetParams(i, parsed);
			};
		};
		this.prSet(parsed);
    }

	xset { |params, from, to|
		var parsed;
		if (from.isNil) {
			from = 0;
			to = numOscs-1;
		};
		if (to.isNil) {
			if (from < (numOscs-1)) {
				parsed = this.parseParams(from, params, 0);
				this.prSetParams(from, parsed);
			}
		} {
			(from..to.min(numOscs-1)).do { |i, j|
				parsed = this.parseParams(i, params, j);
				this.prSetParams(i, parsed);
			};
		};
		this.prXset(parsed);
    }

	reset { |from, to|
		var dict;
		if (from.isNil) {
			from = 0;
			to = numOscs-1;
		};
		dict = this.getDict(from);
		dict.pairsDo { |key, value|
			dict.put(key, 0);
		};
		this.set(dict.asPairs, from, to);
	}

    fadeIn { |amp=1, from, to|
		if (from.isNil) {
			from = 0;
			to = numOscs-1;
		};
		this.xset([\amp, amp], from, to);
    }

    fadeOut { |from, to|
		if (from.isNil) {
			from = 0;
			to = numOscs-1;
		};
		this.xset([\amp, 0], from, to);
    }

	asString {
        ^params.asString;
	}
}

/**

this does not work as expected: (too many UGens allocated after a while) better use SwarmSynth

(
Ndef(\g100).fadeTime = 10;
Ndef(\g100, {
	var freq, amp, phase, pan, combinator, syn, set;
	freq = Control.names(\freq).kr(Array.fill(100, 0));
	amp = Control.names(\amp).kr(Array.fill(100, 0));
	phase = Control.names(\phase).kr(Array.fill(100, 0));
	pan = Control.names(\pan).kr(Array.fill(100, 0));
	combinator = { |a, b| a + b };
	syn = { |i|
		var sig;
		sig = SinOsc.ar(freq[i], phase[i]) * amp[i];
		sig = LeakDC.ar(sig);
		sig = Pan2.ar(sig, pan[i]);
		sig;
	};
	set = 100.collect { |i| syn.(i) };
	set.reduce(combinator);
}).play;
)

~root = 48.midicps;
60.midicps*50
~swarm = SwarmControl.new(Ndef(\g100), 100);
~swarm.reset();
~swarm.xset({|i, p, j| [freq: ~root*(j+1), amp: 1/(i/2.floor+1)*0.1, phase: rrand(-2pi, 2pi), pan: rrand(-1, 1)] }, 0, 50);
(
20.do { |i|
	3.do { |j|
		var freq, amp, phase, pan;
		freq = ~root*(i+1)+j;
		amp = 1/(i+1)*0.1;
		phase = rrand(-2pi, 2pi);
		pan = rrand(-1, 1);
		~swarm.xset({[freq: freq, amp: amp, phase: phase, pan: pan]}, i*3+j);
	};
}
)
**/