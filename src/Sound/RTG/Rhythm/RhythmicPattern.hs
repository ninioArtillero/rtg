{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE InstanceSigs      #-}
{-# LANGUAGE LambdaCase        #-}

{-|
Module      : RhythmicPattern
Description : Main data type and transformations
Copyright   : (c) Xavier Góngora, 2024
License     : GPL-3
Maintainer  : ixbalanque@protonmail.ch
Stability   : experimental

A 'RhythmicPattern' is a binary lists in a newtype wrapper.
Other types with a ''Rhythmic' instance can be converted to a 'RhythmicPattern'.
-}
module Sound.RTG.Rhythm.RhythmicPattern where


import           Data.Group                      (Group, invert)
import qualified Data.List                       as List
import           Euterpea.Music                  hiding (invert)
import           Sound.RTG.Geometry.Euclidean
import           Sound.RTG.Rhythm.Bjorklund      (euclideanPattern)
import           Sound.RTG.Rhythm.Pattern
import           Sound.RTG.Rhythm.PerfectBalance (indicatorVector)
import           Sound.RTG.Rhythm.TimePatterns

-- | This data type represents integers modulo 2
data Binary = Zero | One deriving (Eq, Ord, Enum, Bounded)

instance Show Binary where
  show Zero = show 0
  show One  = show 1

instance Semigroup Binary where
  Zero <> One  = One
  One  <> Zero = One
  _    <> _    = Zero

instance Monoid Binary where
  mempty = Zero

instance Group Binary where
  invert  = id

-- | Rhythm wrapper to define a new custom instances for lists
newtype Rhythm a = Rhythm {getRhythm :: [a]} deriving (Eq,Show)

instance Functor Rhythm where
  fmap f (Rhythm xs) = Rhythm (fmap f xs)

-- | Two general posibilities for the applicative instances: ZipList or regular list
instance Applicative Rhythm where
  pure :: a -> Rhythm a
  pure xs = Rhythm $ pure xs
  Rhythm fs <*> Rhythm xs = Rhythm (zipWith ($) fs xs) --test

-- TODO: DEFINIR MONADA... QUIZAS AÑADIR COMO ESTADO EL METER

-- TODO: Falta lograr propiedad de inversos.
-- Tal propiedad implicaría que dados dos ritmos cualesquiera r1 y r2
-- entonces existe x de forma que r1 <> x == r2 es True
instance Semigroup a => Semigroup (Rhythm a) where
  Rhythm pttrn1 <> Rhythm pttrn2 = Rhythm $ pttrn1 `euclideanZip` pttrn2

-- TODO: ¿Lista vacía, relación de equivalencia o lista infinita?
-- Depende de la operación. Depende de la operación.
instance (Semigroup a, Monoid a) => Monoid (Rhythm a) where
  mempty = Rhythm []

instance (Semigroup a, Monoid a, Group a) => Group (Rhythm a) where
  invert = fmap invert

type RhythmicPattern = Rhythm Binary

-- | Clusters are groupings of pattern onsets generated by the
-- mutual nearest-neighbor graph (MNNG).
type OnsetClusters = [Rhythm Binary]

-- | Meter carries musical context information
-- related to a patterns underlying pulse.
type Meter = Int

-- | The interface for rhythmic pattern types.
-- It lifts instances to rhythmic patterns.
class (Semigroup a, Monoid a, Group a) => Rhythmic a where
  -- | Minimal complete definition
  toRhythm :: a -> RhythmicPattern

  -- | Inverses
  --
  -- prop> x & inv x = mempty
  --
  -- prop> inv x & x = mempty
  inv :: a -> RhythmicPattern
  inv = toRhythm . invert

  -- | Default group operation
  (&) :: Rhythmic b => a -> b -> RhythmicPattern
  x & y = toRhythm x <> toRhythm y

  -- | Complement. Exchange Onsets and Rests (One and Zero).
  --
  -- prop> (x & co x) = toRhythm $ replicate (length x) One
  --
  -- prop> co (co x) = toRhythm x
  --
  co :: a -> RhythmicPattern
  co x = let rhythm = toRhythm x
         in fmap (\case Zero -> One; One -> Zero) rhythm

  -- | Reverse. Play pattern backwards, different from Inverse.
  --
  -- prop> rev (rev x) = toRhythm x
  --
  rev ::  a -> RhythmicPattern
  rev x = let Rhythm xs = toRhythm x
          in Rhythm $ reverse xs

  -- | Sequence. Plays each pattern every other cycle.
  -- TODO: needs to account for cycle/cycle speed
  (|>) :: Rhythmic b => a -> b -> RhythmicPattern
  r1 |> r2 = Rhythm $ (getRhythm . toRhythm) r1 ++ (getRhythm . toRhythm) r2

  -- | Add up
  --
  -- prop> x <+> x = x
  --
  -- prop> x <+> co x = toRhythm $ replicate (length x) One
  --
  (<+>) :: Rhythmic b => a -> b -> RhythmicPattern
  r1 <+> r2 = fixOne <$> toRhythm r1 <*> toRhythm r2
    where fixOne x y = if x == One then One else y

  -- TODO
  --
  -- ¿Paralellization of patterns? Would depend on a implementation of concurrent streams.
  --
  -- Interpolate. Continuous transformation of patterns.
  -- (/\)
  --
  -- Diverge. Interpolate into complement.
  -- (\/) = (/\) . co

infixr 5 &
infixr 5 |>
infixl 5 <+>

 -- TODO: ¿can euclidean rhythm generate all rhythms?
-- Euclidean rhythms generalize isochronous rhythms and evenly spacing. This might be enough.
-- And in this way rhythm generation might be abstracted.
-- Check this ideas after reading Toussaint chapters 20 and 21

-- | Access the binary pattern underlying a rhythmic type
rhythm :: Rhythmic a => a -> [Binary]
rhythm = getRhythm . toRhythm


instance Rhythmic Euclidean where
  toRhythm (Euclidean k n p) = Rhythm . integralToOnset . rotateLeft (fromIntegral p) $ euclideanPattern (fromIntegral k) (fromIntegral n)

instance Rhythmic RhythmicPattern where
  toRhythm = id

-- TODO: La operación de grupo en [] es la concatenación,
-- al levantarse, ¿Cómo se relaciona con la superposición <+>?
instance Rhythmic TimePattern where
  toRhythm = Rhythm . timeToOnset . queryPattern

-- instance Integral a => Rhythmic [a] where
--   toRhythm = Rhythm . integralToOnset

-- Geometric structures

-- | Computes the /mutual nearest neighbor graph/ of an onset pattern.
-- Lists wrap as if embedded in a circle.
-- The result is a list of patterns formed by the clustering of
-- mutually nearest onsets.
-- For example:
--
-- >>> mnng rumba
-- [[1,0,0,1], [0,0,0], [1], [0,0], [1,0,1], [0,0,0]]
--
-- >>> mnng bossa
-- [[1,0,0,1,0,0,1,0,0,1,0,0,1],[0,0,0]]

-- >>> mnng diatonic
-- [[1,1],[0],[1,0,1],[0],[1,1],[0],[1],[0]]
--
-- NOTE: Isochronous rhythms are collapsed to trival pulses (all onset lists)
--
-- >>> mnng wholeTone
-- [1,1,1,1,1,1]
--
-- TODO: formulate properties
-- TODO: optmize recursion
mnng :: Rhythmic a => a -> [[Binary]]
mnng xs = concatMap (\neighborhood -> if length neighborhood <= 1 then clusterBuilder neighborhood else reverse $ longClusterBuilderIter neighborhood [] []) neighborhoods
  where neighborhoods = parseNeighborhoods . iois $ xs
        clusterBuilder neighborhood =
          case neighborhood of
            [] -> []
            (n, (c1,c2)) : nbs -> case (c1,c2) of
              (GT,GT)   -> [One: replicate (n-1) Zero ++ [One]]
              (LT,LT) -> [replicate (n-1) Zero]
              (GT,LT)  -> [[One], replicate (n-1) Zero]
              (LT,GT)  -> [replicate (n-1) Zero, [One]]
              -- The only singleton case left is one interval rhythms (EQ,EQ)
              (_,_) -> [[One]]
        longClusterBuilderIter [] [] cluster = cluster
        longClusterBuilderIter [] acc cluster = acc:cluster
        longClusterBuilderIter neighborhood acc cluster =
          case neighborhood of
            (n, (c1,c2)) : nbs -> case (c1,c2) of
              (EQ,EQ)  -> if not (null nbs) && (snd . head) nbs == (EQ,LT)
                then longClusterBuilderIter nbs (acc ++ (One : replicate (n-1) Zero) ++ [One] ) cluster
                else longClusterBuilderIter nbs (acc ++ (One : replicate (n-1) Zero)) cluster
              (LT,EQ)  ->
                if (snd . head) nbs == (EQ,LT)
                then longClusterBuilderIter nbs (acc ++ [One]) (replicate (n-1) Zero : cluster)
                else longClusterBuilderIter nbs acc (replicate (n-1) Zero : cluster)
              (EQ,LT)   ->
                     longClusterBuilderIter nbs []  (replicate (n-1) Zero : acc : cluster)
              (GT,EQ)  ->
                     longClusterBuilderIter nbs (One : replicate (n-1) Zero) cluster
              (EQ,GT)   ->
                     longClusterBuilderIter nbs [] ((acc ++ (One : replicate (n-1) Zero ++ [One])) : cluster)

-- | A list of pairs where the second value indicates whether
-- its neighbors first values are bigger
type Neighborhood = [(Int, (Ordering,Ordering))]

-- | Takes an IOI pattern and transforms it into a list of neighborhoods
-- joining the intervals of mutual nearest neighbors
parseNeighborhoods :: [Int] -> [Neighborhood]
parseNeighborhoods bs = reverse . map reverse $ parseNeighborhoodsIter (clusterStart . toNeighborhood $ bs) [] []

-- | Look for a starting neighbor for the cluster to avoid cluster wrapping
-- around the list in 'parseNeighborhoods'
clusterStart :: Neighborhood -> Neighborhood
clusterStart [] = []
clusterStart n
  | not $ any ((== GT) . fst . snd) n = n
  | otherwise = lookStart n
    where
      lookStart n = if (fst . snd . head $ n) == GT then n else lookStart $ rotateLeft 1 n

toNeighborhood :: [Int] -> Neighborhood
-- Applicative style is used on the input, which means that
-- the pattern is evaluated on both functions surrounding @<*>@ before zipping
toNeighborhood = zip <$> id <*> compareNeighbor

-- | Compare an element's left and right neighbors. True means its bigger.
compareNeighbor :: [Int] -> [(Ordering,Ordering)]
compareNeighbor xs = let leftNeighbors = zipWith compare (rotateRight 1 xs) xs
                         rightNeighbors = zipWith compare (rotateLeft 1 xs) xs
                     in zip leftNeighbors rightNeighbors

-- | Iterative helper function for 'parseNeighborhoods'
parseNeighborhoodsIter :: Neighborhood -> Neighborhood -> [Neighborhood] -> [Neighborhood]
parseNeighborhoodsIter [] [] neighborhoods = neighborhoods
parseNeighborhoodsIter [] acc neighborhoods = acc:neighborhoods
parseNeighborhoodsIter (n@(_,bs):ns) acc neighborhoods =
  case bs of
    -- Singleton neighborhoods:
    -- Local minimum
    (GT,GT) -> if null acc
      then parseNeighborhoodsIter ns [] ([n]:neighborhoods)
      else parseNeighborhoodsIter ns [] ([n]:acc:neighborhoods)
    -- Local maximum
    (LT,LT) -> if null acc
      then parseNeighborhoodsIter ns [] ([n]:neighborhoods)
      else parseNeighborhoodsIter ns [] ([n]:acc:neighborhoods)
    -- Decrement
    (GT,LT) -> if null acc
      then parseNeighborhoodsIter ns [] ([n]:neighborhoods)
      else parseNeighborhoodsIter ns [] ([n]:acc:neighborhoods)
    -- Increment
    (LT,GT) -> if null acc
      then parseNeighborhoodsIter ns [] ([n]:neighborhoods)
      else parseNeighborhoodsIter ns [] ([n]:acc:neighborhoods)
    -- Composite neighborhoods:
    -- Add interval to cluster
    (EQ,EQ) ->
           parseNeighborhoodsIter ns (n:acc) neighborhoods
    -- Begin cluster
    (_,EQ) -> if null acc
      then parseNeighborhoodsIter ns [n] neighborhoods
      else parseNeighborhoodsIter ns [n] (acc:neighborhoods)
    -- End a cluster
    (EQ,_) ->
           parseNeighborhoodsIter ns [] ((n:acc):neighborhoods)

-- | Compute the Inter-Onset-Intervals of an onset pattern
iois :: Rhythmic a => a -> [Int]
-- Intervals are calculated by counting the times scanl doesn't add another onset
iois = let intervals = List.group . drop 1 . scanl pickOnsets [] . startPosition
           pickOnsets acc x = if x == One then x:acc else acc
       in map length . intervals . rhythm

-- Conversion functions

integralToOnset :: Integral a => [a] -> [Binary]
integralToOnset = map (\n -> if (== 0) . (`mod` 2) $ n then Zero else One)

toInts :: [Binary] -> [Int]
toInts = let toInt x = case x of Zero -> 0; One -> 1
         in map toInt

timeToOnset :: [Time] -> [Binary]
timeToOnset xs = integralToOnset (indicatorVector xs)

showTimePattern :: TimePattern -> [Binary]
showTimePattern = timeToOnset . getPattern

ioisToOnset :: [Int] -> [Binary]
ioisToOnset = foldr (\x acc -> if x>0 then (One:replicate (x-1) Zero) ++ acc else error "There was a non-positive IOI") []

onsetCount :: [Binary] -> Int
onsetCount = foldl (\acc x -> case x of Zero -> acc; One -> acc + 1) 0


-- Use patterns simultaneaously as rhythms and scales
-- for Euterpea MIDI output

type CPS = Rational
type Root = Pitch
type Scale = [Pitch]

-- | Transforms the first rhythm into a scale to be played at the second.
-- Produces an infinite 'Music Pitch' value.
-- TODO: Take the CPS and root values into a State Monad to stop passing then arround
-- TODO: Look for time and timing issues (Euterpea management of duration)
patternToMusic :: (Rhythmic a, Rhythmic b) => CPS -> Root -> a -> b -> Music Pitch
patternToMusic cps root scalePttrn rhythm =
  let binaryPttrn = getRhythm . toRhythm $ rhythm
      scale = scalePitches root scalePttrn
      -- TODO: aux function to count onsets (faster?)
      n = length scale
      m = onsetCount binaryPttrn
      l = length binaryPttrn
      sync = l * (lcm n m `div` m)
      eventDur = 1/(fromIntegral l * cps)
   in line $ take sync $ matchEvents eventDur binaryPttrn scale

scale :: Rhythmic a => CPS -> Root -> a -> Music Pitch
scale cps root rhythm = line . map (note dur) $ scalePttrn
  where scalePttrn = scalePitches root rhythm
        dur = 1/ fromIntegral (length scalePttrn) * cps

matchEvents :: Dur -> [Binary] -> Scale -> [Music Pitch]
matchEvents 0 _ _  = []
matchEvents _ [] _ = []
matchEvents _ _ [] = []
matchEvents duration pttrn scale =
  let (x:xs) = cycle pttrn
      (p:ps) = cycle scale
   in case x of
     Zero -> rest duration : matchEvents duration xs (p:ps)
     One  -> note duration p : matchEvents duration xs ps

-- TODO: Allow microtonal scales

-- | Transforms a given rhythm into an scale begining at a root note
-- up to its octave.
scalePitches :: Rhythmic a => Root -> a -> Scale
scalePitches root = semitonesToScale root . timeToSemitoneIntervals

timeToSemitoneIntervals :: Rhythmic a => a -> [Int]
timeToSemitoneIntervals pttrn =
  let intervals = iois pttrn
   in reverse $ foldl (\acc x -> (head acc + x):acc) [0] intervals

semitonesToScale :: Root -> [Int] -> Scale
semitonesToScale root = map (pitch . (+ absPitch root))
