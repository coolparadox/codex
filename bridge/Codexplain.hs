module Codexplain (explain) where

import qualified Data.Map as Map

explain :: String -> (String, String)
explain input = (explanation, extrusion) where
    explanation = explainDocument document
    extrusion = extrudeDocument document
    document = parse input

data Document = MakeDocument Statistics [Block] deriving Show

data Statistics = MakeStatistics (Map.Map String Int) deriving Show

data Block =
    RawBlock [String] |
    CommentBlock [String] |
    CodeFileBlock String Int [String] deriving Show

parse :: String -> Document
parse str = MakeDocument statistics promoted_blocks where
    (promoted_blocks, statistics) = promoteCommentBlocks blocks (MakeStatistics Map.empty)
    blocks = parseLowLevel $ lines str

promoteCommentBlocks :: [Block] -> Statistics -> ([Block], Statistics)
promoteCommentBlocks [] stat = ([], stat)
promoteCommentBlocks (block:blocks) stat = (promoted_block:promoted_blocks, updated_stat) where
    (promoted_block, promoted_stat) = promoteCommentBlock block stat
    (promoted_blocks, updated_stat) = promoteCommentBlocks blocks promoted_stat

promoteCommentBlock :: Block -> Statistics -> (Block, Statistics)
promoteCommentBlock block@(CommentBlock (x:xs)) stat
    | take 2 x == "//" = promoteToCodeFileBlock (drop 2 x) xs stat
    | otherwise = (block, stat)
promoteCommentBlock block stat = (block, stat)

promoteToCodeFileBlock :: String -> [String] -> Statistics -> (Block, Statistics)
promoteToCodeFileBlock path content (MakeStatistics codefile_map) = (block, MakeStatistics new_map) where
    block = CodeFileBlock path count content
    (m_count, new_map) = Map.insertLookupWithKey incrementStatistic path 1 codefile_map
    count = countFromMaybe m_count

countFromMaybe :: Maybe Int -> Int
countFromMaybe (Just n) = n + 1
countFromMaybe _ = 1

incrementStatistic :: String -> Int -> Int -> Int
incrementStatistic _ _ value = value + 1

explainDocument :: Document -> String
explainDocument (MakeDocument _ []) = ""
explainDocument (MakeDocument stat (block:blocks)) = (explainBlock block) ++ (explainDocument (MakeDocument stat blocks))

explainBlock :: Block -> String
explainBlock (RawBlock strs) = unlines strs
explainBlock (CommentBlock strs) = "////\n" ++ unlines strs ++ "////\n"
explainBlock (CodeFileBlock path count content) = "FILE " ++ path ++ " " ++ show count ++ "\n"

parseLowLevel :: [String] -> [Block]
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

extrudeDocument :: Document -> String
extrudeDocument _ = "extrusion\n"
