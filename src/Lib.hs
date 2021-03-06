{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs            #-}
{-# LANGUAGE TypeFamilies     #-}
{-# LANGUAGE TypeOperators     #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OverloadedLists #-}
{-# LANGUAGE InstanceSigs #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE TypeInType #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fno-warn-unticked-promoted-constructors #-}


module Lib where

import           GHC.TypeLits (KnownSymbol, symbolVal, Symbol)
import           Data.Kind (Type)
import           Data.Void (Void)

import           Data.Proxy             (Proxy (Proxy))
import           Data.Text              (Text)
import qualified Data.Text              as Text

import           Control.Monad.IO.Class (MonadIO, liftIO)

-- types

import           TypeFunctions
import           Types


-- interface

save' :: (MonadIO m, GetAspectsSingle q) => Proxy model -> Proxy q -> CellTypeSingle model q -> m ()
save' Proxy query _ = liftIO . print $ getAspectsSingle query

-- get aspects

symbolText :: KnownSymbol a => Proxy a -> Text
symbolText = Text.pack . symbolVal

class Extractable (a :: k) where
  type Extract (k :: Type) :: Type
  extract :: Proxy (a :: k) -> Extract k

instance KnownSymbol a => Extractable (a :: Symbol) where
  type Extract Symbol = Text
  extract = symbolText

instance (KnownSymbol a, KnownSymbol b) => Extractable ('(a, b) :: (Symbol, Symbol)) where
  type Extract (Symbol, Symbol) = (Text, Text)
  extract _ = (symbolText (Proxy :: Proxy a),
               symbolText (Proxy :: Proxy b))

instance Extractable ('[] :: [a]) where
  type Extract [a] = [Extract a]
  extract _ = []

instance (Extractable x, Extractable xs) => Extractable (x ': xs) where
  type Extract [a] = [Extract a]
  extract _ = extract (Proxy :: Proxy x) : extract (Proxy :: Proxy xs)

-- single

class GetAspectsSingle a where
  getAspectsSingle :: Proxy a -> [(Dimension, DimValue)]

instance (KnownSymbol d, KnownSymbol v, GetAspectsSingle as)
      => GetAspectsSingle (Aspect d v |$ as) where
  getAspectsSingle _ = (symbolText (Proxy :: Proxy d),
                        symbolText (Proxy :: Proxy v))
                         : getAspectsSingle (Proxy :: Proxy as)

instance GetAspectsSingle Nil where
  getAspectsSingle _ = []

-- list

class GetAspectsList query where
  type GetAspectsListType (query :: Type) :: Type
  getAspectsList :: Proxy query -> GetAspectsListType query -> [[(Dimension, DimValue)]]

instance GetAspectsList (a |$ as) where
  type GetAspectsListType (a |$ as) = GetAspectsListType (ExplodeQuery (a |$ as))
  -- getAspectsList :: Proxy (a |$ as) -> GetAspectsListType (a |$ as) -> [[(Dimension, DimValue)]]
  -- getAspectsList Proxy aspects = getAspectsList Proxy Proxy

instance GetAspectsList Nil where
  type GetAspectsListType Nil = Void
  getAspectsList Proxy _ = []

-- there is no query to get cells that have different aspects,
--   i.e. queries run along dimensional values for a given set of dimensions
-- a data point model with cells that differ by the absence of one aspect
--   is discouraged, though it shouldn't lead to problems
-- redundant definition of a data type (e.g. twice the same data type
--    with same aspects but other
--    dimensional values) is nonsensical and should yield a compile error,
--    ideally
-- the data point null (no aspects) currently cannot be used
-- list query: horizontal query results in list
--             vertical queries result in tuples of (Maybe a)
-- singleton query: always result in (Maybe a)
type SimpleModel = Integer $|$ Aspect "foo" '["bor"] |$ Aspect "egon" '["hugo"] |$ Nil
               &&| Double  $|$ Aspect "egon" '["balders", "bolder", "belder"]
                            |$ Aspect "franz" '["frei", "frey"]
                            |$ Nil
               &&| String  $|$ Aspect "egon" '["balders"] |$ Aspect "franz" '["freu"] |$ Nil
               &&| Nil


test :: IO ()
test = save' (Proxy :: Proxy SimpleModel)
             (Proxy :: Proxy (Aspect "egon" "balders"
                           |$ Aspect "franz" "frei"
                           |$ Nil))
             (3 :: Double)
