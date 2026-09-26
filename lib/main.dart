import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async'; // Added for Timeout logic
import 'services/api_service.dart';
import 'services/web3_service.dart';
import 'services/bitcoin_service.dart';

void main() {
  runApp(const CryptoApp());
}

class CryptoApp extends StatelessWidget {
  const CryptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crypto Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        cardColor: const Color(0xFF141B2D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFF00F5A0),
          surface: Color(0xFF141B2D),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF161F36),
          labelStyle: const TextStyle(color: Color(0xFF8F9CAE), fontSize: 14),
          prefixIconColor: const Color(0xFF00E5FF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF26324D))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF26324D))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  void _switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardTab(onNavigateToSettings: () => _switchTab(3)),
      const WithdrawTab(),
      const Web3Tab(),
      const SettingsTab(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF1C263D), width: 1))),
        child: NavigationBar(
          backgroundColor: const Color(0xFF0D1322),
          indicatorColor: const Color(0xFF00E5FF).withOpacity(0.18),
          selectedIndex: _currentIndex,
          onDestinationSelected: _switchTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF8F9CAE)), selectedIcon: Icon(Icons.account_balance_wallet, color: Color(0xFF00E5FF)), label: 'Exchange'),
            NavigationDestination(icon: Icon(Icons.send_outlined, color: Color(0xFF8F9CAE)), selectedIcon: Icon(Icons.send, color: Color(0xFF00E5FF)), label: 'Withdraw'),
            NavigationDestination(icon: Icon(Icons.language_outlined, color: Color(0xFF8F9CAE)), selectedIcon: Icon(Icons.language, color: Color(0xFF00E5FF)), label: 'Web3'),
            NavigationDestination(icon: Icon(Icons.tune_outlined, color: Color(0xFF8F9CAE)), selectedIcon: Icon(Icons.tune, color: Color(0xFF00E5FF)), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// --- HELPER: FORMAT CURRENCY SYMBOLS ---
String _formatSymbol(String ticker, dynamic amount) {
  final num val = (amount is String) ? (double.tryParse(amount) ?? 0) : amount;
  final String t = ticker.toUpperCase();
  if (t == 'USD' || t == 'USDT' || t == 'USDC') return '\$${val.toStringAsFixed(2)}';
  if (t == 'BTC') return '₿ ${val.toStringAsFixed(6)}';
  if (t == 'ETH') return 'Ξ ${val.toStringAsFixed(4)}';
  return '${val.toStringAsFixed(4)} $t';
}

// ==========================================
// TAB 1: DASHBOARD (EXCHANGE PORTFOLIO)
// ==========================================
class DashboardTab extends StatefulWidget {
  final VoidCallback onNavigateToSettings;
  const DashboardTab({super.key, required this.onNavigateToSettings});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _balances = {};
  String _activeExchange = '';

  @override
  void initState() {
    super.initState();
    _fetchBalances();
  }

  Future<void> _fetchBalances() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    final exchangeId = await _storage.read(key: 'exchangeId');
    final apiKey = await _storage.read(key: 'apiKey');
    final apiSecret = await _storage.read(key: 'apiSecret');
    final password = await _storage.read(key: 'apiPassword');

    if (exchangeId == null || apiKey == null || apiSecret == null) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'NO_KEYS'; });
      return;
    }
    setState(() => _activeExchange = exchangeId.toUpperCase());
    
    try {
      // FIX: Added 15-second timeout to prevent infinite loading
      final result = await ApiService.fetchBalance(
        exchangeId: exchangeId, 
        apiKey: apiKey, 
        apiSecret: apiSecret, 
        password: password
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => {'success': false, 'message': 'Connection timed out. Please try again.'},
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (result['success'] == true) {
            final Map<String, dynamic> rawBalances = result['balances'] ?? {};
            _balances = Map.fromEntries(rawBalances.entries.where((entry) {
              final val = entry.value;
              if (val is num) return val > 0;
              if (val is String) return (double.tryParse(val) ?? 0) > 0;
              return false;
            }));
          } else {
            _errorMessage = result['message'] ?? 'Failed to load portfolio.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF00E5FF), backgroundColor: const Color(0xFF141B2D), onRefresh: _fetchBalances,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CENTRALIZED EXCHANGE', style: TextStyle(color: Color(0xFF8F9CAE), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_activeExchange.isEmpty ? 'Connected Assets' : '$_activeExchange Balance', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton.filledTonal(onPressed: _fetchBalances, icon: const Icon(Icons.refresh, size: 20), style: IconButton.styleFrom(backgroundColor: const Color(0xFF161F36), foregroundColor: const Color(0xFF00E5FF))),
            ],
          ),
          const SizedBox(height: 24),
          // FIX: Added manual cancel button to the loading state
          if (_isLoading) Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 80), 
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => setState(() { _isLoading = false; _errorMessage = 'Request cancelled by user.'; }),
                    child: const Text('Cancel Request', style: TextStyle(color: Color(0xFF00E5FF))),
                  )
                ],
              )
            )
          )
          else if (_errorMessage == 'NO_KEYS') _buildEmptyKeysCard()
          else if (_errorMessage.isNotEmpty) _buildErrorCard(_errorMessage)
          else if (_balances.isEmpty) const Center(child: Text('Zero Available Balances', style: TextStyle(color: Color(0xFF8F9CAE))))
          else ..._balances.entries.map((entry) => _buildAssetTile(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildEmptyKeysCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFF141B2D), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF26324D))),
      child: Column(
        children: [
          const Icon(Icons.key_off_rounded, size: 52, color: Color(0xFF8F9CAE)),
          const SizedBox(height: 16),
          const Text('No Active Exchange', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.onNavigateToSettings, icon: const Icon(Icons.add_link), label: const Text('Configure Credentials'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFF2B141E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF6B2432))),
      child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFFF5252)), const SizedBox(width: 14), Expanded(child: Text(error, style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13)))]),
    );
  }

  Widget _buildAssetTile(String symbol, dynamic amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF141B2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF202A40))),
      child: Row(
        children: [
          Container(
            width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF0072FF)]), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(symbol.length > 3 ? symbol.substring(0, 3) : symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Text(_formatSymbol(symbol, amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF00F5A0))),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 2: WITHDRAWAL FORM
// ==========================================
class WithdrawTab extends StatefulWidget {
  const WithdrawTab({super.key});
  @override
  State<WithdrawTab> createState() => _WithdrawTabState();
}

class _WithdrawTabState extends State<WithdrawTab> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _currencyController = TextEditingController();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();

  Map<String, dynamic> _liveBalances = {};
  double _networkFee = 0.0;
  double _netTotal = 0.0;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _fetchBalancesInBackground();
    _currencyController.addListener(_recalculateFees);
    _amountController.addListener(_recalculateFees);
  }

  Future<void> _fetchBalancesInBackground() async {
    final exchangeId = await _storage.read(key: 'exchangeId');
    final apiKey = await _storage.read(key: 'apiKey');
    final apiSecret = await _storage.read(key: 'apiSecret');
    final password = await _storage.read(key: 'apiPassword');
    if (exchangeId == null || apiKey == null) return;

    final result = await ApiService.fetchBalance(exchangeId: exchangeId, apiKey: apiKey, apiSecret: apiSecret!, password: password);
    if (result['success'] == true && mounted) setState(() => _liveBalances = result['balances']);
  }

  void _recalculateFees() {
    final symbol = _currencyController.text.trim().toUpperCase();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    double fee = 0.0;
    if (symbol == 'BTC') fee = 0.0005;
    else if (symbol == 'ETH') fee = 0.002;
    else if (symbol == 'USDT' || symbol == 'USDC') fee = 1.0;
    else if (symbol == 'SOL') fee = 0.01;
    setState(() {
      _networkFee = fee;
      _netTotal = (amount - fee > 0) ? (amount - fee) : 0.0;
    });
  }

  void _applyMaxBalance() {
    final symbol = _currencyController.text.trim().toUpperCase();
    if (symbol.isEmpty) return;
    final balance = _liveBalances[symbol];
    if (balance != null && (balance is num) && balance > 0) _amountController.text = balance.toString();
  }

  Future<void> _openQRScanner() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const QRScannerScreen()));
    if (result != null && result is String) setState(() => _addressController.text = result.split(':').last.split('?').first);
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    final exchangeId = await _storage.read(key: 'exchangeId');
    final apiKey = await _storage.read(key: 'apiKey');
    final apiSecret = await _storage.read(key: 'apiSecret');
    final password = await _storage.read(key: 'apiPassword');

    if (exchangeId == null || apiKey == null || apiSecret == null) {
      setState(() { _statusMessage = 'Connect API keys in Settings first.'; _isSuccess = false; });
      return;
    }
    setState(() { _isLoading = true; _statusMessage = null; });

    final response = await ApiService.requestWithdrawal(
      exchangeId: exchangeId, apiKey: apiKey, apiSecret: apiSecret, password: password,
      currency: _currencyController.text.trim().toUpperCase(), amount: double.parse(_amountController.text.trim()), address: _addressController.text.trim(),
    );
    if (mounted) setState(() { _isLoading = false; _isSuccess = response.success; _statusMessage = response.message; });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('TRANSFER ASSETS', style: TextStyle(color: Color(0xFF8F9CAE), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Withdraw To Wallet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 18), decoration: BoxDecoration(color: _isSuccess ? const Color(0xFF0F2B20) : const Color(0xFF2B141E), borderRadius: BorderRadius.circular(12), border: Border.all(color: _isSuccess ? const Color(0xFF1E6B4A) : const Color(0xFF6B2432))),
                child: Text(_statusMessage!, style: TextStyle(color: _isSuccess ? const Color(0xFF00F5A0) : const Color(0xFFFF8A80), fontSize: 13)),
              ),
            TextFormField(controller: _currencyController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Asset Ticker', hintText: 'USD, BTC, ETH...', prefixIcon: Icon(Icons.toll_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Enter asset ticker' : null),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressController, decoration: InputDecoration(labelText: 'Destination Public Address', hintText: '0x... or bc1q...', prefixIcon: const Icon(Icons.qr_code_scanner_outlined), suffixIcon: IconButton(icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFF00E5FF)), onPressed: _openQRScanner)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Enter recipient wallet address' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Withdrawal Amount', hintText: '0.00', prefixIcon: const Icon(Icons.payments_outlined), suffixIcon: TextButton(onPressed: _applyMaxBalance, child: const Text('MAX', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)))),
              validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter valid amount' : null,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF141B2D), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Network Fee Estimate:', style: TextStyle(color: Color(0xFF8F9CAE))), Text(_formatSymbol(_currencyController.text, _networkFee))]),
                  const Divider(color: Color(0xFF26324D), height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Net Total to Arrive:', style: TextStyle(fontWeight: FontWeight.bold)), Text(_formatSymbol(_currencyController.text, _netTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00F5A0)))]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitWithdrawal,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('Execute Withdrawal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Wallet Address'), backgroundColor: const Color(0xFF0D1322)),
      body: MobileScanner(onDetect: (capture) {
        final List<Barcode> barcodes = capture.barcodes;
        if (barcodes.isNotEmpty && barcodes.first.rawValue != null) Navigator.pop(context, barcodes.first.rawValue);
      }),
    );
  }
}

// ==========================================
// TAB 3: WEB3 WALLET (DUAL-CHAIN)
// ==========================================
class Web3Tab extends StatefulWidget {
  const Web3Tab({super.key});
  @override
  State<Web3Tab> createState() => _Web3TabState();
}

class _Web3TabState extends State<Web3Tab> {
  final _storage = const FlutterSecureStorage();
  final _seedController = TextEditingController();
  
  bool _isLoading = true;
  bool _hasWallet = false;
  String? _errorMessage;

  String _ethAddress = '';
  double _ethBalance = 0.0;
  
  String _btcAddress = '';
  double _btcBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    final seed = await _storage.read(key: 'web3_seed');
    
    if (seed != null && seed.isNotEmpty) {
      await _initializeWalletData(seed);
    } else {
      if (mounted) setState(() { _hasWallet = false; _isLoading = false; });
    }
  }

  Future<void> _initializeWalletData(String seed) async {
    try {
      // 1. Initialize Ethereum Data
      final privateKey = Web3Service.getPrivateKeyFromSeed(seed);
      final ethAddr = await Web3Service.getPublicAddress(privateKey);
      final ethBal = await Web3Service.getBalance(ethAddr);

      // 2. Initialize Bitcoin Data
      final btcAddr = await BitcoinService.getPublicAddress(seed);
      final btcBal = await BitcoinService.getBalance(seed);
      
      if (mounted) {
        setState(() {
          _ethAddress = ethAddr;
          _ethBalance = ethBal;
          _btcAddress = btcAddr;
          _btcBalance = btcBal;
          _hasWallet = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error synchronizing blockchains: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _importWallet() async {
    final phrase = _seedController.text.trim().toLowerCase();
    final words = phrase.split(RegExp(r'\s+'));
    
    if (words.length != 12 && words.length != 24) {
      setState(() => _errorMessage = 'Seed phrase must be exactly 12 or 24 words.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    
    try {
      // Test EVM Derivation first
      Web3Service.getPrivateKeyFromSeed(phrase);
      await _storage.write(key: 'web3_seed', value: phrase);
      await _initializeWalletData(phrase);
      _seedController.clear();
    } catch (e) {
      if (mounted) {
        setState(() { _errorMessage = 'Invalid seed phrase format or network error.'; _isLoading = false; });
      }
    }
  }

  Future<void> _removeWallet() async {
    await _storage.delete(key: 'web3_seed');
    setState(() {
      _hasWallet = false;
      _ethAddress = '';
      _ethBalance = 0.0;
      _btcAddress = '';
      _btcBalance = 0.0;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DECENTRALIZED', style: TextStyle(color: Color(0xFF8F9CAE), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Web3 Wallet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          // FIX: Added manual cancel button to the loading state
          if (_isLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40), 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF00E5FF)),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => setState(() { _isLoading = false; _errorMessage = 'Request cancelled by user.'; }),
                      child: const Text('Cancel Request', style: TextStyle(color: Color(0xFF00E5FF))),
                    )
                  ],
                )
              )
            )
          else if (_hasWallet)
            _buildWalletDashboard()
          else
            _buildImportForm(),
        ],
      ),
    );
  }

  Widget _buildImportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // FIX: Replaced static error box with interactive dismissible Row
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(14), 
            margin: const EdgeInsets.only(bottom: 18), 
            decoration: BoxDecoration(color: const Color(0xFF2B141E), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6B2432))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 13))),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _errorMessage = null), // Instantly dismisses error
                  child: const Icon(Icons.close, color: Color(0xFFFF8A80), size: 20),
                )
              ],
            ),
          ),
        const Text('Enter your 12 or 24-word recovery phrase to securely derive your Dual-Chain (BTC & ETH) private keys.', style: TextStyle(color: Color(0xFF8F9CAE), height: 1.4)),
        const SizedBox(height: 20),
        TextField(
          controller: _seedController, maxLines: 4,
          decoration: const InputDecoration(hintText: 'word1 word2 word3...', labelText: 'Recovery Phrase', alignLabelWithHint: true),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _importWallet, icon: const Icon(Icons.download), label: const Text('Import Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )
      ]
    );
  }

  Widget _buildWalletDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAssetCard(
          title: 'NATIVE BITCOIN',
          symbol: 'BTC',
          address: _btcAddress,
          balance: _btcBalance,
          gradient: const [Color(0xFFF7931A), Color(0xFFF37321)],
        ),
        const SizedBox(height: 16),
        _buildAssetCard(
          title: 'ETHEREUM VIRTUAL MACHINE',
          symbol: 'ETH',
          address: _ethAddress,
          balance: _ethBalance,
          gradient: const [Color(0xFF00E5FF), Color(0xFF0072FF)],
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _removeWallet, icon: const Icon(Icons.logout), label: const Text('Disconnect Device Keys'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFF5252), side: const BorderSide(color: Color(0xFF6B2432)), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )
      ],
    );
  }

  Widget _buildAssetCard({required String title, required String symbol, required String address, required double balance, required List<Color> gradient}) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$symbol Address copied to clipboard!')));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF141B2D), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF202A40))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF8F9CAE), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                const Icon(Icons.copy, size: 16, color: Color(0xFF8F9CAE)),
              ]
            ),
            const SizedBox(height: 12),
            Text('${address.substring(0, 10)}...${address.substring(address.length - 8)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.1)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(gradient: LinearGradient(colors: gradient), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('BALANCE', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 12)),
                  Text(_formatSymbol(symbol, balance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),
                ]
              )
            )
          ]
        )
      )
    );
  }
}

// ==========================================
// TAB 4: SETTINGS (EXCHANGE GATEWAY)
// ==========================================
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});
  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _storage = const FlutterSecureStorage();
  final _keyController = TextEditingController();
  final _secretController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customExchangeController = TextEditingController();

  bool _obscureSecret = true;
  String _selectedExchange = 'binanceus';

  final Map<String, String> _exchanges = {
    'binanceus': 'Binance US', 'coinbaseadvanced': 'Coinbase Advanced', 'kraken': 'Kraken', 'gemini': 'Gemini', 'okx': 'OKX (US / Global)',
    'binance': 'Binance (Global)', 'bybit': 'Bybit', 'kucoin': 'KuCoin', 'gateio': 'Gate.io', 'mexc': 'MEXC', 'other': 'Other (Enter ID manually)',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final exchange = await _storage.read(key: 'exchangeId');
    final key = await _storage.read(key: 'apiKey');
    final secret = await _storage.read(key: 'apiSecret');
    final pass = await _storage.read(key: 'apiPassword');

    setState(() {
      if (exchange != null) {
        if (_exchanges.containsKey(exchange)) _selectedExchange = exchange;
        else { _selectedExchange = 'other'; _customExchangeController.text = exchange; }
      }
      if (key != null) _keyController.text = key;
      if (secret != null) _secretController.text = secret;
      if (pass != null) _passwordController.text = pass;
    });
  }

  Future<void> _saveSettings() async {
    final finalExchangeId = _selectedExchange == 'other' ? _customExchangeController.text.trim().toLowerCase() : _selectedExchange;
    await _storage.write(key: 'exchangeId', value: finalExchangeId);
    await _storage.write(key: 'apiKey', value: _keyController.text.trim());
    await _storage.write(key: 'apiSecret', value: _secretController.text.trim());
    await _storage.write(key: 'apiPassword', value: _passwordController.text.trim());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials Encrypted Successfully', style: TextStyle(color: Color(0xFF00F5A0)))));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('CONFIGURATION', style: TextStyle(color: Color(0xFF8F9CAE), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Exchange Gateway', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedExchange, dropdownColor: const Color(0xFF141B2D), decoration: const InputDecoration(labelText: 'Target Exchange Platform', prefixIcon: Icon(Icons.corporate_fare_outlined)),
            items: _exchanges.entries.map((item) => DropdownMenuItem<String>(value: item.key, child: Text(item.value, style: const TextStyle(fontSize: 15)))).toList(),
            onChanged: (val) => setState(() => _selectedExchange = val!),
          ),
          if (_selectedExchange == 'other') ...[
            const SizedBox(height: 14),
            TextField(controller: _customExchangeController, decoration: const InputDecoration(labelText: 'Custom CCXT Exchange ID (e.g. bitstamp)', prefixIcon: Icon(Icons.code))),
          ],
          const SizedBox(height: 14),
          TextField(controller: _keyController, decoration: const InputDecoration(labelText: 'Exchange API Key', prefixIcon: Icon(Icons.vpn_key_outlined))),
          const SizedBox(height: 14),
          TextField(
            controller: _secretController, obscureText: _obscureSecret,
            decoration: InputDecoration(labelText: 'Exchange API Secret', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscureSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF8F9CAE)), onPressed: () => setState(() => _obscureSecret = !_obscureSecret))),
          ),
          const SizedBox(height: 14),
          TextField(controller: _passwordController, obscureText: _obscureSecret, decoration: const InputDecoration(labelText: 'API Passphrase (Optional)', prefixIcon: Icon(Icons.password_outlined))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F5A0), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Save & Encrypt Keys', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}