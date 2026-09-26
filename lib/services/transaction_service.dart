import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:bdk_flutter/bdk_flutter.dart';

class TransactionService {
  // Your authenticated, permanent ngrok tunnel domain
  final String nodeBackendUrl = 'https://penalty-snowdrift-managing.ngrok-free.dev'; 

  /// --- EVM (Ethereum) WITHDRAWAL ---
  Future<String> withdrawEth({
    required String privateKeyHex,
    required String toAddress,
    required double amountInEth,
    required Web3Client ethClient,
  }) async {
    // 1. Load the Vault keys in memory
    final credentials = EthPrivateKey.fromHex(privateKeyHex);
    final receiver = EthereumAddress.fromHex(toAddress);

    // 2. Build the transaction
    final amountInWei = BigInt.from(amountInEth * 1e18);
    final transaction = Transaction(
      to: receiver,
      value: EtherAmount.inWei(amountInWei),
      maxGas: 21000, 
    );

    // 3. Sign mathematically on the iPhone
    final signedBytes = await ethClient.signTransaction(
      credentials,
      transaction,
      chainId: 1, 
    );
    final signedHex = '0x${bytesToHex(signedBytes)}';

    // 4. Send the locked hex to the Node.js Courier
    return await _broadcastToNode(signedHex, 'evm');
  }

  /// --- NATIVE BITCOIN WITHDRAWAL ---
  Future<String> withdrawBtc({
    required Wallet bdkWallet,
    required String toAddress,
    required int amountInSats,
  }) async {
    // 1. Sync the wallet to fetch available UTXOs
    await bdkWallet.sync(
      blockchain: Blockchain.create(
        network: Network.Bitcoin,
        config: BlockchainConfig.electrum(
          config: ElectrumConfig(
            url: 'ssl://electrum.blockstream.info:50002',
            retry: 5,
          ),
        ),
      ),
    );

    // 2. Build the transaction structure
    final txBuilder = TxBuilder();
    final scriptPubKey = await Address.create(address: toAddress).scriptPubKey();
    final builtTx = await txBuilder
        .addRecipient(scriptPubKey, amountInSats)
        .feeRate(1.5) // sat/vbyte
        .finish(bdkWallet);

    // 3. Sign mathematically on the iPhone using the un-stripped Rust bridge
    final signedTx = await bdkWallet.sign(psbt: builtTx.psbt);
    final signedHex = await signedTx.extractTx();

    // 4. Send the locked hex to the Node.js Courier
    return await _broadcastToNode(signedHex, 'btc');
  }

  /// --- THE COURIER NETWORK CALL ---
  Future<String> _broadcastToNode(String signedHex, String chain) async {
    final url = Uri.parse('$nodeBackendUrl/api/broadcast/$chain');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        // Commands ngrok to bypass the interactive HTML warning screen 
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