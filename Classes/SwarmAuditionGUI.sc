SwarmAuditionGUI {
	var <controller, <options;

	*new { |controller, options| ^super.new.init(controller, options) }

	init { |aController, someOptions|
		controller = aController;
		options = someOptions ? ();
		^this
	}

	open {
		var facade = controller, owner = controller[\owner] ? currentEnvironment, generation;
		generation = (facade[\guiOpenGeneration] ? 0) + 1;
		facade[\guiOpenGeneration] = generation;
	AppClock.sched(0, {
	if (facade[\disposed].not and: { facade[\guiOpenGeneration] == generation }) {
		var window, root, scroll, descriptorPane, statusText, countText, extraControlsView;
		var instrumentMenu, variantMenu, modeMenu, routeMenu, nyquistMenu, ratioMenu, ampMenu;
		var partialView, partialStatus, partialInspector, partialNote, axisMenu, displayMenu, baseMenu, variationMenu;
		var pitchField, durationBox, gapBox, tempoBox, levelBox, partialsBox, variationsBox;
		var ratioPowerBox, stiffnessBox, ampPowerBox, ampSlopeBox;
		var playButton, stopButton, resetButton, refreshButton, extension, extensionHandles = ();
		var refreshAll, refreshStatus, refreshCount, refreshPartials, rebuildDescriptors, currentSettings;
		var closeCleanup;
		var safe, invoke, updateFrequencies, parseFrequencies, setMenu, formatName, makeNumberRow, makeDescriptorRow;
		var partialData, partialPoints = #[], hoverRecord, baseChoices = [nil], variationChoices = [nil];
		var partialAxis = \frequency, partialDisplay = \generated, partialBase, partialVariation;
		var modes, modeLabels, routes, routeLabels, variants, variantLabels;
		var nyquistValues = [-1, 0, 1, 2, 3];
		var ratioModes = [\original, \harmonic, \odd, \power, \stiffString];
		var ampModes = [\original, \power, \exponential];
		var closing = false;

		if (facade[\window].notNil) { facade[\window].close };
		if (facade[\context].isNil) { owner.use { facade[\capture].value(facade) } };

		formatName = options[\formatName] ? { |value|
			var metadata = if (facade[\registry].notNil
				and: { facade[\names].includes(value) }) {
				facade[\registry].metadata(value)
			};
			if(metadata.notNil) { metadata[\label] ? value.asString } { value.asString };
		};
		variants = if (facade[\variantChoices].notNil) {
			facade[\variantChoices].value(facade)
		} { options[\variantChoices] ? [\original] };
		variantLabels = if (facade[\variantLabels].notNil) {
			facade[\variantLabels].value(facade)
		} { options[\variantLabels] ? variants.collect(formatName) };
		modes = options[\modes] ? [\single, \repeat];
		if ((facade[\options] ? options)[\phrase].notNil and: { modes.includes(\phrase).not }) {
			modes = modes ++ [\phrase];
		};
		modeLabels = options[\modeLabels] ? modes.collect(formatName);
		routes = options[\routeChoices]
			? (facade[\context][\routes].keys.asArray.sort ? [\dry]);
		routeLabels = options[\routeLabels] ? routes.collect(formatName);

		currentSettings = {
			facade[\settings][facade[\selected]];
		};

		refreshStatus = { |message|
			var text = message ? facade[\status] ? "Ready";
			if (statusText.notNil and: { statusText.isClosed.not }) {
				statusText.string_(text.asString);
			};
		};

		refreshCount = {
			var count = 0;
			if (facade[\nodeCount].notNil) {
				count = facade[\nodeCount].value(facade);
			};
			if (countText.notNil and: { countText.isClosed.not }) {
				countText.string_("Oscillator nodes: " ++ count.asString ++ " / "
					++ (facade[\nodeLimit] ? 2048).asString);
			};
		};

		safe = { |function|
			var succeeded = true;
			try {
				owner.use(function);
			} { |error|
				succeeded = false;
				refreshStatus.("Error: " ++ error.errorString);
			};
			refreshCount.();
			succeeded;
		};

		invoke = { |method, key, value|
			safe.({ facade[method].value(facade, key, value) });
		};
		parseFrequencies = { |text|
			var expression = "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$";
			var tokens = text.split($,);
			if (tokens.isEmpty) { Error("Enter one or more frequencies in Hz.").throw };
			tokens.collect { |raw|
				var token = raw.stripWhiteSpace;
				if (token.isEmpty or: { token.findRegexp(expression).isEmpty }) {
					Error("Invalid frequency: '" ++ raw ++ "'. Use comma-separated Hz values.").throw;
				};
				token.asFloat;
			};
		};
		updateFrequencies = { |field|
			var succeeded = safe.({
				facade[\update].value(facade, \freqs, parseFrequencies.(field.string));
			});
			if (succeeded.not) {
				field.string_(currentSettings.()[\freqs].collect(_.asString).join(", "));
			};
			succeeded;
		};

		setMenu = { |menu, values, value|
			var index = values.indexOf(value);
			menu.value_(index ? 0);
		};

		makeNumberRow = { |label, key, minimum, maximum, step=0.01, integer=false|
			var box = NumberBox().clipLo_(minimum).clipHi_(maximum).step_(step);
			box.decimals_(if (integer) { 0 } { 4 });
			box.action_({ |view|
				var value = if (integer) { view.value.asInteger } { view.value };
				if (invoke.(\update, key, value).not) {
					view.value_(currentSettings.()[key]);
				};
			});
			[HLayout(StaticText().string_(label).fixedWidth_(170), box), box];
		};

		makeDescriptorRow = { |descriptor|
			var key = descriptor[\key];
			var minimum = descriptor[\min];
			var maximum = descriptor[\max];
			var warp = descriptor[\warp] ? \lin;
			var default = descriptor[\default];
			var overrides = currentSettings.()[\overrides];
			var overridden = overrides.notNil and: { overrides.includesKey(key) };
			var functionDefault = default.isKindOf(Function);
			var initial = if (overridden) {
				overrides[key]
			} {
				if (functionDefault) { (minimum + maximum) * 0.5 } { default }
			};
			var spec = ControlSpec(minimum, maximum, warp);
			var slider = Slider().orientation_(\horizontal).value_(spec.unmap(initial.clip(minimum, maximum)));
			var valueLabel = StaticText().fixedWidth_(155);
			var title = descriptor[\label] ? formatName.(key);

			if (functionDefault and: { overridden.not }) {
				valueLabel.string_("Function (move to set)");
			} {
				valueLabel.string_(initial.round(0.0001).asString);
			};
			slider.action_({ |view|
				var value = spec.map(view.value);
				valueLabel.string_(value.round(0.0001).asString);
				invoke.(\control, key, value);
			});
			HLayout(
				StaticText().string_(title).fixedWidth_(170),
				slider,
				valueLabel
			);
		};

		window = Window(options[\title] ? "Swarm instrument audition", Rect(90, 40, 820, 760));
		facade[\window] = window;

		instrumentMenu = PopUpMenu().items_(facade[\names].collect(formatName));
		instrumentMenu.action_({ |view|
			if (safe.({ facade[\select].value(facade, facade[\names][view.value]) }).not) {
				view.value_(facade[\names].indexOf(facade[\selected]) ? 0);
			};
			refreshAll.();
		});

		variantMenu = PopUpMenu().items_(variantLabels);
		variantMenu.action_({ |view|
			if (invoke.(\update, \variant, variants[view.value]).not) {
				setMenu.(view, variants, currentSettings.()[\variant]);
			};
			refreshAll.();
		});
		modeMenu = PopUpMenu().items_(modeLabels);
		modeMenu.action_({ |view|
			if (invoke.(\update, \mode, modes[view.value]).not) { setMenu.(view, modes, currentSettings.()[\mode]) };
		});
		routeMenu = PopUpMenu().items_(routeLabels);
		routeMenu.action_({ |view|
			if (invoke.(\update, \route, routes[view.value]).not) { setMenu.(view, routes, currentSettings.()[\route]) };
		});
		nyquistMenu = PopUpMenu().items_(["Inherit", "None", "Fold", "Mute", "Taper"]);
		nyquistMenu.action_({ |view|
			if (invoke.(\update, \nyquistMode, nyquistValues[view.value]).not) { setMenu.(view, nyquistValues, currentSettings.()[\nyquistMode]) };
		});
		ratioMenu = PopUpMenu().items_(["Variant default", "Harmonic", "Odd", "Power", "Stiff string"]);
		ratioMenu.action_({ |view|
			if (invoke.(\update, \ratioMode, ratioModes[view.value]).not) { setMenu.(view, ratioModes, currentSettings.()[\ratioMode]) };
		});
		ampMenu = PopUpMenu().items_(["Variant default", "Power", "Exponential"]);
		ampMenu.action_({ |view|
			if (invoke.(\update, \ampMode, ampModes[view.value]).not) { setMenu.(view, ampModes, currentSettings.()[\ampMode]) };
		});

		pitchField = TextField().action_({ |view| updateFrequencies.(view) });
		durationBox = makeNumberRow.("Duration (seconds)", \duration, 0.05, 60, 0.05)[1];
		gapBox = makeNumberRow.("Repeat gap (seconds)", \gap, 0.02, 60, 0.05)[1];
		tempoBox = makeNumberRow.("Tempo (beats / second)", \tempo, 0.1, 8, 0.05)[1];
		levelBox = makeNumberRow.("Level (relative)", \level, 0, 2, 0.01)[1];
		partialsBox = makeNumberRow.("Partials", \partials, 1, facade[\nodeLimit] ? 2048, 1, true)[1];
		variationsBox = makeNumberRow.("Variations", \variations, 1, facade[\nodeLimit] ? 2048, 1, true)[1];
		ratioPowerBox = makeNumberRow.("Ratio power", \ratioPower, 0.1, 4, 0.05)[1];
		stiffnessBox = makeNumberRow.("String stiffness", \stiffness, 0, 0.1, 0.0001)[1];
		ampPowerBox = makeNumberRow.("Amplitude power", \ampPower, 0, 4, 0.05)[1];
		ampSlopeBox = makeNumberRow.("Exponential slope", \ampSlope, 0, 2, 0.01)[1];

		statusText = StaticText().string_("Ready").stringColor_(Color(0.16, 0.45, 0.2));
		countText = StaticText().string_("Oscillator nodes: 0 / " ++ (facade[\nodeLimit] ? 2048).asString);
		partialStatus = StaticText().string_("Partials: waiting for preview");
		partialInspector = StaticText().string_("Hover a stem for captured oscillator details")
			.fixedHeight_(34);
		partialNote = StaticText()
			.string_("Generated-input estimate: envelopes, modulation, filters, feedback, and distortion can change the audible spectrum.")
			.fixedHeight_(20);
		axisMenu = PopUpMenu().items_(["Frequency", "Partial number"]);
		displayMenu = PopUpMenu().items_(["Generated", "Policy estimate"]);
		baseMenu = PopUpMenu().items_(["All base frequencies"]);
		variationMenu = PopUpMenu().items_(["All variations"]);
		partialView = UserView().fixedHeight_(240).background_(Color(0.975, 0.975, 0.98));

		refreshPartials = { |capture|
			var source = capture ? facade[\partialCapture], normalized = false;
			hoverRecord = nil;
			partialInspector.string_("Hover a stem for captured oscillator details");
			if (source.isNil) {
				partialData = nil; partialPoints = #[]; hoverRecord = nil;
				partialStatus.string_("Partials: waiting for preview");
			} {
				try {
					partialData = SwarmPartialPlotData.fromCapture(source, partialAxis,
						partialDisplay, partialBase, partialVariation);
					baseChoices = [nil] ++ partialData[\baseIndices];
					variationChoices = [nil] ++ partialData[\variations];
					if (baseChoices.includes(partialBase).not) {
						partialBase = nil; normalized = true;
					};
					if (variationChoices.includes(partialVariation).not) {
						partialVariation = nil; normalized = true;
					};
					if (normalized) {
						partialData = SwarmPartialPlotData.fromCapture(source, partialAxis,
							partialDisplay, partialBase, partialVariation);
					};
					baseMenu.items_(["All base frequencies"] ++ partialData[\baseIndices].collect {
						|index| "Base " ++ (index + 1)
					});
					variationMenu.items_(["All variations"] ++ partialData[\variations].collect {
						|index| "Variation " ++ (index + 1)
					});
					baseMenu.value_(baseChoices.indexOf(partialBase) ? 0);
					variationMenu.value_(variationChoices.indexOf(partialVariation) ? 0);
					partialStatus.string_(switch(partialData[\status],
						\playing, { "Playing sampled inputs — " ++ partialData[\sampleRateLabel] },
						\stopped, { "Stopped — last sampled inputs" },
						\pending, { "Changes pending next attack — showing last sampled inputs" },
						{ "Preview — " ++ partialData[\sampleRateLabel] }
					));
				} { |error|
					partialData = nil; partialPoints = #[];
					partialStatus.string_("Partial plot error: " ++ error.errorString);
				};
			};
			partialView.refresh;
		};

		axisMenu.action_({ |view|
			partialAxis = [\frequency, \partial][view.value];
			refreshPartials.();
		});
		displayMenu.action_({ |view|
			partialDisplay = [\generated, \policy][view.value];
			refreshPartials.();
		});
		baseMenu.action_({ |view|
			partialBase = baseChoices[view.value];
			refreshPartials.();
		});
		variationMenu.action_({ |view|
			partialVariation = variationChoices[view.value];
			refreshPartials.();
		});
		partialView.drawFunc_({ |view|
			var bounds = Rect(0, 0, view.bounds.width, view.bounds.height);
			var plot = Rect(52, 27, (bounds.width - 68).max(20), (bounds.height - 67).max(20));
			var xMap, xValue, yMap, palette;
			Pen.fillColor = Color(0.975, 0.975, 0.98); Pen.fillRect(bounds);
			Pen.font = Font.default.copy.size_(10);
			if (partialData.isNil or: { partialData[\empty] }) {
				Pen.fillColor = Color.gray(0.42);
				Pen.stringAtPoint("No cached partials for this selection", Point(54, 105));
			} {
				xMap = { |value|
					var normalized;
					normalized = if (partialData[\axisLog]) {
						value.max(1e-12).log.linlin(partialData[\axisMin].log,
							partialData[\axisMax].log, 0, 1)
					} {
						value.linlin(partialData[\axisMin], partialData[\axisMax], 0, 1)
					};
					plot.left + (normalized.clip(0, 1) * plot.width);
				};
				xValue = { |normalized|
					if (partialData[\axisLog]) {
						partialData[\axisMin].log.blend(partialData[\axisMax].log, normalized).exp
					} {
						partialData[\axisMin].blend(partialData[\axisMax], normalized)
					}
				};
				yMap = { |value|
					plot.bottom - (value.linlin(partialData[\amplitudeMin],
						partialData[\amplitudeMax], 0, plot.height).clip(0, plot.height));
				};
				palette = [Color(0.15, 0.43, 0.78), Color(0.88, 0.38, 0.16),
					Color(0.25, 0.62, 0.34), Color(0.55, 0.35, 0.75), Color(0.86, 0.66, 0.12)];
				Pen.strokeColor = Color.gray(0.82); Pen.width = 1;
				[-100, -80, -60, -40, -20, 0].do { |db|
					if (db <= partialData[\amplitudeMax]) {
						var y = yMap.(db);
						Pen.moveTo(Point(plot.left, y)); Pen.lineTo(Point(plot.right, y)); Pen.stroke;
						Pen.fillColor = Color.gray(0.4); Pen.stringAtPoint(db.asString, Point(13, y - 6));
					};
				};
				Pen.strokeColor = Color.gray(0.3); Pen.addRect(plot); Pen.stroke;
				5.do { |index|
					var normalized = index / 4, x = plot.left + (normalized * plot.width);
					var tick = xValue.(normalized);
					Pen.strokeColor = Color.gray(0.45);
					Pen.moveTo(Point(x, plot.bottom)); Pen.lineTo(Point(x, plot.bottom + 4)); Pen.stroke;
					Pen.fillColor = Color.gray(0.32);
					Pen.stringAtPoint(if(partialAxis == \frequency) {
						tick.round(if(tick < 100, 0.1, 1)).asString
					} { tick.round(0.1).asString }, Point(x - if(index == 0) { 0 } {
						if(index == 4) { 40 } { 13 }
					}, plot.bottom + 5));
				};
				if (partialData[\nyquistVisible]) {
					var nx = if (partialData[\nyquistSide] == \left) { plot.left } {
						if (partialData[\nyquistSide] == \right) { plot.right } {
							xMap.(partialData[\nyquist])
						}
					};
					Pen.strokeColor = Color(0.75, 0.16, 0.16, 0.75);
					Pen.moveTo(Point(nx, plot.top)); Pen.lineTo(Point(nx, plot.bottom)); Pen.stroke;
					Pen.fillColor = Color(0.65, 0.12, 0.12);
					Pen.stringAtPoint(if(partialData[\nyquistSide] == \left) { "Nyquist < range" } {
						if(partialData[\nyquistSide] == \right) { "Nyquist > range" } { "Nyquist" }
					}, Point((nx + 3).min(plot.right - 82), plot.top + 2));
				};
				partialPoints = partialData[\records].collect { |record|
					var jitter = (record[\coincidenceIndex] - ((record[\coincidenceCount] - 1) * 0.5)) * 4;
					var x = xMap.(record[\x]) + jitter, y = yMap.(record[\y]);
					var color = palette.wrapAt(record[\variation]);
					Pen.strokeColor = color; Pen.fillColor = color; Pen.width = 1.5;
					Pen.moveTo(Point(x, plot.bottom)); Pen.lineTo(Point(x, y)); Pen.stroke;
					if (record[\zero]) {
						Pen.strokeColor = Color(0.75, 0.12, 0.12); Pen.addOval(Rect(x-3, plot.bottom-6, 6, 6)); Pen.stroke;
					} {
						Pen.addOval(Rect(x-2.5, y-2.5, 5, 5)); Pen.fill;
					};
					(record: record, point: Point(x, y));
				};
				Pen.fillColor = Color.gray(0.22);
				Pen.stringAtPoint(partialData[\estimateLabel] ++ " | " ++
					(if(partialData[\axisLog]) { "log axis" } { "linear axis" }) ++
					" | Input amplitude — 1 = 0 dB", Point(plot.left, 5));
				Pen.stringAtPoint(partialData[\axisLabel] ++ " (" ++ partialData[\axisUnit] ++ ")",
					Point(plot.left + (plot.width * 0.42), plot.bottom + 20));
			};
		});
		partialView.mouseMoveAction_({ |view, x, y|
			var nearest, distance = inf;
			partialPoints.do { |item|
				var candidate = item[\point].dist(Point(x, y));
				if (candidate < distance) { distance = candidate; nearest = item[\record] };
			};
			hoverRecord = if (distance <= 12) { nearest } { nil };
			partialInspector.string_(if (hoverRecord.isNil) {
				"Hover a stem for captured oscillator details"
			} {
				"base % Hz | p% v% | ratio % | phase %\ngenerated % Hz | policy estimate % Hz | input amp % | shown % dB | %"
					.format(hoverRecord[\baseFrequency], hoverRecord[\partial],
						hoverRecord[\variation] + 1, hoverRecord[\ratio], hoverRecord[\phase],
						hoverRecord[\generatedFrequency].round(0.01),
						hoverRecord[\effectiveFrequency].round(0.01), hoverRecord[\inputAmplitude],
						hoverRecord[\amplitudeDb].round(0.1), hoverRecord[\policyLabel])
			});
			view.refresh;
		});
		descriptorPane = View();
		if (options[\extraControls].notNil) {
			extension = options[\extraControls].value(facade, { refreshAll.() });
			if (extension.isKindOf(Dictionary)) {
				extraControlsView = extension[\view];
				extensionHandles = extension[\handles] ? ();
			} { extraControlsView = extension };
		};
		extraControlsView = extraControlsView ? View().fixedHeight_(0);
		playButton = Button().states_([["Play"]]).action_({
			if (safe.({
				facade[\update].value(facade, \freqs, parseFrequencies.(pitchField.string));
				facade[\start].value(facade);
			}).not) {
				pitchField.string_(currentSettings.()[\freqs].collect(_.asString).join(", "));
			};
		});
		stopButton = Button().states_([["Stop"]]).action_({ safe.({ facade[\stopAudition].value(facade) }) });
		resetButton = Button().states_([["Reset instrument"]]).action_({
			safe.({ facade[\resetInstrument].value(facade) }); refreshAll.();
		});
		refreshButton = Button().states_([["Refresh from project"]]).action_({
			safe.({ facade[\refresh].value(facade) }); refreshAll.();
		});

		rebuildDescriptors = {
			var descriptors = facade[\descriptors].value(facade, facade[\selected]) ? #[];
			var rows = descriptors.collect(makeDescriptorRow);
			if (rows.isEmpty) {
				rows = [StaticText().string_("This instrument has no additional controls.")];
			};
			descriptorPane.removeAll;
			descriptorPane.layout_(VLayout(*rows));
		};

		refreshAll = {
			var settings = currentSettings.();
			var selectedIndex = facade[\names].indexOf(facade[\selected]);
			variants = if (facade[\variantChoices].notNil) {
				facade[\variantChoices].value(facade)
			} { options[\variantChoices] ? [\original] };
			variantLabels = if (facade[\variantLabels].notNil) {
				facade[\variantLabels].value(facade)
			} { options[\variantLabels] ? variants.collect(formatName) };
			if (variantLabels.size != variants.size) {
				Error("SwarmAuditionGUI variant labels must match variant choices").throw;
			};
			variantMenu.items_(variantLabels);
			routes = options[\routeChoices]
				? (facade[\context][\routes].keys.asArray.sort ? [\dry]);
			routeLabels = options[\routeLabels] ? routes.collect(formatName);
			if (routeLabels.size != routes.size) {
				Error("SwarmAuditionGUI route labels must match route choices").throw;
			};
			routeMenu.items_(routeLabels);
			instrumentMenu.value_(selectedIndex ? 0);
			setMenu.(variantMenu, variants, settings[\variant]);
			setMenu.(modeMenu, modes, settings[\mode]);
			setMenu.(routeMenu, routes, settings[\route]);
			setMenu.(nyquistMenu, nyquistValues, settings[\nyquistMode]);
			setMenu.(ratioMenu, ratioModes, settings[\ratioMode]);
			setMenu.(ampMenu, ampModes, settings[\ampMode]);
			pitchField.string_(settings[\freqs].collect(_.asString).join(", "));
			durationBox.value_(settings[\duration]);
			gapBox.value_(settings[\gap]);
			tempoBox.value_(settings[\tempo]);
			levelBox.value_(settings[\level]);
			partialsBox.value_(settings[\partials]);
			variationsBox.value_(settings[\variations]);
			ratioPowerBox.value_(settings[\ratioPower]);
			stiffnessBox.value_(settings[\stiffness]);
			ampPowerBox.value_(settings[\ampPower]);
			ampSlopeBox.value_(settings[\ampSlope]);
			if (extension.notNil and: { extension[\refresh].notNil }) {
				extension[\refresh].value(facade);
			};
			rebuildDescriptors.();
			refreshStatus.();
			refreshCount.();
		};

		root = VLayout(
			HLayout(StaticText().string_("Instrument").fixedWidth_(170), instrumentMenu),
			HLayout(StaticText().string_(options[\variantSelectorLabel] ? "Timbre variant").fixedWidth_(170), variantMenu),
			HLayout(StaticText().string_("Playback mode").fixedWidth_(170), modeMenu),
			HLayout(StaticText().string_("Pitch / chord (Hz, comma-separated)").fixedWidth_(260), pitchField),
			HLayout(StaticText().string_("Duration (seconds)").fixedWidth_(170), durationBox),
			HLayout(StaticText().string_("Repeat gap (seconds)").fixedWidth_(170), gapBox),
			HLayout(StaticText().string_("Tempo (beats / second)").fixedWidth_(170), tempoBox),
			HLayout(StaticText().string_("Output route").fixedWidth_(170), routeMenu),
			HLayout(
				playButton, stopButton, resetButton, refreshButton
			),
			HLayout(StaticText().string_("Status").fixedWidth_(170), statusText),
			HLayout(StaticText().string_("Partial plot").fixedWidth_(170), axisMenu, displayMenu,
				baseMenu, variationMenu),
			partialStatus,
			partialNote,
			partialView,
			partialInspector,
			HLayout(StaticText().string_("Load estimate").fixedWidth_(170), countText),
			StaticText().string_("Live: sustained timbre and spectrum.").font_(Font.default.boldVariant).fixedHeight_(20),
			StaticText().string_("Next attack: density, envelopes, and all transient-instrument changes.").fixedHeight_(20),
			HLayout(StaticText().string_("Level (relative)").fixedWidth_(170), levelBox),
			HLayout(StaticText().string_("Partials").fixedWidth_(170), partialsBox),
			HLayout(StaticText().string_("Variations").fixedWidth_(170), variationsBox),
			HLayout(StaticText().string_("Nyquist policy").fixedWidth_(170), nyquistMenu),
			StaticText().string_("Spectrum recipes (Variant default uses the selected timbre)").font_(Font.default.boldVariant),
			HLayout(StaticText().string_("Partial ratios").fixedWidth_(170), ratioMenu),
			HLayout(StaticText().string_("Ratio power").fixedWidth_(170), ratioPowerBox),
			HLayout(StaticText().string_("String stiffness").fixedWidth_(170), stiffnessBox),
			HLayout(StaticText().string_("Amplitudes").fixedWidth_(170), ampMenu),
			HLayout(StaticText().string_("Amplitude power").fixedWidth_(170), ampPowerBox),
			HLayout(StaticText().string_("Exponential slope").fixedWidth_(170), ampSlopeBox),
			extraControlsView,
			StaticText().string_("Instrument controls").font_(Font.default.boldVariant),
			descriptorPane,
			nil
		);

		scroll = ScrollView().hasHorizontalScroller_(false).hasVerticalScroller_(true);
		scroll.canvas_(View().layout_(root));
		window.layout_(VLayout(scroll));
		facade[\guiViews] = (
			instrument: instrumentMenu, variant: variantMenu, mode: modeMenu, pitch: pitchField,
			duration: durationBox, gap: gapBox, tempo: tempoBox, route: routeMenu,
			play: playButton, stop: stopButton, reset: resetButton, refresh: refreshButton,
			level: levelBox, partials: partialsBox, variations: variationsBox,
			nyquist: nyquistMenu, ratioMode: ratioMenu, ratioPower: ratioPowerBox,
			stiffness: stiffnessBox, ampMode: ampMenu, ampPower: ampPowerBox,
			ampSlope: ampSlopeBox,
			descriptors: descriptorPane, status: statusText, count: countText,
			partialView: partialView, partialStatus: partialStatus, partialInspector: partialInspector,
			partialAxis: axisMenu, partialDisplay: displayMenu,
			partialBase: baseMenu, partialVariation: variationMenu,
			refreshControls: refreshAll
		).putAll(extensionHandles);
		closeCleanup = {
			if (closing.not and: { facade[\window] === window
				and: { facade[\guiOpenGeneration] == generation } }) {
				closing = true;
				facade[\onStatus] = nil;
				facade[\onPartials] = nil;
				facade[\guiViews] = nil;
				facade[\window] = nil;
				owner.use { facade[\stopAudition].value(facade) };
			};
		};
		window.onClose_(closeCleanup);
		// Qt can close a heavily updated window without delivering its language
		// onClose callback. Keep the same idempotent ownership cleanup as a
		// fallback while this generation owns the facade window.
		AppClock.sched(0.05, {
			if (closing.not and: { facade[\window] === window
				and: { facade[\guiOpenGeneration] == generation } }) {
				if (window.isClosed) { closeCleanup.value; nil } { 0.05 }
			} { nil };
		});
		facade[\onStatus] = { |message|
			{
				if (closing.not and: { facade[\window] === window and: { window.isClosed.not } }) {
					refreshStatus.(message);
					refreshCount.();
				};
			}.defer;
		};
		facade[\onPartials] = { |capture| {
			if (closing.not and: { facade[\window] === window and: { window.isClosed.not } }) {
				refreshPartials.(capture);
			};
		}.defer };
		if (facade[\partialCapture].isNil) {
			safe.({ facade[\previewPartials].value(facade) });
		} {
			refreshPartials.(facade[\partialCapture]);
		};
		refreshAll.();
		window.front;
		nil;
	};
		nil;
	});
		^this
	}
}
