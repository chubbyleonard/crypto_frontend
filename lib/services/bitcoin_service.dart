import 'package:bdk_flutter/bdk_flutter.dart';

// 🟢 NEW: Enum to support every major Bitcoin address format
enum BitcoinWalletType {
  legacyBip44,       // Addresses starting with '1'
  nestedSegWitBip49, // Addresses starting with '3'
  nativeSegWitBip84, // Addresses starting with 'bc1q'
  taprootBip86       // Addresses starting with 'bc1p'
}

class BitcoinService {
  static Future<Wallet>? _walletInitialization;
  static Future<Blockchain>? _blockchainInitialization;

  // ==========================================
  // 1. Initialize the BDK Wallet (Concurrency-Safe)
  // ==========================================
  static Future<Wallet> _getWallet(
    String seedPhrase, {
    BitcoinWalletType type = BitcoinWalletType.nativeSegWitBip84,
    String passphrase = "",
  }) {
    _walletInitialization ??= _buildWallet(seedPhrase, type, passphrase);
    return _walletInitialization!;
  }

  static Future<Wallet> _buildWallet(
    String seedPhrase, 
    BitcoinWalletType type, 
    String passphrase
  ) async {
    final mnemonic = await Mnemonic.fromString(seedPhrase);
    
    // 🟢 NEW: Supports optional BIP-39 Passphrases (13th/25th word)
    final secretKey = await DescriptorSecretKey.create(
      network: Network.Bitcoin,
      mnemonic: mnemonic,
      password: passphrase, 
    );

    Descriptor externalDescriptor;
    Descriptor internalDescriptor;

    // 🟢 NEW: Dynamic Descriptor Switcher based on the imported wallet type
    switch (type) {
      case BitcoinWalletType.legacyBip44:
        externalDescriptor = await Descriptor.newBip44(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.External,
        );
        internalDescriptor = await Descriptor.newBip44(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.Internal,
        );
        break;
      case BitcoinWalletType.nestedSegWitBip49:
        externalDescriptor = await Descriptor.newBip49(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.External,
        );
        internalDescriptor = await Descriptor.newBip49(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.Internal,
        );
        break;
      case BitcoinWalletType.taprootBip86:
        externalDescriptor = await Descriptor.newBip86(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.External,
        );
        internalDescriptor = await Descriptor.newBip86(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.Internal,
        );
        break;
      case BitcoinWalletType.nativeSegWitBip84:
      default:
        externalDescriptor = await Descriptor.newBip84(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.External,
        );
        internalDescriptor = await Descriptor.newBip84(
          secretKey: secretKey, network: Network.Bitcoin, keychain: KeychainKind.Internal,
        );
        break;
    }

    return await Wallet.create(
      descriptor: externalDescriptor,
      changeDescriptor: internalDescriptor,
      network: Network.Bitcoin,
      databaseConfig: const DatabaseConfig.memory(),
    );
  }

  // ==========================================
  // 2. Connect to Blockchain
  // ==========================================
  static Future<Blockchain> _getBlockchain() {
    _blockchainInitialization ??= _buildBlockchain();
    return _blockchainInitialization!;
  }

  static Future<Blockchain> _buildBlockchain() async {
    return await Blockchain.create(
      config: BlockchainConfig.electrum(
        config: const ElectrumConfig(
          url: 'ssl://electrum.blockstream.info:50002', // Mainnet Port
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
  static Future<String> getPublicAddress(
    String seedPhrase, {
    BitcoinWalletType type = BitcoinWalletType.nativeSegWitBip84,
    String passphrase = "",
  }) async {
    try {
      final wallet = await _getWallet(seedPhrase, type: type, passphrase: passphrase);
      final addressInfo = await wallet.getAddress(addressIndex: const AddressIndex.new());
      return addressInfo.address;
    } catch (e) {
      throw Exception('Failed to generate Bitcoin address: $e');
    }
  }

  // ==========================================
  // 4. Fetch On-Chain Balance
  // ==========================================
  static Future<double> getBalance(
    String seedPhrase, {
    BitcoinWalletType type = BitcoinWalletType.nativeSegWitBip84,
    String passphrase = "",
  }) async {
    try {
      final wallet = await _getWallet(seedPhrase, type: type, passphrase: passphrase);
      final blockchain = await _getBlockchain();

      await wallet.sync(blockchain);

      final balance = await wallet.getBalance();
      return balance.total / 100000000;
    } catch (e) {
      throw Exception('Failed to fetch Bitcoin balance: $e');
    }
  }

  // ==========================================
  // 5. Reset State
  // ==========================================
  static void clearSession() {
    _walletInitialization = null;
    _blockchainInitialization = null;
  }
}