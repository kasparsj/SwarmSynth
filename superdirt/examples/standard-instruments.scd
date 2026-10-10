/* Install the optional SwarmSynth adapter into an already running SuperDirt.
   Loading this file defines no Tdefs, Pdefs, or composition functions.

   In Tidal, import Sound.Tidal.SwarmSynth and use swFlute, swClarinet,
   swOrgan, swMarimba, swBell, and swKick after this setup completes.
*/
(
var root = thisProcess.nowExecutingPath.dirname.dirname.dirname;

if (~dirt.isNil) {
    Error("Start SuperDirt and assign it to ~dirt before installing SwarmDirt").throw;
};

~swDirt !? { |previous| previous.dispose };
thisProcess.interpreter.executeFile(root +/+ "superdirt/SwarmDirt.scd");
~swDirt = ~installSwarmDirt.(~dirt);
~swDirt.registerStandardInstruments;
"SwarmDirt installed: swFlute, swClarinet, swOrgan, swMarimba, swBell, swKick".postln;
)

// Remove every owned voice, timer, callback, and sound registration:
// ~swDirt.dispose; ~swDirt = nil;
