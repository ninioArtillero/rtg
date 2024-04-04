module Sound.RTG.Ritmo.PatronRegular where

-- Ritmos euclideanos utilizando un redondeo modular
-- Esta aproximación es una adaptación del trabajo final con Mauricio Rodriguez

{-@ assume fromInteger :: Num a => {x : Integer | x /= 0} -> {y : a | y /= 0} @-}

{-@ patronRegular :: { pulses : Integer | pulses > 0} -> { onsets : Integer | onsets >= pulses} -> { xs : [Integer] | len xs > 0 }@-}
patronRegular :: Integer -> Integer -> [Integer]
patronRegular pulses events =
  let p' = fromInteger pulses :: Rational
      e' = fromInteger events :: Rational
      step = e' / p'
      stepList = map round [0, step ..]
   in takeWhile (< events) stepList

rotation :: Int -> Int -> [Int] -> [Int]
rotation amount events = map ((`mod` events) . (+ amount))
