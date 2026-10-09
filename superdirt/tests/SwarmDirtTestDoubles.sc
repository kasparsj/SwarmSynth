SwarmDirtTestLibrary {
    var sounds, <synthEvents;

    *new { ^super.new.init }

    init {
        sounds = IdentityDictionary.new;
        synthEvents = IdentityDictionary.new;
        ^this;
    }

    at { |name| ^sounds[name] }

    addSynth { |name, event|
        sounds[name] = event;
        synthEvents[name] = List[event];
    }

    freeSynths { |name|
        sounds.removeAt(name);
        synthEvents.removeAt(name);
    }
}

SwarmDirtTestDirt {
    var <numChannels, <soundLibrary;

    *new { |channels=2, library|
        ^super.newCopyArgs(channels, library ? SwarmDirtTestLibrary.new);
    }
}

// NRT capture variant that preserves Server.makeBundle's relative delay.
SwarmDirtRenderServer : Server {
    var <events, <>scoreTime = 0.01;

    startCapture { events = List.new; ^this }

    sendMsg { |... message|
        if (events.notNil) { events.add([scoreTime, message]) };
        ^this;
    }

    sendBundle { |time ... messages|
        messages.do { |message| events.add([scoreTime + time, message]) };
        ^this;
    }
}
