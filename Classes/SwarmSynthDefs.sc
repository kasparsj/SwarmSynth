SwarmSynthDefs {
	*partial { |name|
		^SynthDef(name, { |out=0, freq=440, amp=0.1, phase=0, pan=0,
			attack=0.01, decay=1, sustain=0, release=0.1, gate=1, nyquistMode=0|
			var transientEnv, gatedEnv, zeroSustain, env, done, sig, policy;
			zeroSustain = sustain <= 0;
			transientEnv = EnvGen.kr(Env([0, 1, 0], [attack, decay], [-4, -4]));
			gatedEnv = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate);
			env = Select.kr(zeroSustain, [gatedEnv, transientEnv]);
			done = Select.kr(zeroSustain, [Done.kr(gatedEnv), Done.kr(transientEnv)]);
			FreeSelf.kr(done);
			policy = SwarmMath.frequencyPolicy(freq, SampleRate.ir, nyquistMode);
			sig = SinOsc.ar(policy[0], phase, amp * policy[1]) * env;
			Out.ar(out, Pan2.ar(sig, pan));
		});
	}

	*sustained { |name, gateBeforeAmp=false|
		if (gateBeforeAmp) {
			^SynthDef(name, { |out=0, freq=440, gate=1, amp=1, fadeTime=1,
				pan=0, panf=0, detune=0, detunef=(1/30), phase=0, phasef=0,
				pulse=0, pulsef=0.1, pulsew=0.5, saw=0, sawf=0.1,
				mod=0, modf=(1/11), foldNyquist=0, nyquistMode=(-1)|
				this.prSustainedGraph(out, freq, amp, fadeTime, gate, pan, panf,
					detune, detunef, phase, phasef, pulse, pulsef, pulsew,
					saw, sawf, mod, modf, foldNyquist, nyquistMode);
			});
		};
		^SynthDef(name, { |out=0, freq=440, amp=1, fadeTime=1, gate=1,
			pan=0, panf=0, detune=0, detunef=(1/30), phase=0, phasef=0,
			pulse=0, pulsef=0.1, pulsew=0.5, saw=0, sawf=0.1,
			mod=0, modf=(1/11), foldNyquist=0, nyquistMode=(-1)|
			this.prSustainedGraph(out, freq, amp, fadeTime, gate, pan, panf,
				detune, detunef, phase, phasef, pulse, pulsef, pulsew,
				saw, sawf, mod, modf, foldNyquist, nyquistMode);
		});
	}

	*prSustainedGraph { |out, freq, amp, fadeTime, gate, pan, panf,
		detune, detunef, phase, phasef, pulse, pulsef, pulsew,
		saw, sawf, mod, modf, foldNyquist, nyquistMode|
		var sig, env, mode, policy;
		env = EnvGen.kr(Env.adsr(fadeTime, 0.001, 1, fadeTime), gate, doneAction: 2);
		amp = (amp * (1.0 - pulse) + (pulse * LFPulse.kr(pulsef, Rand(), pulsew, amp)));
		amp = (amp * (1.0 - saw) + (saw * LFSaw.kr(sawf, Rand(0, 2.0), amp)));
		amp = ((1.0 - mod.sign) + (SinOsc.kr(modf).range(mod, 1) * mod.sign)) * amp;
		detune = (detune * (1.0 - detunef.sign)) + (LFNoise0.kr(detunef, detune) * detunef.sign);
		freq = freq + (detune * freq);
		phase = (phase * (1.0 - phasef.sign)) + (LFNoise1.kr(phasef).range(-2pi, 2pi) * phasef.sign);
		mode = Select.kr(nyquistMode < 0, [nyquistMode, foldNyquist > 0]);
		policy = SwarmMath.frequencyPolicy(freq, SampleRate.ir, mode);
		freq = policy[0];
		amp = amp * policy[1];
		sig = SinOsc.ar(freq, phase, amp);
		pan = (pan * (1.0 - panf.sign)) + (LFNoise1.kr(panf).range(-1.0, 1.0) * panf.sign);
		sig = Pan2.ar(sig, pan);
		^Out.ar(out, sig * env);
	}

	*pad { |name|
		^SynthDef(name, { |out=0, freq=440, amp=1, duration=1,
			pan=0, panf=0, detune=0, detunef=(1/30), phase=0, phasef=0,
			pulse=0, pulsef=0.1, pulsew=0.5, saw=0, sawf=0.1,
			mod=0, modf=(1/11), foldNyquist=0, nyquistMode=(-1)|
			var sig, env, mode, policy;
			env = Env.linen(0.1, duration, 0.01, curve: -4).ar(Done.freeSelf);
			detune = (detune * (1.0 - detunef.sign)) + (LFNoise0.kr(detunef, detune) * detunef.sign);
			freq = freq + (detune * freq);
			mode = Select.kr(nyquistMode < 0, [nyquistMode, foldNyquist > 0]);
			policy = SwarmMath.frequencyPolicy(freq, SampleRate.ir, mode);
			freq = policy[0];
			amp = amp * policy[1];
			sig = SinOsc.ar(freq, phase, amp);
			sig = Pan2.ar(sig, pan);
			Out.ar(out, sig * env);
		});
	}

	*chip { |name|
		^SynthDef(name, { |out=0, freq=440, detune=0, duration=1,
			amp=1, pan=0, phase=0, foldNyquist=1, nyquistMode=(-1)|
			var env, sig, mode, policy;
			env = Env.linen(0.0, duration, 0.0).ar(Done.freeSelf);
			freq = freq + (detune * freq);
			mode = Select.kr(nyquistMode < 0, [nyquistMode, foldNyquist > 0]);
			policy = SwarmMath.frequencyPolicy(freq, SampleRate.ir, mode);
			freq = policy[0];
			amp = amp * policy[1];
			sig = SinOsc.ar(freq, phase, amp);
			sig = Pan2.ar(sig, pan);
			Out.ar(out, sig * env);
		});
	}

	*kick { |name|
		^SynthDef(name, { |out=0, freq=55, amp=0.1, duration=0.4, pan=0,
			attack=0.002, detune=0, sweepRatio=3.5, sweepTime=0.045,
			drive=1, nyquistMode=2, decayScale=1, attackScale=1,
			detuneOffset=0, sweepRatioScale=1, sweepTimeScale=1|
			var safeDuration, safeAttack, safeSweepTime, tuned, swept;
			var policy, env, sig, safeDrive;
			safeDuration = (duration * decayScale.clip(0.01, 4)).clip(0.002, 240);
			safeAttack = (attack * attackScale.clip(0.05, 20))
				.clip(0.0001, safeDuration - 0.0001);
			safeSweepTime = (sweepTime * sweepTimeScale.clip(0.01, 8))
				.clip(0.0001, safeDuration);
			tuned = (freq * (1 + (detune + detuneOffset).clip(-0.99, 4))).max(0.001);
			swept = XLine.kr(
				(tuned * (sweepRatio * sweepRatioScale).clip(0.01, 32)).max(0.001),
				tuned,
				safeSweepTime
			);
			policy = SwarmMath.frequencyPolicy(swept, SampleRate.ir, nyquistMode);
			env = EnvGen.kr(
				Env.perc(safeAttack, (safeDuration - safeAttack).max(0.0001), curve: -5),
				doneAction: 2
			);
			safeDrive = drive.clip(0.1, 20);
			sig = SinOsc.ar(policy[0], 0, amp * policy[1]);
			sig = (sig * safeDrive).tanh / safeDrive.sqrt;
			Out.ar(out, Pan2.ar(sig * env, pan.clip(-1, 1)));
		});
	}

	*install {
		this.partial(\swarm_partial).add;
		this.sustained(\swarm_sustained).add;
		this.pad(\swarm_pad).add;
		this.chip(\swarm_chip).add;
		this.kick(\swarm_kick).add;
		^this;
	}
}
