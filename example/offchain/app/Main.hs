module Main (main) where

import Control.Monad.Reader (ReaderT, ask)
import Data.Default (Default (def))
import Data.Fixed (Fixed (MkFixed), Micro)
import System.FilePath ((</>))

import Test.Plutip.Internal.BotPlutusInterface.Run (runContract)
import Test.Plutip.Internal.BotPlutusInterface.Wallet (walletPkh)
import Test.Plutip.Internal.Types (
  ClusterEnv,
  ExecutionResult (ExecutionResult),
  FailureReason (CaughtException, ContractExecutionError),
 )
import Test.Plutip.LocalCluster (
  BpiWallet,
  addSomeWallet,
  startCluster,
  stopCluster,
  waitSeconds,
 )

import Ledger (PaymentPubKeyHash (PaymentPubKeyHash))
import Ply (readTypedScript)
import qualified Ply

import Example.Nft (
  MintParams (
    MintParams,
    mpDescription,
    mpName,
    mpPubKeyHash,
    mpTokenName
  ),
  mintNft,
 )

main :: IO ()
main = do
  -- Start the node.
  (clusterStat, (cEnv, ownWallet)) <- startCluster def setup
  nftMp <- readTypedScript $ "../" </> "compiled" </> "nftMp.plutus"

  -- Print the Plutus ledger version used by the minting policy.
  putStr "NFT Minting Policy version: "
  print $ Ply.getPlutusVersion nftMp

  -- Do stuff.
  ExecutionResult exOutcome _ _ _ <-
    runContract cEnv ownWallet $
      mintNft nftMp $
        MintParams
          { mpName = "exampleNFT"
          , mpDescription = Nothing
          , mpTokenName = "NFTA"
          , mpPubKeyHash = PaymentPubKeyHash $ walletPkh ownWallet
          }
  case exOutcome of
    Left (ContractExecutionError e) -> putStrLn "Contract failed" >> print e
    Left (CaughtException e) -> putStrLn "Unexpected exception" >> print e
    Right _ -> putStrLn "Contract ran successfully"

  -- Stop the node.
  stopCluster clusterStat
  where
    setup :: ReaderT ClusterEnv IO (ClusterEnv, BpiWallet)
    setup = do
      env <- ask
      -- Gotta have all those utxos for the collaterals.
      ownWallet <- addWalletWithAdas $ 100 : replicate 20 10
      -- Wait for faucet funds to be added.
      waitSeconds 2
      pure (env, ownWallet)

    addWalletWithAdas :: [Ada] -> ReaderT ClusterEnv IO BpiWallet
    addWalletWithAdas = addSomeWallet . map (fromInteger . toLovelace)

-- | Ada represented with a 'Micro' value.
newtype Ada = Ada Micro
  deriving stock (Eq, Ord, Show)
  deriving newtype (Num)

-- | Convert Ada amount to its corresponding Lovelace unit.
toLovelace :: Ada -> Integer
toLovelace (Ada (MkFixed i)) = i
