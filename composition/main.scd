(
s.waitForBoot {
	"config.scd".loadRelative;

	"synths/*.scd".loadRelative;
	"fx/*.scd".loadRelative;

	s.sync;

	"swarm.scd".loadRelative;
	"pdefs.scd".loadRelative;

	"swarm loaded".postln;
};
)

(
RedMst.clear;
//RedMst.clock = TempoClock(60/60);
RedMst.quant = 1;

RedTrk2(\drone, RedVol(RedFn({
	if (~droneSynth.isPlaying) {
		~droneSynth.rampTo(~droneState, 0.3);
	} {
		~droneSynth.xset(~droneState);
	};
}, {
	~droneSynth.closeGate;
}), { |vol|
	~droneState.vol = vol;
	if (~droneSynth.isPlaying) {
		~droneSynth.rampTo(~droneState, 1/60);
	};
}, ~droneState.vol));

RedTrk2(\drone_up, RedFn({
	Tdef(\drone_up, {
		// change partials from 1 to 50
		var duration = 30;
		var startValue = ~droneState.partials;
		var startTime = thisThread.seconds;
		var delta = 0;
		var progress = 0;
		while ({ progress < 1 }) {
			var value = progress.linexp(0, 1, startValue, 50).floor;
			if (~droneState.partials < value) {
				~droneState.partials = value;
				~droneState.partials.postln;
				~droneSynth.rampTo(~droneState, 0.3);
			};
			0.5.wait;
			delta = thisThread.seconds - startTime;
			progress = delta / duration;
		};
		~droneState.variations = 1;
		~droneSynth.rampTo(~droneState, 0.3);
	}).play;
}, {
	Tdef(\drone_up).stop;
}));

RedTrk2(\drone_restore, RedFn({
	~droneState.partials = 12;
	~droneState.variations = 7;
	~droneSynth.rampTo(~droneState, 0.3);
}, {

}));

RedTrk2(\laser_random, RedVol(Pdef(\laser_random), { |vol|
	~laserState.vol = vol;
}, ~laserState.vol));

RedTrk2(\voice_tenor_random, RedVol(Pdef(\voice_tenor_random), { |vol|
	~tenorState.vol = vol;
}, ~tenorState.vol));

~score = RedScore([
	inf, [\drone],
	inf, [\drone, \drone_up],
	inf, [\drone, \drone_restore],
	inf, [\laser_random, \drone],
	inf, [\laser_random, \voice_tenor_random, \drone],
]);

// todo: use RedSeq instead
~video = VideoOSC(NetAddr("127.0.0.1", 133333));
~sound = SoundTrack(~video, ~score.beats, \beats);
)

~sound.play(loop: false);
~sound.nextSection;
~sound.stop;

~master.gui;

RedMstGUI4()