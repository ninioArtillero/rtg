{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE InstanceSigs      #-}
module Sound.RTG.Rhythm.RhythmicPattern where
{-|
Module      : RhythmicPattern
Description : Main data type and its API helper functions
Copyright   : (c) Xavier Góngora, 2024
License     : GPL-3
Maintainer  : ixbalanque@protonmail.ch
Stability   : experimental

Rhythmic patterns are wrapped patterns with aditional structure.
-}

import           Data.Group                      (Group, invert)
import qualified Data.List                       as List
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

type Pattern a = [a]

-- | Pattern wrapper to define a new Subgroup instance
newtype Rhythm a = Rhythm {getRhythm :: Pattern a} deriving (Eq,Show)

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

instance Rhythmic Euclidean where
  toRhythm (Euclidean k n p) = Rhythm . integralToOnset . rotateLeft p $ euclideanPattern k n

instance Rhythmic RhythmicPattern where
  toRhythm = id

-- TODO: La operación de grupo en Pattern es la concatenación de listas,
-- al levantarse, ¿Cómo se relaciona con la superposición <+>?
instance Rhythmic TimePattern where
  toRhythm = Rhythm . timeToOnset . queryPattern

-- instance Integral a => Rhythmic [a] where
--   toRhythm = Rhythm . integralToOnset

-- Geometric structures

-- | Computes the mutual nearest neighbor graph of an onset pattern.
-- For example:
--
-- >>> cluster rumba
-- [[1,0,0,1], [0,0,0], [1,0,0], [1,0,1], [0,0,0]]
--
-- TODO: Decide what to do with clusters that wrap pass the cycle border
-- For example, bossa has only one cluster sourrounding the 3 rest interval:
--
-- >>> clusters bossa
-- [[1,0,0,1,0,0,1],[0,0,0],[1,0,0,1,0,0]]
mutualNNG :: Pattern Binary -> [Pattern Binary]
mutualNNG xs = map (\neighborhood -> if length neighborhood <= 1 then clusterBuilder neighborhood else longClusterBuilder neighborhood) neighborhoods
  where neighborhoods = parseNeighborhoods $ iois xs
        clusterBuilder neighborhood =
          case neighborhood of
            [] -> []
            -- True signals the presense of a One
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


-- | Takes a IOIs pattern and returns a list of lists with minimal IOIs in the same list
-- and neighboorhood information.
parseNeighborhoods :: Pattern Int -> [[(Int,(Bool,Bool))]]
-- | Applicative style is used on the input, which means that
-- the pattern is evaluated on both functions surrounding @<*>@ before zipping)
parseNeighborhoods bs = reverse $ map reverse $ parseNeighborhoodsIter (zip <$> id <*> biggerNeighbor $ bs) [] []

-- | Helper function with an extra parameter to join the intervals of nearest neighbors
parseNeighborhoodsIter :: [(Int, (Bool,Bool))] -> [(Int, (Bool,Bool))] -> [[(Int, (Bool,Bool))]] -> [[(Int, (Bool,Bool))]]
parseNeighborhoodsIter [] [] clusters = clusters
parseNeighborhoodsIter [] acc clusters = acc:clusters
parseNeighborhoodsIter (n@(_,bs):ns) acc clusters =
  case bs of
    -- A local minimum forms its own cluster.
    -- Conditional to avoid passing empty list
    (True,True) -> if null acc
      then parseNeighborhoodsIter ns [] ([n]:clusters)
      else parseNeighborhoodsIter ns [] ([n]:acc:clusters)
    -- Start a new cluster without passing empty lists
    (True,False) -> if null acc
      then parseNeighborhoodsIter ns [n] clusters
      else parseNeighborhoodsIter ns [n] (acc:clusters)
    -- Add interval to cluster
    (False,False) ->
           parseNeighborhoodsIter ns (n:acc) clusters
    -- | Close a cluster
    (False,True) ->
           parseNeighborhoodsIter ns [] ((n:acc):clusters)

-- | Compare an element's left and right neighbors. True means its bigger.
biggerNeighbor :: [Int] -> [(Bool,Bool)]
biggerNeighbor xs = let leftNeighbors = zipWith (>) (rotateRight 1 xs) xs
                        rightNeighbors = zipWith (>) (rotateLeft 1 xs) xs
                    in zip leftNeighbors rightNeighbors

-- | Compute the Inter-Onset-Intervals of an onset pattern
iois :: Pattern Binary -> [Int]
-- Intervals are calculated by counting the times the scan doesn't add another onset
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

showTimePattern :: TimePattern -> Pattern Binary
showTimePattern = timeToOnset . getPattern

ioisToOnset :: [Int] -> Pattern Binary
ioisToOnset = foldr (\x acc -> if x>0 then (One:replicate (x-1) Zero) ++ acc else error "There was a non-positive IOI") []
