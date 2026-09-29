import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:web3dart/crypto.dart' as crypto;

class TransactionService {
  final String nodeBackendUrl = 'https://penalty-snowdrift-managing.ngrok-free.dev'; 

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

    final signedBytes = await ethClient.signTransaction(
      credentials,
      transaction,
      chainId: 1, 
    );
    final signedHex = '0x${crypto.bytesToHex(signedBytes)}';

    return await _broadcastToNode(signedHex, 'evm');
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
    
    // DEMANDS the 'config:' label
    final blockchainConfig = bdk.BlockchainConfig.electrum(config: electrumConfig);
    
    // ERROR 1 FIXED: create() DEMANDS the 'config:' label (0 positional allowed)
    final blockchain = await bdk.Blockchain.create(config: blockchainConfig);
    
    // ERROR 2 FIXED: sync() FORBIDS labels (1 positional required)
    await bdkWallet.sync(blockchain);

    final txBuilder = bdk.TxBuilder();
    
    final addressInfo = await bdk.Address.create(address: toAddress);
    final scriptPubKey = await addressInfo.scriptPubKey(); 
    
    final builtTx = await txBuilder
        .addRecipient(scriptPubKey, amountInSats)
        .feeRate(1.5) 
        .finish(bdkWallet);

    final signedTx = await bdkWallet.sign(psbt: builtTx.psbt);
    
    final tx = await signedTx.extractTx();
    final txBytes = await tx.serialize();
    final signedHex = crypto.bytesToHex(txBytes);

    return await _broadcastToNode(signedHex, 'btc');
  }

  /// --- THE COURIER NETWORK CALL ---
  Future<String> _broadcastToNode(String signedHex, String chain) async {
    final url = Uri.parse('$nodeBackendUrl/api/broadcast/$chain');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true', 
      },
      body: jsonEncode({'signedTx': signedHex}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['hash'] ?? data['txid']; 
    } else {
      throw Exception('Node Backend Broadcast Failed: ${response.body}');
    }
  }
}