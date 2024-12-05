-- | Main API
module Sound.RTG
  (
    p
    -- * Re-exported modules
  , module Euterpea.IO.MIDI
  , module Euterpea.Music
  , module Sound.RTG.Geometry
  , module Sound.RTG.ReactivePattern
  , module Sound.RTG.Rhythm
  , module Sound.RTG.Time
  )
where


import           Control.Concurrent        (ThreadId, forkIO, readMVar)
import           Control.Monad             (forever)
import           Euterpea.IO.MIDI
import           Euterpea.Music            hiding (forever, invert)
import           Sound.RTG.Geometry
import           Sound.RTG.ReactivePattern
import           Sound.RTG.Rhythm
import           Sound.RTG.TiledStreams
import           Sound.RTG.Time

p :: (Rhythmic a, Rhythmic b) => Root -> a -> b -> IO ThreadId
p root r1 r2 =
  forkIO $ forever $ do
    cps <- readMVar globalCPS
    playS $ patternToMusic cps root r1 r2
