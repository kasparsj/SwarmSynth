SwarmPlaybackTestState {
	var <events, <values;

	*new { ^super.new.init }

	init {
		events = List.new;
		values = IdentityDictionary.new;
		^this;
	}

	putEvent { |event|
		var normalized = event.asDict;
		events.add(normalized.deepCopy);
		values.putAll(normalized);
		^this;
	}
}

SwarmPlaybackTestSynth {
	var <sets, <closedGates = 0, <resets = 0, <releases = 0, <disposals = 0;
	var <cancelledRamps = 0, <isPlaying = false;

	*new { ^super.new.init }

	init {
		sets = List.new;
		^this;
	}

	set { |state, from, to, createNew=true, fadeTime, defer=0, excludeParams|
		sets.add((state: state, excludeParams: excludeParams,
			createNew: createNew, fadeTime: fadeTime));
		isPlaying = true;
		^this;
	}

	closeGate {
		closedGates = closedGates + 1;
		isPlaying = false;
		^this;
	}

	reset { resets = resets + 1; isPlaying = false; ^this }
	release { releases = releases + 1; isPlaying = false; ^this }
	dispose { disposals = disposals + 1; isPlaying = false; ^this }
	cancelRamp { cancelledRamps = cancelledRamps + 1; ^this }
}
