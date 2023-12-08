(

~reverbBus = Bus.audio(s,2);
~miverbBus = Bus.audio(s,2);
~delayBus = Bus.audio(s,2);
~delayBps = TempoClock.default.tempo;

Ndef(\reverb, { |out=0, dec=4, lpf=1500, mix=1.0|
	var sig;
	sig = (In.ar(~reverbBus, 2) * mix).sum;
	sig = DelayN.ar(sig, 0.03, 0.03);
	sig = CombN.ar(sig, 0.1, {Rand(0.01,0.099)}!32, dec);
	sig = SplayAz.ar(2, sig);
	sig = LPF.ar(sig, lpf);
	5.do{sig = AllpassN.ar(sig, 0.1, {Rand(0.01,0.099)}!2, 3)};
	sig = LPF.ar(sig, lpf);
	sig = LeakDC.ar(sig);
	Out.ar(out, sig);
}).play;

Ndef(\miverb, { |out=0, time=0.7, drywet=0.5, amp=1.0|
	var sig;
	sig = In.ar(~miverbBus, 2);
	sig = MiVerb.ar(sig, time, drywet);
	Out.ar(out, sig * amp);
}).play;

Ndef(\delay, {
	var src = In.ar(~delayBus,2);
	var loc = LocalIn.ar(2)+src;
	loc = DelayC.ar(loc,1/~delayBps*2,LFNoise0.ar(~delayBps).range(0.125,1).round(0.25)/~delayBps);
	loc = FreqShift.ar(loc,LFNoise1.ar(3/~delayBps).range(-15,15));
	loc = loc+(loc ring4: WhiteNoise.ar(1*LFNoise1.ar(0.25)));

	LocalOut.ar(loc*0.5);
	Balance2.ar(loc[0], loc[1], SinOsc.ar(2))
}).play;

)

// NdefGui.new(Ndef(\miverb))
