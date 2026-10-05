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
  // 1. Initialize & Auto-Discover the BDK Wallet
  // ==========================================
  
  /// Public accessor used by main.dart to pass the active wallet to the Withdraw UI
  static Future<Wallet> getAutoDiscoveredWallet(
    String seedPhrase, {
    String passphrase = "",
  }) {
    _walletInitialization ??= _autoDiscoverWallet(seedPhrase, passphrase);
    return _walletInitialization!;
  }

  /// The Engine: Scans all derivation paths and locks in the one holding funds
  static Future<Wallet> _autoDiscoverWallet(String seedPhrase, String passphrase) async {
    final blockchain = await _getBlockchain();

    // Order of scanning: Native SegWit (Most Common), Legacy, Nested, Taproot
    final typesToScan = [
      BitcoinWalletType.nativeSegWitBip84,
      BitcoinWalletType.legacyBip44,
      BitcoinWalletType.nestedSegWitBip49,
      BitcoinWalletType.taprootBip86,
    ];

    Wallet? defaultWallet;

    for (final type in typesToScan) {
      final wallet = await _buildWallet(seedPhrase, type, passphrase);
      
      try {
        // Sync the specific format with the live blockchain
        await wallet.sync(blockchain);
        final balance = await wallet.getBalance();
        
        // If unspent funds exist, lock this format into memory and stop scanning!
        if (balance.total > 0) {
          return wallet;
        }
      } catch (e) {
        // Ignore network timeouts for a specific format and continue scanning
      }

      // Store Native SegWit as the fallback in case all formats have a 0 balance
      if (type == BitcoinWalletType.nativeSegWitBip84) {
        defaultWallet = wallet;
      }
    }

    return defaultWallet!;
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
  // 3. Get Public Address (Uses Auto-Discovered Wallet)
  // ==========================================
  static Future<String> getPublicAddress(
    String seedPhrase, {
    String passphrase = "",
  }) async {
    try {
      final wallet = await getAutoDiscoveredWallet(seedPhrase, passphrase: passphrase);
      final addressInfo = await wallet.getAddress(addressIndex: const AddressIndex.new());
      return addressInfo.address;
    } catch (e) {
      throw Exception('Failed to generate Bitcoin address: $e');
    }
  }

  // ==========================================
  // 4. Fetch On-Chain Balance (Uses Auto-Discovered Wallet)
  // ==========================================
  static Future<double> getBalance(
    String seedPhrase, {
    String passphrase = "",
  }) async {
    try {
      final wallet = await getAutoDiscoveredWallet(seedPhrase, passphrase: passphrase);
      final blockchain = await _getBlockchain();

      // Ensure we have the latest balance if checking again later
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