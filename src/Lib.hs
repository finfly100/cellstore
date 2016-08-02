{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RecordWildCards       #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeFamilyDependencies #-}
-- {-# LANGUAGE AllowAmbiguousTypes #-}

module Lib
    ( someFunc
    ) where

import qualified Data.Bson              as Bson
import           Data.Map               (Map)
import           Data.Proxy             (Proxy (Proxy))
import           Data.Text              (Text)
import qualified Data.Text              as Text

import           Control.Monad.IO.Class (MonadIO, liftIO)

-- mongo backend

import qualified Database.MongoDB       as Mongo
import           Database.MongoDB.Query (AccessMode, master)

someFunc :: IO ()
someFunc = putStrLn "someFunc"

-- cellstore mongodb backend

type DbHost = Text
type DbName = Text

mkCellStoreMongoDb :: MonadIO m
                  => DbName
                  -> DbHost
                  -> AccessMode
                  -> m (CellStore MongoBackend)
mkCellStoreMongoDb name host accessMode = do
    pipe <- liftIO $ Mongo.connect $ Mongo.host (Text.unpack host)
    pure $ CellStore MongoBackend
      { mbPipe       = pipe
      , mbDbName     = name
      , mbAccessMode = accessMode
      }

data MongoBackend = MongoBackend
  { mbPipe       :: Mongo.Pipe
  , mbDbName     :: DbName
  , mbAccessMode :: AccessMode
  }

class CellStoreBackend backend where
  type DbValueType backend = c | c -> backend
  put :: MonadIO m
      => backend -> Map Dimension DimValue -> DbValueType backend -> m ()

instance CellStoreBackend MongoBackend where
  type DbValueType MongoBackend = Bson.Document
  put MongoBackend{..} dims value = undefined

-- cellstore interface

data CellStore a where
  CellStore :: CellStoreBackend a => a -> CellStore a

class CellStoreBackend backend => Cell backend a where
    mkValue :: a -> DbValueType backend
    dimensions :: Proxy backend -> a -> Map Dimension DimValue

putCell :: (MonadIO m, Cell backend a)
        => CellStore backend -> a -> m ()
putCell (CellStore db) c = put db (dimensions (Proxy :: backend) c) (mkValue c)

-- cellstore types

type Dimension = Text
type DimValue = Text
