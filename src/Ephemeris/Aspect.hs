{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE RecordWildCards #-}
module Ephemeris.Aspect where

import Import
import Utils
import Ephemeris.Types
import RIO.List (headMaybe)
import Ephemeris.Utils (isRetrograde)

majorAspects :: [Aspect]
majorAspects =
    [ Aspect{ aspectType = Major, aspectName = Conjunction, angle = 0.0, maxOrb = 10.0, temperament = Synthetic }
    , Aspect{ aspectType = Major, aspectName = Sextile, angle = 60.0, maxOrb = 6.0, temperament = Synthetic }
    , Aspect{ aspectType = Major, aspectName = Square, angle = 90.0, maxOrb = 10.0, temperament = Analytical }
    , Aspect{ aspectType = Major, aspectName = Trine, angle = 120.0, maxOrb = 10.0, temperament = Synthetic }
    , Aspect{ aspectType = Major, aspectName = Opposition, angle = 180.0, maxOrb = 10.0, temperament = Analytical }
    ]


minorAspects :: [Aspect]
minorAspects =
    [ Aspect { aspectType = Minor, aspectName = SemiSquare, angle = 45.0, maxOrb = 3.0, temperament = Analytical }
    , Aspect { aspectType = Minor, aspectName = Sesquisquare, angle = 135.0, maxOrb = 3.0, temperament = Analytical }
    , Aspect { aspectType = Minor, aspectName = SemiSextile, angle = 30.0, maxOrb = 3.0, temperament = Neutral }
    , Aspect { aspectType = Minor, aspectName = Quincunx, angle = 150.0, maxOrb = 3.0, temperament = Neutral }
    , Aspect { aspectType = Minor, aspectName = Quintile, angle = 72.0, maxOrb = 2.0, temperament = Synthetic }
    , Aspect { aspectType = Minor, aspectName = BiQuintile, angle = 144.0, maxOrb = 2.0, temperament = Synthetic }
    ]

defaultAspects :: [Aspect]
defaultAspects = majorAspects <> minorAspects

-- | Calculate aspects to use for transit insights.
-- Note that we use the default orbs.
-- However, to consider the aspect "active", we use a smaller orb, of 1 degree.
-- cf.: https://www.astro.com/astrowiki/en/Transit
aspectsForTransits :: [Aspect]
aspectsForTransits = defaultAspects-- map (\a -> a{maxOrb = 5.0}) majorAspects

aspects' :: (HasLongitude a, HasLongitude b) => [Aspect] -> [a] -> [b] -> [HoroscopeAspect a b]
aspects' possibleAspects bodiesA bodiesB =
  concatMap aspectsBetween pairs & catMaybes
  where
    pairs = [(x, y) | x <- bodiesA, y <- bodiesB]
    aspectsBetween bodyPair = map (haveAspect bodyPair) possibleAspects
    haveAspect (a, b) asp@Aspect {} =
      findAspectAngle asp a b <&> HoroscopeAspect asp (a,b)


aspects :: (HasLongitude a, HasLongitude b) => [a] -> [b] -> [HoroscopeAspect a b]
aspects = aspects' defaultAspects

-- | calculate aspects between the same set of planets. Unlike `transitingAspects`, don't
-- keep aspects of a planet with itself.
planetaryAspects :: [PlanetPosition] -> [HoroscopeAspect PlanetPosition PlanetPosition]
planetaryAspects ps = filter (\a -> uncurry (/=) (a & bodies)) $ aspects ps $ rotateList 1 ps

celestialAspects :: [PlanetPosition] -> Angles -> [HoroscopeAspect PlanetPosition House]
celestialAspects ps as = aspects ps (aspectableAngles as)

aspectableAngles :: Angles -> [House]
aspectableAngles Angles {..} = [House I (Longitude ascendant) 0, House X (Longitude mc) 0]

-- TODO(luis) should this exist? Should we just use normal majorAspects, or even the default
-- aspects? The only benefit here is that many aspects with bigger orbs are discarded
-- outright and as such we don't need to go calculate their activity (which has an IO cost,
-- at the DB,) but it does mean fewer aspects are shown when using this than in
-- e.g. the chart of the moment. On the other hand, it's less sifting through "inactive" aspects.
transitingAspects :: (HasLongitude a, HasLongitude b) => [a] -> [b] -> [HoroscopeAspect a b]
transitingAspects = aspects' aspectsForTransits

-- | Given a list of aspects, keep only major aspects.
-- useful as a helper when plotting/showing tables.
selectMajorAspects :: [HoroscopeAspect a b] -> [HoroscopeAspect a b]
selectMajorAspects = filter ((== Major) . aspectType . aspect)

-- | Select aspects with an orb of at most 1 degree. Useful for plotting.
selectExactAspects :: [HoroscopeAspect a b] -> [HoroscopeAspect a b]
selectExactAspects = filter ((<= 1) . orb)

-- TODO(luis): have even fancier select*aspects heuristics? Maybe
-- something like "only select applying aspects with orb smaller than X,
-- or separating aspects with orb smaller than Y?"
selectSignificantAspects :: [HoroscopeAspect a b] -> [HoroscopeAspect a b]
selectSignificantAspects = selectExactAspects

-- TODO(luis): these find* functions are _so_ wasteful. We could clearly do it in one pass vs. traverse the whole
-- list for each planet. However, I always find myself updating this file at midnight when my neurons are
-- not ready for the magic.
findAspectBetweenPlanets :: [HoroscopeAspect PlanetPosition PlanetPosition] -> Planet -> Planet -> Maybe (HoroscopeAspect PlanetPosition PlanetPosition)
findAspectBetweenPlanets aspectList pa pb =
  aspectList
    & filter (\HoroscopeAspect {..} -> bimap planetName planetName bodies `elem` [(pa, pb), (pb, pa)])
    & headMaybe

findAspectWithPlanet :: [PlanetaryAspect] -> Planet -> Planet -> Maybe PlanetaryAspect
findAspectWithPlanet aspectList aspecting aspected =
  aspectList
    & filter (\HoroscopeAspect {..} -> bimap planetName planetName bodies == (aspecting, aspected))
    & headMaybe

findAspectWithAngle :: [HoroscopeAspect PlanetPosition House] -> Planet -> HouseNumber -> Maybe (HoroscopeAspect PlanetPosition House)
findAspectWithAngle aspectList pa hb =
  aspectList
    & filter (\HoroscopeAspect {..} -> bimap planetName houseNumber bodies == (pa, hb))
    & headMaybe

findAspectsByName :: [HoroscopeAspect a b] -> AspectName -> [HoroscopeAspect a b]
findAspectsByName aspectList name =
  aspectList
    & filter (\HoroscopeAspect {..} -> (aspect & aspectName) == name)

findAspectAngle :: (HasLongitude a, HasLongitude b) => Aspect -> a -> b -> Maybe AspectAngle
findAspectAngle aspect aspecting aspected =
  aspectAngle' aspect aspecting                        aspected <|>
  aspectAngle' aspect (aspecting `addLongitude` 360)   aspected <|>
  aspectAngle' aspect aspecting                        (aspected `addLongitude` 360)

aspectAngle' :: (HasLongitude a, HasLongitude b) => Aspect -> a -> b -> Maybe AspectAngle
aspectAngle' Aspect{..} aspecting aspected =
  if inOrb then
    case (compare (getLongitude aspecting) (getLongitude aspected), compare angleDiff angle) of
      (LT, GT) -> mkAngle Applying
      (LT, LT) -> mkAngle Separating
      (_, EQ)  -> mkAngle Exact
      (EQ, _)  -> mkAngle Exact
      (GT, GT) -> mkAngle Separating
      (GT, LT) -> mkAngle Applying
  else
    Nothing
  where
    mkAngle    = Just . (\phase -> AspectAngle aspecting' aspected' phase orb')
    aspecting' = EclipticAngle $ getLongitudeRaw aspecting
    aspected'  = EclipticAngle $ getLongitudeRaw aspected
    angleDiff = abs $ getLongitudeRaw aspecting - getLongitudeRaw aspected
    orb' = abs $ angle - angleDiff
    inOrb = orb' <= maxOrb

toLongitude :: EclipticAngle -> Longitude
toLongitude (EclipticAngle e)
  | e > 360   = Longitude . abs $ 360 - e
  | e == 360  = Longitude 0
  | e < 0     = Longitude . abs $ 360 + e
  | otherwise = Longitude e

exactAngle :: HoroscopeAspect a b -> Longitude
exactAngle aspect' =
  case aspectAngleApparentPhase angle' of
    Applying   -> EclipticAngle (aspecting' + orb') & toLongitude
    Separating -> EclipticAngle (aspecting' - orb') & toLongitude
    Exact      -> a & toLongitude
  where
    angle' = aspectAngle aspect'
    orb'   = aspectAngleOrb angle'
    a@(EclipticAngle aspecting') = aspectingPosition angle'

currentAngle :: HoroscopeAspect a b -> EclipticAngle
currentAngle HoroscopeAspect{..} =
  abs $ (aspectAngle & aspectingPosition) - (aspectAngle & aspectedPosition)


orb :: HoroscopeAspect a b -> Double
orb  = aspectAngleOrb . aspectAngle

aspectPhase :: TransitAspect a -> AspectPhase
aspectPhase asp =
  if aspectingIsRetrograde then
    flipPhase $ aspectAngleApparentPhase angle'
  else
    aspectAngleApparentPhase angle'
  where
    flipPhase Applying = Separating
    flipPhase Separating = Applying
    flipPhase Exact = Exact
    angle' = aspectAngle asp
    aspectingIsRetrograde = asp & bodies & fst & isRetrograde
