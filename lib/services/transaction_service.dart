import 'package:web3dart/web3dart.dart' as web3;
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class TransactionService {
  
  /// --- EVM (Ethereum) WITHDRAWAL ---
  Future<String> withdrawEth({
    required String privateKeyHex,
    required String toAddress,
    required double amountInEth,
    required web3.Web3Client ethClient,
  }) async {
    final credentials = web3.EthPrivateKey.fromHex(privateKeyHex);
    final receiver = web3.EthereumAddress.fromHex(toAddress);

    final amountInWei = BigInt.from(amountInEth * 1e18);
    final transaction = web3.Transaction(
      to: receiver,
      value: web3.EtherAmount.inWei(amountInWei),
      maxGas: 21000, 
    );

    // 1. Sign the transaction locally on the iPhone
    final signedBytes = await ethClient.signTransaction(
      credentials,
      transaction,
      chainId: 1, 
    );
    
    // 2. 🟢 DIRECT BROADCAST (No Node.js Backend Needed)
    // Sends the raw transaction directly to the EVM network
    final txHash = await ethClient.sendRawTransaction(signedBytes);
    
    // Returns the Transaction ID for the UI receipt
    return txHash; 
  }

  /// --- NATIVE BITCOIN WITHDRAWAL ---
  Future<String> withdrawBtc({
    required bdk.Wallet bdkWallet,
    required String toAddress,
    required int amountInSats,
  }) async {
    final electrumConfig = bdk.ElectrumConfig(
      url: 'ssl://electrum.blockstream.info:50002', 
      retry: 5,
      stopGap: 20,
      timeout: 5,
      validateDomain: true,
    );
    
    final blockchainConfig = bdk.BlockchainConfig.electrum(config: electrumConfig);
    final blockchain = await bdk.Blockchain.create(config: blockchainConfig);
    
    await bdkWallet.sync(blockchain);

    final txBuilder = bdk.TxBuilder();
    
    final addressInfo = await bdk.Address.create(address: toAddress);
    final scriptPubKey = await addressInfo.scriptPubKey(); 
    
    final builtTx = await txBuilder
        .addRecipient(scriptPubKey, amountInSats)
        .feeRate(1.5) 
        .finish(bdkWallet);

    // 1. Sign the transaction locally on the iPhone
    final signedTx = await bdkWallet.sign(psbt: builtTx.psbt);
    final tx = await signedTx.extractTx();
    
    // 2. 🟢 DIRECT BROADCAST (No Node.js Backend Needed)
    // Sends the signed transaction directly to Blockstream's live node
    await blockchain.broadcast(tx);
    
    // Extract and return the TXID for the UI receipt
    return await tx.txid(); 
  }
}