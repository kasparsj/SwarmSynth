// Optional lifecycle-owner regression. Loads no StochasticSequencer classes.
(
var check, state, variants, registry, environment, makeAudition, makeOwner;
var audition, facade, factoryCalls = 0, factorySawInertRoot = false;
var run, lifecycle, synth, child, error, reports = List.new, beforeDispose;

check = { |condition, message| if(condition.not) { Error(message).throw } };
state = SwarmMath.new([110], 1, 1, (
	ratio: { |event| event.p1 }, freq: { |event| event.freq },
	amp: { |event| event.vol }, phase: { 0 }, pan: { 0 }, out: 0
), 0.1);
variants = (plain: (args: state.args.deepCopy, partials: 1, variations: 1));
environment = Environment.new;
environment.put(\ownerState, state);
environment.put(\ownerSynth, Object.new);
registry = SwarmInstrumentRegistry.new;
registry.register(\ownerVoice, { |lookup|
	(synth: lookup[\ownerSynth], state: lookup[\ownerState])
}, (
	synthDef: \swarm_owner_test, variant: \plain,
	defaultParams: [\release, 0.01], hasGate: true, liveSwitch: \sustained
), variants, (
	auditionGate: true, auditionParams: [\release, 0.01], releaseTime: 0.01
));

makeOwner = { |controller, ownedRun, failCleanup=false|
	SwarmAuditionRunOwnerDouble.new(
		{
			// Passing the captured run makes late callbacks harmless after replacement.
			controller[\stopAudition].value(controller, ownedRun);
		},
		{ |caught|
			if(controller.run.isNil or: { controller.run === ownedRun }) {
				reports.add(caught.what);
				controller[\notify].value(controller, caught.errorString);
			};
		},
		failCleanup
	)
};

makeAudition = { |failCleanup=false, phrase=nil|
	environment.use {
		SwarmAudition.new(registry, (
			captureContext: { (routes: (dry: 0)) },
			variantSettings: { |variant| (variant: variant, duration: 0.02, gap: 0.02) },
			phrase: phrase,
			runOwner: { |controller, ownedRun|
				factoryCalls = factoryCalls + 1;
				factorySawInertRoot = ownedRun[\routine].notNil
					and: { ownedRun[\routine].isPlaying.not };
				makeOwner.(controller, ownedRun, failCleanup)
			}
		))
	}
};

try {
	check.(SwarmAudition.supportsRunOwner, "SwarmAudition did not advertise runOwner support");
	audition = makeAudition.();
	facade = audition.facade;
	check.(factoryCalls == 0, "Construction invoked the runOwner factory");
	audition.capture;
	facade[\ready] = { true };
	facade[\makeSynth] = { SwarmAuditionRecordingSynth.new };
	audition.update(\mode, \repeat);

	Routine {
		try {
			audition.start;
			run = facade.run;
			lifecycle = run[\owner];
			synth = run[\synth];
			check.(factoryCalls == 1 and: { factorySawInertRoot },
				"runOwner was not created after an inert root Routine");
			check.(run[\children] === lifecycle.children,
				"Legacy run children did not alias owner children");
			0.08.wait;
			check.(lifecycle.runs == 1, "Owner did not wrap root execution");
			child = lifecycle.fork({ 20.wait }, run[\clock]);
			check.(run[\children].includes(child), "Owner child was not visible through the run");
			audition.stopAudition;
			check.(facade.run.isNil and: { lifecycle.cleanups == 1 }
				and: { child.isPlaying.not } and: { synth.disposals == 1 },
				"Owner stop did not release child, synth, clock ownership, and run state once");
			audition.stopAudition;
			check.(lifecycle.cleanups == 1 and: { synth.disposals == 1 },
				"Repeated stop repeated owner or synth cleanup");

			// A callback captured by a retired owner cannot stop its replacement.
			audition.start;
			run = facade.run;
			audition.stopAudition;
			audition.start;
			lifecycle = facade.run[\owner];
			facade[\stopAudition].value(facade, run);
			check.(facade.run.notNil and: { facade.run[\owner] === lifecycle },
				"Retired run callback stopped its replacement");
			audition.stopAudition;

			// Child failure stops the whole owner and publishes the original error once.
			reports.clear;
			audition.start;
			run = facade.run;
			lifecycle = run[\owner];
			lifecycle.fork({ Error("owner child failed").throw }, run[\clock]);
			0.08.wait;
			check.(reports.asArray == ["owner child failed"],
				"Child owner error was not reported exactly once");
			check.(facade.run.isNil and: { lifecycle.children.isEmpty },
				"Child owner error left the audition or children active");

			// Owner cleanup failure is reported after all audition resources are released.
			audition.dispose;
			audition = makeAudition.(true);
			facade = audition.facade;
			audition.capture;
			facade[\ready] = { true };
			facade[\makeSynth] = { SwarmAuditionRecordingSynth.new };
			audition.update(\mode, \repeat);
			audition.start;
			run = facade.run;
			synth = run[\synth];
			beforeDispose = CmdPeriod.objects.size;
			error = try { audition.dispose; nil } { |caught| caught };
			check.(error.notNil and: { error.what.contains("owner cleanup failed") },
				"Owner cleanup error did not propagate");
			check.(facade.run.isNil and: { run[\active].not }
				and: { synth.disposals == 1 }
				and: { CmdPeriod.objects.size == (beforeDispose - 1) }
				and: { facade[\onStatus].isNil and: { facade[\onPartials].isNil } },
				"Owner cleanup error left audition resources active");

			// Root failures are published once, after the owner tears down the run.
			reports.clear;
			audition = makeAudition.(false, {
				Error("owner root failed").throw
			});
			facade = audition.facade;
			audition.capture;
			facade[\ready] = { true };
			facade[\makeSynth] = { SwarmAuditionRecordingSynth.new };
			audition.update(\mode, \phrase);
			audition.start;
			0.08.wait;
			check.(reports.asArray == ["owner root failed"],
				"Root owner error was not reported exactly once");
			check.(facade.run.isNil, "Root owner error left the audition active");

			audition.dispose;
			registry.dispose;
			"PASS: optional SwarmAudition run owner lifecycle".postln;
			0.exit;
		} { |caught|
			caught.reportError;
			try { audition.dispose };
			1.exit;
		};
	}.play(AppClock);
} { |caught|
	caught.reportError;
	try { audition !? { |item| item.dispose } };
	1.exit;
};
)
