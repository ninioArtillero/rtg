module Sound.RTG.Ritmo.PatronRegular where

-- Ritmos euclideanos utilizando un redondeo modular
-- Esta aproximación es una adaptación del trabajo final con Mauricio Rodriguez

{-@ patronRegular :: Nat -> {n : Nat | n /= 0} -> [Nat] @-}
patronRegular :: Int -> Int -> [Int]
patronRegular pulses events =
  let p' = fromIntegral pulses :: Rational
      e' = fromIntegral events :: Rational
      step = e' / p'
      stepList = map round [0, step ..]
   in takeWhile (< events) stepList

rotation :: Int -> Int -> [Int] -> [Int]
rotation amount events = map ((`mod` events) . (+ amount))
