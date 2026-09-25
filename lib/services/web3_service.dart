import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'package:hex/hex.dart';

class Web3Service {
  // Swapped to a dedicated, keyless public node
  static const String rpcUrl = 'https://ethereum-rpc.publicnode.com';
  static final Web3Client _client = Web3Client(rpcUrl, http.Client());

  // ==========================================
  // 1. Convert Seed Phrase to Private Key
  // ==========================================
  static String getPrivateKeyFromSeed(String mnemonic) {
    // 1. Verify it is a valid 12 or 24-word phrase
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid seed phrase.');
    }

    // 2. Convert mnemonic to a binary seed
    final seed = bip39.mnemonicToSeed(mnemonic);

    // 3. Create a master node from the seed
    final root = bip32.BIP32.fromSeed(seed);

    // 4. Derive the standard Ethereum path (m/44'/60'/0'/0/0)
    final child = root.derivePath("m/44'/60'/0'/0/0");

    // 5. Extract and format the private key as a Hex string
    final privateKeyBytes = child.privateKey!;
    return HEX.encode(privateKeyBytes);
  }

  // ==========================================
  // 2. Get Public Address from Private Key
  // ==========================================
  static Future<String> getPublicAddress(String privateKeyHex) async {
    final credentials = EthPrivateKey.fromHex(privateKeyHex);
    final address = await credentials.extractAddress();
    return address.hexEip55; // Returns standard 0x... format
  }

  // ==========================================
  // 3. Fetch On-Chain Balance
  // ==========================================
  static Future<double> getBalance(String walletAddress) async {
    try {
      final address = EthereumAddress.fromHex(walletAddress);
      final balance = await _client.getBalance(address);
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      throw Exception('Failed to fetch blockchain balance: $e');
    }
  }

  // ==========================================
  // 4. Execute Self-Custody Transfer
  // ==========================================
  static Future<String> sendFunds({
    required String privateKeyHex,
    required String destinationAddress,
    required double amountInEth,
  }) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKeyHex);
      final receiver = EthereumAddress.fromHex(destinationAddress);
      final amountInWei = BigInt.from(amountInEth * pow(10, 18));

      final transaction = Transaction(
        to: receiver,
        value: EtherAmount.inWei(amountInWei),
      );

      final txHash = await _client.sendTransaction(
        credentials,
        transaction,
        chainId: 1, // Ethereum Mainnet
      );

      return txHash;
    } catch (e) {
      throw Exception('Blockchain transaction failed: $e');
    }
  }
}