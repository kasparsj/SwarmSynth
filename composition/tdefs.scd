(
var animatePartials = { |duration, from, to, state, synth, rampTime|
	var startTime = thisThread.seconds;
	var delta = 0;
	var progress = 0;
	while ({ progress < 1 }) {
		var value = progress.linexp(0, 1, from, to).floor;
		if (state.partials < value) {
			state.partials = value;
			state.partials.postln;
			synth.rampTo(state, rampTime);
			(rampTime+0.1).wait;
		};
		0.1.wait;
		delta = thisThread.seconds - startTime;
		progress = delta / duration;
	};
};

Tdef(\drone_notes, {
	loop {
		var notes = [~rootHz, ~rootHz*1.5, ~rootHz*2, ~rootHz*3].select({ |v| v != ~droneState.freqs[0] });
		var note = notes.choose;
		note.postln;
		~droneState.freqs[0] = note;
		~droneSynth.xset(~droneState, fadeTime: 3);
		[1, 2, 4, 8, 16].wchoose([1, 1, 1, 8, 1].normalizeSum).wait;
	}
});

Tdef(\drone_up, {
	animatePartials.(30, ~droneState.partials, 50, ~droneState, ~droneSynth, 0.3);
	1.wait;
	~droneState.variations = 1;
	~droneSynth.rampTo(~droneState, 0.3);
});
)