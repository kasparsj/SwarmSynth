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
