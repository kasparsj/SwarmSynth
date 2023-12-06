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
