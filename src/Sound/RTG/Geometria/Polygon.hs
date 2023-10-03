{-|
Module      : Polygon
Description : Generation of irreducibly periodic and perfectly balanced rhythms
Copyright   : (c) Xavier Góngora, 2023
License     : GPL-3
Maintainer  : ixbalanque@protonmail.ch
Stability   : experimental

Generation of irreducibily periodic and perfectly balaced rhythms
using linear sums of polygons. In the simplest case they can be thought of as /displaced polyrhythms/: the combination
of isochronous beats of different and coprime interonset intervals displaced so that they never
coincide. None trivial structures araise when weigthed sums are allowed.

Based on the heuristics found in:
Milne, Andrew, David Bulger, Steffen Herff, y William Sethares. 2015.
“Perfect balance: A novel principle for the construction of musical scales and meters”.
In Mathematics and computation in music: 5th international conference, MCM 2015;
proceedings, 97–108. Lecture notes in computer science 9110. London, UK.
https://doi.org/10.1007/978-3-319-20603-5.
-}
module Sound.RTG.Geometria.Polygon {-(Polygon, polygonPattern, polygonPatternSum, rotateLeft, rotateRight)-} where

import qualified Data.Set as Set
import Sound.RTG.Ritmo.Pattern ( Pattern, rotateLeft )

-- TODO:
-- Al definir un polígono hay que ver la manera de generalizar su posición
-- módulo rotaciones (para evitar que se superpongan).
-- Además, hay que cuidar cuando la suma de polígonos forman otro polígono regular
-- que no es coprimo con alguno de los considerados.
-- La generalización a sumas no disjuntas permite dar pesos a los polígonos, siempre que
-- la combinación lineal resultante sólo contenga 1 y 0.

-- | The Polygon data type is used to represent regular polygons on a discrete space in the circle.
data Polygon = Polygon Pulses Onsets Position

type Pulses = Int
type Onsets = Int
type Position = Int

type Scalar = Int

instance Show Polygon where
  show = show . polygonPattern

-- TODO: Comparar con factors de Data.Numbers
divisors :: Int -> [Int]
divisors n = [k | k <- [2 .. (n - 1)], n `rem` k == 0]

-- Coprime Disjoint Regular Polygons

-- | Produces a list of @1@ and @0@ representing a @k@-gon in circular @n@-space
-- It only has @0@ when @k@ is less than @2@ or doesn't divide @n@.
-- Empty for @n <= 0@.
polygonPattern :: Polygon -> Pattern Int
polygonPattern (Polygon n k p)
  | k >= 2 && n `rem` k == 0 = rotateLeft p . concat . replicate k $ side
  | otherwise = replicate n 0
  where
    subperiod = n `quot` k
    side = 1 : replicate (subperiod - 1) 0

-- | The same as 'polygonPattern' but with weighted vertices of integer value @a@.
wPolygonPattern :: (Scalar, Polygon) -> Pattern Int
wPolygonPattern (a, Polygon n k p)
  | k >= 2 && n `rem` k == 0 = rotateLeft p . concat . replicate k $ side
  | otherwise = replicate n 0
  where
    subperiod = n `quot` k
    side = a : replicate (subperiod - 1) 0


-- | The list obtained by adding two polygons pointwise when in the same @n@-space.
polygonPatternSum :: Polygon -> Polygon -> Maybe (Pattern Int)
polygonPatternSum p1@(Polygon n _ _) p2@(Polygon n' _ _) =
  if n == n'
    then Just $ patternSum pttrn1 pttrn2
    else Nothing
  where
    pttrn1 = polygonPattern p1
    pttrn2 = polygonPattern p2
    patternSum = zipWith (+)

-- | The list obtained by adding two weighted polygons pointwise in a @n@-space
-- with adjusted granularity.
wPolygonPatternSum :: (Scalar, Polygon) -> (Scalar, Polygon) -> Pattern Int
wPolygonPatternSum (a, Polygon n k p) (a', Polygon n' k' p') = patternSum pttrn1 pttrn2
  where
    pttrn1 = wPolygonPattern (a, Polygon grain k position)
    pttrn2 = wPolygonPattern (a', Polygon grain k' position')
    patternSum = zipWith (+)
    grain = lcm n n'
    position =
      let scaleFactor = grain `div` n
       in (p `mod` n) * scaleFactor
    position' =
      let scaleFactor' = grain `div` n'
       in (p' `mod` n') * scaleFactor'


-- | Polygon sum restricted to disjoint polygons in the same @n@-space.
polygonPatternSumRestricted :: Polygon -> Polygon -> Pattern Int
polygonPatternSumRestricted p1@(Polygon n _ _) p2@(Polygon n' _ _) =
  if compatiblePatterns pttrn1 pttrn2
    then patternSum pttrn1 pttrn2
    else []
  where
    pttrn1 = polygonPattern p1
    pttrn2 = polygonPattern p2
    patternSum = zipWith (+)
    compatiblePatterns xs ys =
      n == n' &&
      2 `notElem` patternSum xs ys

disjointPolygonRhythm :: Int -> Onsets -> Onsets -> [Pattern Int]
disjointPolygonRhythm j k l
  | coprimeOnsets && disjointablePatterns =
      let n = j * k * l
          clean = rotationNub . setNub . filter (/= [])
          displacementCombinations = map (polygonPatternSumRestricted (Polygon n k 0) . Polygon n l) [1..(n-1)]
       in clean $ displacementCombinations
  | otherwise = []
    where coprimeOnsets = gcd k l == 1
          disjointablePatterns = j >= 2


-- The following functions use the Data.Set module

-- | Eliminates duplicate entries in a list but forgets original order.
setNub :: Ord a => [a] -> [a]
setNub = Set.toList . Set.fromList

-- | Generates the set of all the patterns rotations
rotationSet :: Ord a => [a] -> Set.Set [a]
rotationSet xs =
  let n = length xs
  in Set.fromList $ map (\a -> rotateLeft a xs) [0..(n-1)]

-- | Equivalence relation based on
equivModRotation :: Ord a => [a] -> [a] -> Bool
equivModRotation xs ys = ys `Set.member` rotationSet xs

rotationNub :: Ord a => [[a]] -> [[a]]
rotationNub [] = []
rotationNub [x] = [x]
rotationNub (x:y:xs) = if equivModRotation x y
                     then y:rotationNub xs
                     else x:y:rotationNub xs
