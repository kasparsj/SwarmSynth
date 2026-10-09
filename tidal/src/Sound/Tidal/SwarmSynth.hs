{-# LANGUAGE OverloadedStrings #-}

-- | Tidal control parameters and command helpers for the optional
-- SwarmSynth SuperDirt adapter.
--
-- This module only constructs ordinary Tidal control events. It has no
-- dependency on SuperDirt or SuperCollider; the receiving adapter owns sound
-- registration, synthesis, persistent-voice state, and cleanup.
module Sound.Tidal.SwarmSynth
  ( -- * Adapter controls
    swInstrument,
    swVoiceId,
    swVariant,
    swPartials,
    swVariations,
    swDetune,
    swMod,
    swModFreq,
    swPhase,
    swPhaseFreq,
    swPanFreq,
    swNyquist,
    swSeed,
    swRampSeconds,
    swGrowSeconds,
    swGrowPartials,
    swGrowVariations,
    swVowel,
    swVibratoSpeed,
    swVibratoDepth,
    swLPF,
    swHPF,
    swSweepRatio,
    swComb1,
    swComb2,
    swPulse,
    swPulseFreq,
    swSaw,
    swSawFreq,

    -- * Persistent voices
    swHold,
    swRelease,
    swFree,
    swBindPanic,
    swPanic,

    -- * Standard instrument sounds
    swFlute,
    swClarinet,
    swOrgan,
    swMarimba,
    swBell,
  )
where

import Data.IORef (IORef, atomicWriteIORef, newIORef, readIORef)
import Sound.Tidal.Core ((#))
import Sound.Tidal.Pattern (ControlPattern, Pattern)
import Sound.Tidal.Params (pF, pI, pS, s)
import Sound.Tidal.UI (segment)
import System.IO.Unsafe (unsafePerformIO)

-- The names below are the wire contract shared with the SuperCollider
-- adapter. Keep their spelling and case stable.

-- | Select a registered instrument recipe by name.
swInstrument :: Pattern String -> ControlPattern
swInstrument = pS "swInstrument"

-- | Identify a persistent voice within an orbit.
swVoiceId :: Pattern Int -> ControlPattern
swVoiceId = pI "swVoiceId"

-- | Select a registered recipe variant by name.
swVariant :: Pattern String -> ControlPattern
swVariant = pS "swVariant"

-- | Override the recipe's partial count.
swPartials :: Pattern Int -> ControlPattern
swPartials = pI "swPartials"

-- | Override the number of variations per partial.
swVariations :: Pattern Int -> ControlPattern
swVariations = pI "swVariations"

-- | Set the recipe's detuning amount.
swDetune :: Pattern Double -> ControlPattern
swDetune = pF "swDetune"

-- | Set amplitude-modulation depth.
swMod :: Pattern Double -> ControlPattern
swMod = pF "swMod"

-- | Set amplitude-modulation frequency.
swModFreq :: Pattern Double -> ControlPattern
swModFreq = pF "swModFreq"

-- | Set phase-modulation depth.
swPhase :: Pattern Double -> ControlPattern
swPhase = pF "swPhase"

-- | Set phase-modulation frequency.
swPhaseFreq :: Pattern Double -> ControlPattern
swPhaseFreq = pF "swPhaseFreq"

-- | Set pan-modulation frequency.
swPanFreq :: Pattern Double -> ControlPattern
swPanFreq = pF "swPanFreq"

-- | Select a registered Nyquist policy by name.
swNyquist :: Pattern String -> ControlPattern
swNyquist = pS "swNyquist"

-- | Set the adapter's deterministic sampling seed.
swSeed :: Pattern Int -> ControlPattern
swSeed = pI "swSeed"

-- | Set the duration of a persistent-voice transition in seconds.
swRampSeconds :: Pattern Double -> ControlPattern
swRampSeconds = pF "swRampSeconds"

-- | Set the duration of an adapter-managed density growth in seconds.
swGrowSeconds :: Pattern Double -> ControlPattern
swGrowSeconds = pF "swGrowSeconds"

-- | Set the target partial count for an adapter-managed density growth.
swGrowPartials :: Pattern Int -> ControlPattern
swGrowPartials = pI "swGrowPartials"

-- | Set the final variation count for an adapter-managed density growth.
swGrowVariations :: Pattern Int -> ControlPattern
swGrowVariations = pI "swGrowVariations"

-- | Select the numeric vowel index used by compatible voice recipes.
swVowel :: Pattern Int -> ControlPattern
swVowel = pI "swVowel"

-- | Set vibrato speed for compatible recipes.
swVibratoSpeed :: Pattern Double -> ControlPattern
swVibratoSpeed = pF "swVibratoSpeed"

-- | Set vibrato depth for compatible recipes.
swVibratoDepth :: Pattern Double -> ControlPattern
swVibratoDepth = pF "swVibratoDepth"

-- | Set the low-pass cutoff for compatible recipes.
swLPF :: Pattern Double -> ControlPattern
swLPF = pF "swLPF"

-- | Set the high-pass cutoff for compatible recipes.
swHPF :: Pattern Double -> ControlPattern
swHPF = pF "swHPF"

-- | Set a sweep recipe's target-frequency ratio.
swSweepRatio :: Pattern Double -> ControlPattern
swSweepRatio = pF "swSweepRatio"

-- | Set the first comb parameter for compatible recipes.
swComb1 :: Pattern Double -> ControlPattern
swComb1 = pF "swComb1"

-- | Set the second comb parameter for compatible recipes.
swComb2 :: Pattern Double -> ControlPattern
swComb2 = pF "swComb2"

-- | Set pulse amount for compatible recipes.
swPulse :: Pattern Double -> ControlPattern
swPulse = pF "swPulse"

-- | Set pulse frequency for compatible recipes.
swPulseFreq :: Pattern Double -> ControlPattern
swPulseFreq = pF "swPulseFreq"

-- | Set saw amount for compatible recipes.
swSaw :: Pattern Double -> ControlPattern
swSaw = pF "swSaw"

-- | Set saw frequency for compatible recipes.
swSawFreq :: Pattern Double -> ControlPattern
swSawFreq = pF "swSawFreq"

swOp :: Pattern String -> ControlPattern
swOp = pS "swOp"

-- | Sample a persistent voice's controls on a sixteen-event-per-cycle grid
-- and mark every resulting event as a hold/update command. The 16-step cycle
-- grid is the adapter heartbeat; it does not speed up the source pattern.
swHold :: ControlPattern -> ControlPattern
swHold source = segment 16 source # swOp (pure "hold")

-- | Construct release commands for the given voice identifiers. The adapter
-- preserves each voice's configured release tail.
swRelease :: Pattern Int -> ControlPattern
swRelease voiceIds =
  s (pure "swVoice") # swVoiceId voiceIds # swOp (pure "release")

-- | Construct immediate-free commands for the given voice identifiers.
swFree :: Pattern Int -> ControlPattern
swFree voiceIds =
  s (pure "swVoice") # swVoiceId voiceIds # swOp (pure "free")

{-# NOINLINE panicHook #-}
panicHook :: IORef (Maybe (IO ()))
panicHook = unsafePerformIO $ newIORef Nothing

-- | Bind the emergency cleanup action for the active Tidal stream. Boot code
-- should call this once, for example with an action that sends one @swPanic@
-- sound event and then silences the relevant streams.
swBindPanic :: IO () -> IO ()
swBindPanic action = atomicWriteIORef panicHook (Just action)

-- | Run the emergency cleanup action installed by 'swBindPanic'. Failing
-- explicitly before binding avoids a false impression that voices were freed.
swPanic :: IO ()
swPanic = do
  binding <- readIORef panicHook
  case binding of
    Just action -> action
    Nothing -> ioError $ userError "swPanic: no action bound; call swBindPanic in BootTidal"

-- | The standard registered flute sound.
swFlute :: ControlPattern
swFlute = s $ pure "swFlute"

-- | The standard registered clarinet sound.
swClarinet :: ControlPattern
swClarinet = s $ pure "swClarinet"

-- | The standard registered organ sound.
swOrgan :: ControlPattern
swOrgan = s $ pure "swOrgan"

-- | The standard registered marimba sound.
swMarimba :: ControlPattern
swMarimba = s $ pure "swMarimba"

-- | The standard registered bell sound.
swBell :: ControlPattern
swBell = s $ pure "swBell"
