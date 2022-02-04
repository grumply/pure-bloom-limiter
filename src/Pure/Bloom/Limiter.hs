{-# language OverloadedStrings #-}
module Pure.Bloom.Limiter (allowedWith,allowed,limitWith,limit,testLimiter) where

import Pure.Bloom.Scalable
import Pure.Data.Time
import Pure.Data.Txt

import Control.Concurrent
import Control.Monad
import Data.IORef
import Data.Typeable
import System.IO.Unsafe

import Data.Foldable

import qualified Data.Map as Map

{-# NOINLINE limiters #-}
limiters :: IORef (Map.Map Txt Bloom)
limiters = unsafePerformIO (newIORef Map.empty)

limiterWith :: Double -> Txt -> Time -> IO Bloom
limiterWith e nm d = do
  ls <- readIORef limiters
  case Map.lookup nm ls of
    Just b -> pure b
    Nothing -> do
      b <- bloom e
      join $ atomicModifyIORef' limiters $ \ls -> 
        -- just in case; we don't want two watchers
        case Map.lookup nm ls of
          Nothing -> (Map.insert nm b ls,watch >> pure b)
          Just b  -> (ls,pure b)
  where
    watch = forkIO $ do
      forever $ do
        delay d 
        reset

    reset = do
      b <- bloom e
      atomicModifyIORef' limiters $ \ls -> 
        (Map.insert nm b ls,())

-- Test 1, then max, then binary search 2 through max-1
allowedWith :: Double -> Int -> Txt -> Time -> IO Bool
allowedWith e max action d = do
  l <- limiterWith e action d
  empty <- update l (a 1)
  if empty then
    pure True
  else do
    full <- test l (a max)
    if full then 
      pure False
    else 
      go 2 max l
  where
    a :: Int -> Txt
    a n = action <> "_" <> toTxt n

    -- a binary search for the first empty slot between lo and hi
    go :: Int -> Int -> Bloom -> IO Bool
    go lo hi b
      | lo >= hi = update b (a hi)
      | otherwise = do
        let mid = (lo + hi) `div` 2
        test b (a mid) >>= \found ->
          if found 
          then go (mid + 1) hi b
          else go lo mid b

allowed :: Int -> Txt -> Time -> IO Bool
allowed = allowedWith 0.001

limitWith :: Double -> Int -> Txt -> Time -> IO a -> IO (Maybe a)
limitWith e max action d ioa = do
  allow <- allowedWith e max action d
  if allow then
    Just <$> ioa
  else
    pure Nothing

limit :: Int -> Txt -> Time -> IO a -> IO (Maybe a)
limit = limitWith 0.001