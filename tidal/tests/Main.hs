{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Control.Exception (IOException, try)
import Control.Monad (unless)
import Data.IORef (modifyIORef', newIORef, readIORef)
import Data.List (sort, sortOn)
import qualified Data.Map.Strict as Map
import Sound.Tidal.Core
import Sound.Tidal.Params (gain, s)
import Sound.Tidal.ParseBP ()
import Sound.Tidal.Pattern
  ( Arc,
    ArcF (Arc),
    ControlPattern,
    Event,
    Value (..),
    ValueMap,
    defragParts,
    part,
    queryArc,
    value,
    whole,
  )
import Sound.Tidal.SwarmSynth
import Sound.Tidal.UI (rand)
import System.IO (BufferMode (LineBuffering), hSetBuffering, stdout)

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  putStrLn "test: control wire names"
  testControlWireNames
  putStrLn "test: standard sounds"
  testStandardSounds
  putStrLn "test: persistent voice commands"
  testVoiceCommands
  putStrLn "test: hold query stability"
  testHoldQueryStability
  putStrLn "test: panic binding"
  testPanicBinding
  putStrLn "PASS: swarm-synth-tidal tests"

assert :: Bool -> String -> IO ()
assert condition message = unless condition (error message)

eventMaps :: ControlPattern -> Arc -> [ValueMap]
eventMaps pat queryRange = map value $ queryArc pat queryRange

singleMap :: String -> ControlPattern -> ValueMap
singleMap label pat =
  case eventMaps pat (Arc 0 1) of
    [controls] -> controls
    events -> error $ label ++ ": expected one event, got " ++ show (length events)

assertValue :: String -> Value -> ValueMap -> IO ()
assertValue key expected controls =
  assert (Map.lookup key controls == Just expected) $
    key ++ ": missing or incorrectly encoded control"

testControlWireNames :: IO ()
testControlWireNames = do
  let controls = singleMap "controls" $
        s "swFlute"
          # swInstrument "flute"
          # swVoiceId 7
          # swVariant "breathy"
          # swPartials 24
          # swVariations 3
          # swDetune 0.01
          # swMod 0.4
          # swModFreq 0.2
          # swPhase 0.6
          # swPhaseFreq 0.3
          # swPanFreq 0.1
          # swNyquist "fold"
          # swSeed 1234
          # swRampSeconds 12
          # swGrowSeconds 180
          # swGrowPartials 50
          # swGrowVariations 1
          # swVowel 3
          # swVibratoSpeed 4.5
          # swVibratoDepth 0.2
          # swLPF 8000
          # swHPF 80
          # swSweepRatio 8
          # swComb1 0.03
          # swComb2 0.07
          # swPulse 0.4
          # swPulseFreq 3
          # swSaw 0.25
          # swSawFreq 5
          # swKickSweepRatio 7
          # swKickSweepTime 0.03
          # swKickAttack 0.002
          # swKickDrive 1.5
  assertValue "swInstrument" (VS "flute") controls
  assertValue "swVoiceId" (VI 7) controls
  assertValue "swVariant" (VS "breathy") controls
  assertValue "swPartials" (VI 24) controls
  assertValue "swVariations" (VI 3) controls
  assertValue "swDetune" (VF 0.01) controls
  assertValue "swMod" (VF 0.4) controls
  assertValue "swModFreq" (VF 0.2) controls
  assertValue "swPhase" (VF 0.6) controls
  assertValue "swPhaseFreq" (VF 0.3) controls
  assertValue "swPanFreq" (VF 0.1) controls
  assertValue "swNyquist" (VS "fold") controls
  assertValue "swSeed" (VI 1234) controls
  assertValue "swRampSeconds" (VF 12) controls
  assertValue "swGrowSeconds" (VF 180) controls
  assertValue "swGrowPartials" (VI 50) controls
  assertValue "swGrowVariations" (VI 1) controls
  assertValue "swVowel" (VI 3) controls
  assertValue "swVibratoSpeed" (VF 4.5) controls
  assertValue "swVibratoDepth" (VF 0.2) controls
  assertValue "swLPF" (VF 8000) controls
  assertValue "swHPF" (VF 80) controls
  assertValue "swSweepRatio" (VF 8) controls
  assertValue "swComb1" (VF 0.03) controls
  assertValue "swComb2" (VF 0.07) controls
  assertValue "swPulse" (VF 0.4) controls
  assertValue "swPulseFreq" (VF 3) controls
  assertValue "swSaw" (VF 0.25) controls
  assertValue "swSawFreq" (VF 5) controls
  assertValue "swKickSweepRatio" (VF 7) controls
  assertValue "swKickSweepTime" (VF 0.03) controls
  assertValue "swKickAttack" (VF 0.002) controls
  assertValue "swKickDrive" (VF 1.5) controls

testStandardSounds :: IO ()
testStandardSounds = do
  let expected = ["swFlute", "swClarinet", "swOrgan", "swMarimba", "swBell", "swKick"]
      actual = map soundName [swFlute, swClarinet, swOrgan, swMarimba, swBell, swKick]
  assert (actual == expected) "standard sound helper names changed"
  assertValue "freq" (VF 55) (singleMap "kick default" swKick)
  where
    soundName pat =
      case Map.lookup "s" $ singleMap "standard sound" pat of
        Just (VS name) -> name
        _ -> error "standard sound: missing string s control"

testVoiceCommands :: IO ()
testVoiceCommands = do
  let releaseControls = singleMap "release" $ swRelease 9
      freeControls = singleMap "free" $ swFree 10
  assertValue "s" (VS "swVoice") releaseControls
  assertValue "swVoiceId" (VI 9) releaseControls
  assertValue "swOp" (VS "release") releaseControls
  assertValue "s" (VS "swVoice") freeControls
  assertValue "swVoiceId" (VI 10) freeControls
  assertValue "swOp" (VS "free") freeControls

testHoldQueryStability :: IO ()
testHoldQueryStability = do
  let held = swHold $ s "swVoice" # swInstrument "drone" # swVoiceId 2 # swPartials "8 16" # gain rand
      allAtOnceEvents = queryArc held (Arc 0 1)
      splitEvents = queryArc held (Arc 0 (1 / 2)) ++ queryArc held (Arc (1 / 2) 1)
      allAtOnce = map value allAtOnceEvents
  assert (length allAtOnce == 16) "swHold did not emit sixteen heartbeat events per cycle"
  assert (all ((== Just (VS "hold")) . Map.lookup "swOp") allAtOnce)
    "swHold did not mark every heartbeat as hold"
  assert (normalize allAtOnceEvents == normalize splitEvents)
    "swHold changed events across split scheduler queries"
  assert (length (eventMaps held (Arc 4 5)) == 16)
    "swHold heartbeat rate changed in a later cycle"

normalize :: [Event ValueMap] -> [Event ValueMap]
normalize = sort . defragParts . sortOn (\event -> (whole event, part event, value event))

testPanicBinding :: IO ()
testPanicBinding = do
  unbound <- try swPanic :: IO (Either IOException ())
  case unbound of
    Left _ -> pure ()
    Right _ -> error "swPanic succeeded before a cleanup action was bound"
  calls <- newIORef (0 :: Int)
  swBindPanic $ modifyIORef' calls (+ 1)
  swPanic
  swPanic
  count <- readIORef calls
  assert (count == 2) "swPanic did not invoke the bound action"
