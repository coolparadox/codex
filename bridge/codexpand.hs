module Main where

import System.IO
import Codex

main :: IO()
main = do
    c <- getContents
    sequence_ (actionize (parse c))
