SwarmAuditionRecordingSynth {
	var <sets, <closedGates = 0, <releases = 0, <disposals = 0;
	var <params, <isPlaying = false, <>rampRoutine;

	*new { ^super.new.init }

	init {
		sets = List.new;
		params = [];
		^this
	}

	prMergePairs { |first, second|
		var merged = Dictionary.newFrom(first ? []);
		(second ? []).pairsDo { |key, value| merged[key] = value };
		^merged.asPairs
	}

	setSampled { |sampled, fadeTime, excludeParams, createNew=true|
		var targetSize = sampled.size;
		sets.add((sampled: sampled.deepCopy, fadeTime: fadeTime,
			excludeParams: excludeParams, createNew: createNew));
		if (targetSize < params.size) {
			params = if (targetSize == 0) { [] } { params.copyRange(0, targetSize - 1) };
		};
		sampled.do { |pairs, index|
			var previous = params[index], filtered;
			if (previous.notNil) {
				filtered = pairs.asDict.reject { |value, key|
					(excludeParams ? []).includes(key)
				}.asPairs;
				params[index] = this.prMergePairs(previous, filtered);
			} {
				if (createNew) {
					while { params.size <= index } { params = params.add(nil) };
					params[index] = pairs.deepCopy;
				};
			};
		};
		isPlaying = params.notEmpty;
		^this
	}

	closeGate {
		closedGates = closedGates + 1;
		params = [];
		isPlaying = false;
		^this
	}

	release {
		releases = releases + 1;
		params = [];
		isPlaying = false;
		^this
	}

	dispose {
		disposals = disposals + 1;
		this.release;
		^this
	}
}

// Lifecycle owner used to prove SwarmAudition's optional protocol without
// loading StochasticSequencer or any other quark.
SwarmAuditionRunOwnerDouble {
	var <children, <active = true, <runs = 0, <forks = 0, <cleanups = 0;
	var onCleanup, onError, failCleanup;

	*new { |onCleanup=nil, onError=nil, failCleanup=false|
		^super.newCopyArgs(nil, true, 0, 0, 0, onCleanup, onError, failCleanup).init
	}

	init {
		children = IdentitySet.new;
		^this
	}

	run { |function|
		runs = runs + 1;
		try {
			function.value;
			this.cleanup;
		} { |error|
			this.cleanup;
			if(onError.notNil) { onError.value(error, this) } { error.throw };
		};
		^this
	}

	fork { |function, clock|
		var child;
		if(active.not) { ^nil };
		forks = forks + 1;
		child = Routine {
			try {
				function.value;
				children.remove(child);
			} { |error|
				children.remove(child);
				this.cleanup;
				if(onError.notNil) { onError.value(error, this) } { error.throw };
			};
		};
		children.add(child);
		child.play(clock ? thisThread.clock);
		^child
	}

	cleanup {
		if(active) {
			active = false;
			cleanups = cleanups + 1;
			children.copy.do { |child|
				if(child !== thisThread and: { child !== thisThread.threadPlayer }) {
					child.stop;
				};
			};
			children.clear;
			onCleanup !? { |action| action.value(this) };
			if(failCleanup) { Error("owner cleanup failed").throw };
		};
		^this
	}
}
