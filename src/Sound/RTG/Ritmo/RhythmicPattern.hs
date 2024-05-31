{-# LANGUAGE InstanceSigs #-}
module Sound.RTG.Ritmo.RhythmicPattern where
{-|
Module      : RhythmicPattern
Description : Main data type and its API helper functions
Copyright   : (c) Xavier Góngora, 2024
License     : GPL-3
Maintainer  : ixbalanque@protonmail.ch
Stability   : experimental

Rhythmic patterns are wrapped patterns with aditional structure.
-}

import           Data.Group                     (Group, invert)
import           Data.List                      (group, sort)
import           Sound.RTG.Geometria.Euclidean
import qualified Sound.RTG.Ritmo.Pattern        as P
import           Sound.RTG.Ritmo.PerfectBalance (indicatorVector)

-- | This data type represents integers modulo 2
data Binary = Zero | One deriving (Eq, Ord, Enum, Bounded)

instance Show Binary where
  show :: Binary -> String
  show Zero = show 0
  show One  = show 1

instance Semigroup Binary where
  (<>) :: Binary -> Binary -> Binary
  Zero <> One  = One
  One  <> Zero = One
  _    <> _    = Zero

-- TODO: change to onset notation (x . . x . .)
instance Monoid Binary where
  mempty :: Binary
  mempty = Zero

instance Group Binary where
  invert :: Binary -> Binary
  invert  = id

-- | Onset patterns are represented by binary valued lists
-- so that group structure can de lifted.
newtype Rhythm = Rhythm {getRhythm :: (P.Pattern Binary)} deriving (Eq,Show)

-- | Clusters are groupings of pattern onsets generated by the
-- mutual nearest-neighbor graph (MNNG).
type OnsetClusters = [Rhythm]

-- | Meter carries musical context information
-- related to a patterns underlying pulse.
type Meter = Int

-- | This data type encondes a rhythmic pattern along with
-- other structure related to rhythm perception.
-- data Rhythmicc = Rhythm {
--                        pttrn       :: OnsetPattern,
--                        clusters    :: OnsetClusters,
--                        meter       :: Meter,
--                        orientation :: Sign
--                       } deriving (Eq,Show)

class Rhythmic a where
  toRhythm :: a -> Rhythm

instance Rhythmic Rhythm where
  toRhythm = id

instance Rhythmic Euclidean where
  toRhythm (Euclidean k n p) = integralToOnset $ rotateLeft p $ euclideanPattern k n

-- TODO: Create functor instance of rhythmic to lift list transformations

instance Semigroup Rhythm where
  (<>) :: Rhythm -> Rhythm -> Rhythm
  Rhythm pttrn1 <> Rhythm pttrn2 = Rhythm $ reduceEmpty $ zipWith (<>) pttrn1 pttrn2 ++ P.diff pttrn1 pttrn2

instance Group Rhythm where
  invert :: Rhythmic -> Rhythmic
  invert = inv

-- Main functions

inv :: Rhythm -> Rhythm
inv = Rhythm . map (\x -> if x == Zero then One else Zero) . getRhythm

-- | Computes the mutual nearest neighbor graph for the Rhythmic type cluster field.
-- For example:
-- cluster rumba = [[1,0,0,1], [0,0,0], [1,0,0], [1,0,1], [0,0,0]]
-- TODO Decide what to do with clusters that wrap pass the cycle border
-- For example, bossa has only one cluster:
-- clusters bossa = [[1,0,0,1,0,0,1],[0,0,0],[1,0,0,1,0,0]]
mutualNNG :: Rhythm -> OnsetClusters
mutualNNG (Rhythm xs) = map Rhythm . map (\neighborhood -> if length neighborhood <= 1 then clusterBuilder neighborhood else longClusterBuilder neighborhood) neighborhoods
  where neighborhoods = parseNeighborhoods $ iois xs
        clusterBuilder neighborhood =
          case neighborhood of
            [] -> []
            (n, (b1,b2)) : nbs -> case (b1,b2) of
              (True,True)   -> One : replicate (n-1) Zero ++ [One]
              (True,False)  -> One : replicate (n-1) Zero
              (False,False) -> replicate (n-1) Zero
              (False,True)  -> replicate (n-1) Zero ++ [One]
        longClusterBuilder neighborhood =
          case neighborhood of
            [] -> []
            (n, (b1,b2)) : nbs -> case (b1,b2) of
              (_,True)   -> One : replicate (n-1) Zero ++ [One] ++ longClusterBuilder nbs
              (_,False)  -> One : replicate (n-1) Zero ++ longClusterBuilder nbs


parseNeighborhoods :: [Int] -> [[(Int,(Bool,Bool))]]
-- | Applicative style is used on the input, which means that
-- the rhythmic pattern is evaluated on both functions surrounding @<*>@ before zipping)
parseNeighborhoods bs = map reverse $ parseNeighborhoodsIter (zip <$> id <*> biggerNeighbor $ bs) []

-- | Helper function with an extra parameter to join the intervals of nearest neighbors
parseNeighborhoodsIter :: [(Int, (Bool,Bool))] -> [(Int, (Bool,Bool))] -> [[(Int, (Bool,Bool))]]
parseNeighborhoodsIter [] [] = []
parseNeighborhoodsIter [] xs = [xs]
parseNeighborhoodsIter (m@(int,ns):bs) xs = case ns of
  -- | A local minimum is its own cluster. Avoid passing empty list.
  (True,True) -> if null xs
    then [m] : parseNeighborhoodsIter bs []
    else xs : [m] : parseNeighborhoodsIter bs []
  -- | Start a new cluster without passing empty lists
  (True,False) -> if null xs
    then parseNeighborhoodsIter bs [m]
    else xs : parseNeighborhoodsIter bs [m]
  -- | Add interval to cluster
  (False,False) -> parseNeighborhoodsIter bs (m:xs)
  -- | Close a cluster
  (False,True) -> (m:xs) : parseNeighborhoodsIter bs []

-- | Compare an element's left and right neighbors. True means its bigger.
biggerNeighbor :: [Int] -> [(Bool,Bool)]
biggerNeighbor xs = let leftNeighbors = zipWith (>) (P.rotateRight 1 xs) xs
                        rightNeighbors = zipWith (>) (P.rotateLeft 1 xs) xs
                    in zip leftNeighbors rightNeighbors

-- | Compute the Inter-Onset-Intervals of an onset pattern
iois :: Rhythm -> [Int]
iois r =
  let intervals = group . drop 1 . scanl pickOnsets [] . getRhythm . startPosition $ r
      pickOnsets acc x = if x == One then x:acc else acc
  in map length intervals

-- Conversion functions

integralToOnset :: Integral a => P.Pattern a -> Rhythm
integralToOnset = Rhythm . map (\n -> if (== 0) . (`mod` 2) $ n then Zero else One)

toInts :: Rhythm -> P.Pattern Int
toInts = let toInt x = case x of Zero -> 0; One -> 1
         in map toInt . getRhythm

timeToOnset :: P.Pattern P.Time -> Rhythm
timeToOnset xs = Rhythm . integralToOnset (indicatorVector xs)

ioisToOnset :: [Int] -> Rhythm
ioisToOnset = Rhythm . foldr (\x acc -> if x>0 then (One:replicate (x-1) Zero) ++ acc else error "There was a non-positive IOI") []

-- Auxiliary functions

startPosition :: Rhythm -> Rhythm
startPosition (Rhythm []) = Rhythm []
startPosition (Rhythm pttrn@(x:xs))
  | null (reduceEmpty pttrn) = Rhythm []
  | x == Zero = startPosition $ P.rotateLeft 1 pttrn
  | otherwise = Rhythm pttrn

-- | Steps away from the first onset
position :: Rhythm -> Int
position (Rhythm xs)
  | null (reduceEmpty xs) = 0
  | take 1 xs == [One] = 0
  | otherwise = 1 + position $ Rhythm (drop 1 xs)


reduceEmpty :: Rhythm -> Rhythm
reduceEmpty (Rhythm [])          = Rhythm []
reduceEmpty (Rhythm pttrn@(x:xs)) = if x == Zero then reduceEmpty Rhythm xs else Rhythm pttrn

-- Toussaint's six distinguished rhythms for examples

clave = timeToOnset P.clave
rumba = timeToOnset P.rumba
gahu = timeToOnset P.gahu
shiko = timeToOnset P.shiko
bossa = timeToOnset P.bossa
soukous = timeToOnset P.soukous

-- TODO: Create module with rhythmic pattern combinators:
-- sequence, parallel, complement, reverse...
