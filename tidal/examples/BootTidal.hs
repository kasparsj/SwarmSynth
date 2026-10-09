:set -fno-warn-orphans -Wno-type-defaults -XMultiParamTypeClasses -XOverloadedStrings
:set prompt ""

import Sound.Tidal.Boot
import Sound.Tidal.SwarmSynth

default (Rational, Integer, Double, Pattern String)

tidalInst <- mkTidal

instance Tidally where tidal = tidalInst

-- The adapter registers swPanic as a command sound. Bind emergency cleanup
-- after mkTidal so the library helper can reach this active stream.
swBindPanic $ once $ s "swPanic"

:set prompt "tidal> "
:set prompt-cont ""
