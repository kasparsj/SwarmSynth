(
SynthDef(\droneSynth, { |out=0, freq=440, amp=0.5, fadeTime=2, gate=1|
	var env, sig;
	// env = EnvGen.kr(Env.linen(fadeTime, 1e6, fadeTime), gate, doneAction: 2);
    env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
	sig = SinOsc.ar(freq) * amp * env;
	Out.ar(out, sig);
}).add;
)

~swarm = SwarmSynth.new(\droneSynth, [\fadeTime, 10]);
~swarm.set([\freq, 220], 0);
~swarm.set([\freq, 880], 1);
~swarm.release(1);
~swarm.closeGate(0);
~swarm.size;
~swarm.removeNil;
~swarm.release;
