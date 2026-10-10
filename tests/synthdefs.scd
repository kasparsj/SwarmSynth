(
var root = PathName(thisProcess.nowExecutingPath).pathOnly.dirname;
var project = "PAGRABS_PROJECT".getenv;
var check, compare, expected, aliases;

check = { |condition, message| if (condition.not) { Error(message).throw } };

try {
	(root +/+ "tests/fixtures/legacy-sine-synthdefs.scd").load;

	check.(Server.default.serverRunning.not, "SynthDef test began with a running server");
	[
		[\swarmPartialProbe, { SwarmSynthDefs.partial(\swarmPartialProbe) }],
		[\swarmSustainedProbe, { SwarmSynthDefs.sustained(\swarmSustainedProbe) }],
		[\swarmPadProbe, { SwarmSynthDefs.pad(\swarmPadProbe) }],
		[\swarmChipProbe, { SwarmSynthDefs.chip(\swarmChipProbe) }],
		[\swarmKickProbe, { SwarmSynthDefs.kick(\swarmKickProbe) }]
	].do { |entry|
		check.(SynthDescLib.global.at(entry[0]).isNil,
			"Builder probe % was already registered".format(entry[0]));
		entry[1].value;
		check.(SynthDescLib.global.at(entry[0]).isNil,
			"Builder registered %".format(entry[0]));
	};
	check.(Server.default.serverRunning.not, "A builder booted the default server");

	compare = { |label, legacy, current|
		check.(legacy.asBytes == current.asBytes,
			"% graph or control contract differs from frozen Pagrabs source".format(label));
	};
	compare.("partial", ~legacySineSynthDefs[\partial].value(\samePartial),
		SwarmSynthDefs.partial(\samePartial));
	compare.("sustained", ~legacySineSynthDefs[\sustained].value(\sameSustained),
		SwarmSynthDefs.sustained(\sameSustained));
	compare.("sustained gate-first", ~legacySineSynthDefs[\sustained].value(\sameDrone, true),
		SwarmSynthDefs.sustained(\sameDrone, true));
	compare.("pad", ~legacySineSynthDefs[\pad].value(\samePad),
		SwarmSynthDefs.pad(\samePad));
	compare.("chip", ~legacySineSynthDefs[\chip].value(\sameChip),
		SwarmSynthDefs.chip(\sameChip));

	SwarmSynthDefs.install;
	[\swarm_partial, \swarm_sustained, \swarm_pad, \swarm_chip, \swarm_kick].do { |name|
		check.(SynthDescLib.global.at(name).notNil,
			"install omitted canonical %".format(name));
	};
	SwarmSynthDefs.sustained(\swarm_test_drone, true).add;
	check.(Server.default.serverRunning.not, "install booted the default server");

	expected = (
		swarm_partial: [\out, \freq, \amp, \phase, \pan, \attack, \decay,
			\sustain, \release, \gate, \nyquistMode],
		swarm_sustained: [\out, \freq, \amp, \fadeTime, \gate, \pan, \panf,
			\detune, \detunef, \phase, \phasef, \pulse, \pulsef, \pulsew,
			\saw, \sawf, \mod, \modf, \foldNyquist, \nyquistMode],
		swarm_test_drone: [\out, \freq, \gate, \amp, \fadeTime, \pan, \panf,
			\detune, \detunef, \phase, \phasef, \pulse, \pulsef, \pulsew,
			\saw, \sawf, \mod, \modf, \foldNyquist, \nyquistMode],
		swarm_pad: [\out, \freq, \amp, \duration, \pan, \panf, \detune,
			\detunef, \phase, \phasef, \pulse, \pulsef, \pulsew, \saw,
			\sawf, \mod, \modf, \foldNyquist, \nyquistMode],
		swarm_chip: [\out, \freq, \detune, \duration, \amp, \pan, \phase,
			\foldNyquist, \nyquistMode],
		swarm_kick: [\out, \freq, \amp, \duration, \pan, \attack, \detune,
			\sweepRatio, \sweepTime, \drive, \nyquistMode, \decayScale,
			\attackScale, \detuneOffset, \sweepRatioScale, \sweepTimeScale]
	);
	expected.keysValuesDo { |name, names|
		var actual = SynthDescLib.global.at(name).controls.collect(_.name);
		check.(actual == names, "% control order changed: %".format(name, actual));
	};

	if (project.notNil) {
		if (PathName(project).isFolder.not) {
			Error("PAGRABS_PROJECT does not name a repository").throw;
		};
		(project +/+ "synths/additive.scd").load;
		(project +/+ "synths/drones.scd").load;
		(project +/+ "synths/perc.scd").load;
		aliases = [
			[\swarm_partial, \partial, false],
			[\swarm_bass, \sustained, false],
			[\swarm_bass2, \sustained, false],
			[\swarm_vocalBass, \sustained, false],
			[\drone, \sustained, true],
			[\swarm_pad, \pad, false],
			[\swarm_pad2, \pad, false],
			[\swarm_chip, \chip, false]
		];
		aliases.do { |entry|
			var actual = SynthDescLib.global.at(entry[0]);
			var baseline = if (entry[1] == \sustained) {
				~legacySineSynthDefs[entry[1]].value(entry[0], entry[2])
			} {
				~legacySineSynthDefs[entry[1]].value(entry[0])
			};
			check.(actual.notNil, "Project alias % did not register".format(entry[0]));
			check.(actual.def.asBytes == baseline.asBytes,
				"Project alias % differs from frozen graph".format(entry[0]));
		};
	};

	"PASS: SwarmSynthDefs frozen graphs, controls, inert builders, install, and optional aliases".postln;
	0.exit;
} { |error|
	error.reportError;
	1.exit;
};
)
