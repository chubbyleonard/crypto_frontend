import 'package:bdk_flutter/bdk_flutter.dart';

class BitcoinService {
  // Dart Futures used as initialization locks
  static Future<Wallet>? _walletInitialization;
  static Future<Blockchain>? _blockchainInitialization;

  // ==========================================
  // 1. Initialize the BDK Wallet (Concurrency-Safe)
  // ==========================================
  static Future<Wallet> _getWallet(String seedPhrase) {
    // The null-coalescing assignment (??=) locks the initialization.
    // If called simultaneously, both UI requests await the exact same FFI process.
    _walletInitialization ??= _buildWallet(seedPhrase);
    return _walletInitialization!;
  }

  static Future<Wallet> _buildWallet(String seedPhrase) async {
    final mnemonic = await Mnemonic.fromString(seedPhrase);
    
    final secretKey = await DescriptorSecretKey.create(
      network: Network.Bitcoin,
      mnemonic: mnemonic,
    );

    final externalDescriptor = await Descriptor.newBip84(
      secretKey: secretKey,
      network: Network.Bitcoin,
      keychain: KeychainKind.External,
    );

    final internalDescriptor = await Descriptor.newBip84(
      secretKey: secretKey,
      network: Network.Bitcoin,
      keychain: KeychainKind.Internal,
    );

    return await Wallet.create(
      descriptor: externalDescriptor,
      changeDescriptor: internalDescriptor,
      network: Network.Bitcoin,
      databaseConfig: const DatabaseConfig.memory(),
    );
  }

  // ==========================================
  // 2. Connect to Blockchain (Concurrency-Safe)
  // ==========================================
  static Future<Blockchain> _getBlockchain() {
    _blockchainInitialization ??= _buildBlockchain();
    return _blockchainInitialization!;
  }

  static Future<Blockchain> _buildBlockchain() async {
    return await Blockchain.create(
      config: BlockchainConfig.electrum(
        config: const ElectrumConfig(
          url: 'ssl://electrum.blockstream.info:50002',
          retry: 5,
          timeout: 5,
          stopGap: 10,
          validateDomain: true,
        ),
      ),
    );
  }

  // ==========================================
  // 3. Get Public Address
  // ==========================================
  static Future<String> getPublicAddress(String seedPhrase) async {
    try {
      final wallet = await _getWallet(seedPhrase);
      final addressInfo = await wallet.getAddress(addressIndex: const AddressIndex.new());
      return addressInfo.address;
    } catch (e) {
      throw Exception('Failed to generate Bitcoin address: $e');
    }
  }

  // ==========================================
  // 4. Fetch On-Chain Balance
  // ==========================================
  static Future<double> getBalance(String seedPhrase) async {
    try {
      final wallet = await _getWallet(seedPhrase);
      final blockchain = await _getBlockchain();

      // Sync the wallet's transaction history with the public ledger
      await wallet.sync(blockchain);

      final balance = await wallet.getBalance();
      return balance.total / 100000000;
    } catch (e) {
      throw Exception('Failed to fetch Bitcoin balance: $e');
    }
  }

  // ==========================================
  // 5. Reset State (Call this if the user logs out)
  // ==========================================
  static void clearSession() {
    _walletInitialization = null;
    _blockchainInitialization = null;
  }
}