module Main where

import System.IO
import Codexpand

main :: IO()
main = do
    c <- getContents
    sequence_ (actionize (parse c))
