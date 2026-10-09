SwarmDensityAutomation {
	*prPositiveCount { |value, name|
		if (SwarmMath.prFiniteNumber(value).not or: {
			(value < 1) or: { value != value.asInteger }
		}) {
			Error("SwarmDensityAutomation: % must be a positive whole number".format(name)).throw;
		};
		^value.asInteger;
	}

	*run { |state, synth, key, duration, from, to, rampTime=0.3|
		var setter, startTime, delta = 0, progress = 0;

		if (key.isKindOf(Symbol).not or: { #[partials, variations].includes(key).not }) {
			Error("SwarmDensityAutomation: key must be \\partials or \\variations").throw;
		};
		from = this.prPositiveCount(from, "from");
		to = this.prPositiveCount(to, "to");
		if (SwarmMath.prFiniteNumber(duration).not or: { duration <= 0 }) {
			Error("SwarmDensityAutomation: duration must be a positive finite number").throw;
		};
		if (SwarmMath.prFiniteNumber(rampTime).not or: { rampTime < 0 }) {
			Error("SwarmDensityAutomation: rampTime must be a nonnegative finite number").throw;
		};
		this.prPositiveCount(state.perform(key), "current %".format(key));

		setter = key.asSetter;
		startTime = thisThread.seconds;
		while ({ progress < 1 }) {
			var value = progress.linexp(0, 1, from, to).floor;
			if (state.perform(key) < value) {
				state.perform(setter, value);
				synth.rampTo(state, rampTime);
				(rampTime + 0.1).wait;
			};
			0.1.wait;
			delta = thisThread.seconds - startTime;
			progress = delta / duration;
		};
	}
}
