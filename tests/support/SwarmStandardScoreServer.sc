// Capture real SwarmInstrument/SwarmSynth OSC at explicit score times.
// No packets are sent to a live server.
SwarmStandardScoreServer : Server {
	var <events, <>scoreTime = 0.01;

	startCapture { events = List.new; ^this }

	sendMsg { |... message|
		if (events.notNil) { events.add([scoreTime, message]) };
		^this;
	}

	sendBundle { |time ... messages|
		messages.do { |message| this.sendMsg(*message) };
		^this;
	}
}
