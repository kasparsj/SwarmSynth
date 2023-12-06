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

Tdef(\drone_up, {
	animatePartials.(30, ~droneState.partials, 50, ~droneState, ~droneSynth, 0.3);
	1.wait;
	~droneState.variations = 1;
	~droneSynth.rampTo(~droneState, 0.3);
});
)