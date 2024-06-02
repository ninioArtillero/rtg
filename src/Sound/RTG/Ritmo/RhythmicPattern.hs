{-# LANGUAGE FlexibleInstances #-}
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
import qualified Data.List                      as List
import           Sound.RTG.Geometria.Euclidean
import           Sound.RTG.Ritmo.Bjorklund      (euclideanPattern)
import           Sound.RTG.Ritmo.Pattern
import           Sound.RTG.Ritmo.PerfectBalance (indicatorVector)

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

-- | Pattern wrapper to define a new Subgroup instance
newtype Rhythm a = Rhythm {getRhythm :: Pattern a} deriving (Eq,Show)

instance Functor Rhythm where
  fmap f (Rhythm xs) = Rhythm (fmap f xs)

-- | Two general posibilities for the applicative instances: ZipList or regular list
instance Applicative Rhythm where
  pure xs = Rhythm $ pure xs
  Rhythm fs <*> Rhythm xs = Rhythm (zipWith ($) fs xs) --test

-- TODO: DEFINIR MONADA... QUIZAS AÑADIR COMO ESTADO EL METER

-- TODO: Falta lograr propiedad de inversos.
-- Tal propiedad implicaría que dados dos ritmos cualesquiera r1 y r2
-- entonces existe x de forma que r1 <> x == r2 es True
instance Semigroup a => Semigroup (Rhythm a) where
  Rhythm pttrn1 <> Rhythm pttrn2 = Rhythm $ pttrn1 `euclideanZip` pttrn2

-- | Deprecated semigroup operation
pttrn1 `frontWideZip` pttrn2 = zipWith (<>) pttrn1 pttrn2 ++ diffPattern pttrn1 pttrn2

-- TODO: Explore other operations: backWideZip, frontNarrowZip (regular zip),
-- backNarrowZip, centerWideZip and centerNarrowZip.
-- Note that according to design criteria, we target the least amount of arbritrarity.

-- | When patterns have different size,
-- distributes event composition as evenly as possible matching euclidean onsets.
-- Otherwise it zips one to one.
-- TODO: there's ambiguity regarding the position of the euclidean pattern,
-- this could be exploited. For example, use all and choose the one
-- with the least rests.
-- TODO: choose finite lists... may be I need stronger types (GADTs?).
euclideanZip :: Semigroup a => Pattern a -> Pattern a -> Pattern a
pttrn1 `euclideanZip` pttrn2
  | len1 == len2 = zipWith (<>) pttrn1 pttrn2
  | otherwise = fzip pttrn markedPattern []
  where (pttrn, markedPattern)= if len1 == k
          then (pttrn1, pttrn2 `zip` euclideanPattern k n)
          else (pttrn2, pttrn1 `zip` euclideanPattern k n)
        len1 = length pttrn1; len2 = length pttrn2
        k = min len1 len2; n = max len1 len2
        fzip :: Semigroup a => Pattern a -> Pattern (a,Int) -> Pattern a -> Pattern a
        fzip [] ys zs = reverse zs
        -- superflous case?
        fzip xs [] zs = reverse zs
        fzip (x:xs) (y:ys) zs = if snd y == 1 then fzip xs ys ((x <> fst y):zs)
                                              else fzip (x:xs) ys ((fst y):zs)
        -- is this a fold? branched fold?

-- TODO: ¿Lista vacía, relación de equivalencia o lista infinita?
-- Depende de la operación. Depende de la operación.
instance (Semigroup a, Monoid a) => Monoid (Rhythm a) where
  mempty = Rhythm $ repeat mempty

instance (Semigroup a, Monoid a, Group a) => Group (Rhythmic a) where
  invert = fmap (invert x)

type RhythmicPattern = Rhythm Binary

-- | Clusters are groupings of pattern onsets generated by the
-- mutual nearest-neighbor graph (MNNG).
type OnsetClusters = [Rhythm Binary]

-- | Meter carries musical context information
-- related to a patterns underlying pulse.
type Meter = Int

-- | The interface for rhythmic pattern types.
-- It lifts instances to rhythmic patterns.
class Semigroup a => Rhythmic a where
  -- | Minimal complete definition
  toRhythm :: a -> RhythmicPattern

  -- | Inverses
  --
  -- prop> x & inv x = mempty
  --
  -- prop> inv x & x = mempty
  inv :: a -> RhythmicPattern
  inv = invert . toRhythm

  -- | Group structure lifting
  (&) :: Rhythmic b => a -> b -> RhythmicPattern
  x & y = toRhythm x <> toRhythm y
  (!&) :: a -> a -> RhythmicPattern
  x !& y = toRhythm (x <> y)

  -- | Complement. Exchange Onsets and Rests (One and Zero).
  --
  -- prop> (x & co x) = toRhythm $ replicate (length x) One
  --
  -- prop> co (co x) = toRhythm x
  --
  co :: a -> RhythmicPattern
  co x = let rhythm = toRhythm x
         in fmap (\x -> case x of Zero -> One; One -> Zero) rhythm

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
infixr 6 !&
infixr 5 |>
infixl 5 <+>

 -- TODO: ¿can euclidean rhythm generate all rhythms?
-- Euclidean rhythms generalize isochronous rhythms and evenly spacing. This might be enough.
-- And in this way rhythm generation might be abstracted.
-- Check this ideas after reading Toussaint chapters 20 and 21

instance Rhythmic Euclidean where
  toRhythm (Euclidean k n p) = Rhythm . integralToOnset . rotateLeft p $ euclideanPattern k n

instance Rhythmic RhythmicPattern where
  toRhythm = id

instance Rhythmic (Pattern Binary) where
  toRhythm = Rhythm

instance Rhythmic (Pattern Time) where
  toRhythm = Rhythm . timeToOnset

-- Geometric structures

-- | Computes the mutual nearest neighbor graph for the Rhythmic type cluster field.
-- For example:
-- cluster rumba = [[1,0,0,1], [0,0,0], [1,0,0], [1,0,1], [0,0,0]]
-- TODO Decide what to do with clusters that wrap pass the cycle border
-- For example, bossa has only one cluster:
-- clusters bossa = [[1,0,0,1,0,0,1],[0,0,0],[1,0,0,1,0,0]]
mutualNNG :: Pattern Binary -> [Pattern Binary]
mutualNNG xs = map (\neighborhood -> if length neighborhood <= 1 then clusterBuilder neighborhood else longClusterBuilder neighborhood) neighborhoods
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
biggerNeighbor xs = let leftNeighbors = zipWith (>) (rotateRight 1 xs) xs
                        rightNeighbors = zipWith (>) (rotateLeft 1 xs) xs
                    in zip leftNeighbors rightNeighbors

-- | Compute the Inter-Onset-Intervals of an onset pattern
iois :: Pattern Binary -> [Int]
iois = let intervals = List.group . drop 1 . scanl pickOnsets [] . startPosition
           pickOnsets acc x = if x == One then x:acc else acc
       in map length . intervals

-- Conversion functions

integralToOnset :: Integral a => Pattern a -> Pattern Binary
integralToOnset = map (\n -> if (== 0) . (`mod` 2) $ n then Zero else One)

toInts :: Pattern Binary -> Pattern Int
toInts = let toInt x = case x of Zero -> 0; One -> 1
         in map toInt

timeToOnset :: Pattern Time -> Pattern Binary
timeToOnset xs = integralToOnset (indicatorVector xs)

ioisToOnset :: [Int] -> Pattern Binary
ioisToOnset = foldr (\x acc -> if x>0 then (One:replicate (x-1) Zero) ++ acc else error "There was a non-positive IOI") []
