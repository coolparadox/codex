module Codexpand where

import System.IO

data CodexBlock =
    RawBlock [String] |
    CommentBlock [String] |
    IncludeBlock String deriving Show

parse :: String -> [CodexBlock]
parse str = parseHighLevel(parseLowLevel (lines str))

parseLowLevel :: [String] -> [CodexBlock]
parseLowLevel [] = []
parseLowLevel ("////":xs) = (CommentBlock ls):blocks where
    (ls, lss) = seekCommentEnd [] xs
    blocks = parseLowLevel lss
parseLowLevel (x:xs) = (RawBlock (x:ls)):blocks where
    (ls, lss) = seekCommentBegin [] xs
    blocks = parseLowLevel lss

seekCommentBegin :: [String] -> [String] -> ([String], [String])
seekCommentBegin acc [] = (acc, [])
seekCommentBegin acc xs@("////":_) = (acc, xs)
seekCommentBegin acc (x:xs) = seekCommentBegin (acc ++ [x]) xs

seekCommentEnd :: [String] -> [String] -> ([String], [String])
seekCommentEnd acc [] = (acc, [])
seekCommentEnd acc ("////":xs) = (acc, xs)
seekCommentEnd acc (x:xs) = seekCommentEnd (acc ++ [x]) xs

parseHighLevel :: [CodexBlock] -> [CodexBlock]
parseHighLevel [] = []
parseHighLevel ((CommentBlock ["///include", path]):xs) = (IncludeBlock path):(parseHighLevel xs)
parseHighLevel (x:xs) = x:(parseHighLevel xs)

actionize :: [CodexBlock] -> [IO ()]
actionize [] = []
actionize ((IncludeBlock path):xs) = action:(actionize xs) where
    action = do
        h <- openFile path ReadMode
        c <- hGetContents h
        sequence_ (actionize (parse c))
        hClose h
actionize ((RawBlock ls):xs) = (putStr (unlines ls)):(actionize xs)
actionize ((CommentBlock ls):xs) = action:(actionize xs) where
    action = do
        putStrLn "////"
        sequence_ (map putStrLn ls)
        putStrLn "////"

