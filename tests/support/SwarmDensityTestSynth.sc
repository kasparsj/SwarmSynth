SwarmDensityTestSynth {
	var <ramps, <times;

	*new { ^super.new.init }

	init {
		ramps = List.new;
		times = List.new;
		^this
	}

	rampTo { |state, duration|
		ramps.add((
			partials: state.partials,
			variations: state.variations,
			duration: duration
		));
		times.add(Main.elapsedTime);
		^this
	}
}
