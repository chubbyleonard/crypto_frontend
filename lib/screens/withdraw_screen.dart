import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart' as web3;
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import '../services/transaction_service.dart';

class WithdrawScreen extends StatefulWidget {
  final String ethPrivateKeyHex;
  final web3.Web3Client ethClient;
  final bdk.Wallet bdkWallet;

  const WithdrawScreen({
    super.key,
    required this.ethPrivateKeyHex,
    required this.ethClient,
    required this.bdkWallet,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final TransactionService _txService = TransactionService();

  bool _isLoading = false;
  bool _isLoadingBalances = true;
  String _selectedChain = 'BTC'; // Default active chain

  String _btcAddress = '';
  double _btcBalance = 0.0;

  String _ethAddress = '';
  double _ethBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLiveWalletDetails();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadLiveWalletDetails() async {
    setState(() => _isLoadingBalances = true);
    try {
      // 1. Derive ETH Address & On-Chain Balance
      final credentials = web3.EthPrivateKey.fromHex(widget.ethPrivateKeyHex);
      _ethAddress = credentials.address.hex;
      final ethEtherAmount = await widget.ethClient.getBalance(credentials.address);
      _ethBalance = ethEtherAmount.getValueInUnit(web3.EtherUnit.ether);

      // 2. Fetch BTC Address & Cached/Synced Balance
      final addrInfo = await widget.bdkWallet.getAddress(
        addressIndex: const bdk.AddressIndex.new(),
      );
      _btcAddress = addrInfo.address;
      final btcBalanceData = await widget.bdkWallet.getBalance();
      _btcBalance = btcBalanceData.total / 100000000;
    } catch (e) {
      debugPrint('Error retrieving wallet balances: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBalances = false);
    }
  }

  String _truncateAddress(String addr) {
    if (addr.isEmpty) return 'Loading...';
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  void _applyMaxBalance() {
    final maxBal = _selectedChain == 'BTC' ? _btcBalance : _ethBalance;
    _amountController.text = maxBal.toString();
  }

  Future<void> _executeWithdrawal() async {
    final address = _addressController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (address.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid destination address and amount'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String txHash = '';

      if (_selectedChain == 'ETH') {
        txHash = await _txService.withdrawEth(
          privateKeyHex: widget.ethPrivateKeyHex,
          toAddress: address,
          amountInEth: amount,
          ethClient: widget.ethClient,
        );
      } else {
        final amountInSats = (amount * 100000000).toInt();
        txHash = await _txService.withdrawBtc(
          bdkWallet: widget.bdkWallet,
          toAddress: address,
          amountInSats: amountInSats,
        );
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF13151C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF222632)),
            ),
            title: const Text('Transfer Broadcasted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            content: SelectableText(
              'Transaction ID / Hash:\n\n$txHash',
              style: const TextStyle(color: Color(0xFF8A919E), fontSize: 13, fontFamily: 'monospace'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addressController.clear();
                  _amountController.clear();
                  _loadLiveWalletDetails(); // Refresh balances post-transfer
                },
                child: const Text('OK', style: TextStyle(color: Color(0xFF2970FF), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast Failed: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Web3 Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8A919E)),
            onPressed: _isLoadingBalances ? null : _loadLiveWalletDetails,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SELECT SOURCE WALLET',
              style: TextStyle(
                color: Color(0xFF8A919E),
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // DUAL-HEADER WALLET SELECTION CARDS
            Row(
              children: [
                Expanded(
                  child: _buildWalletCard(
                    symbol: 'BTC',
                    network: 'Bitcoin',
                    address: _btcAddress,
                    balance: '₿ ${_btcBalance.toStringAsFixed(6)}',
                    isSelected: _selectedChain == 'BTC',
                    accentColor: const Color(0xFFF7931A),
                    onTap: () => setState(() => _selectedChain = 'BTC'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildWalletCard(
                    symbol: 'ETH',
                    network: 'Ethereum',
                    address: _ethAddress,
                    balance: 'Ξ ${_ethBalance.toStringAsFixed(4)}',
                    isSelected: _selectedChain == 'ETH',
                    accentColor: const Color(0xFF627EEA),
                    onTap: () => setState(() => _selectedChain = 'ETH'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // DESTINATION ADDRESS FIELD
            const Text(
              'RECIPIENT ADDRESS',
              style: TextStyle(color: Color(0xFF8A919E), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _selectedChain == 'BTC' ? 'Destination bc1q... or 1...' : 'Destination 0x...',
                hintStyle: const TextStyle(color: Color(0xFF8A919E)),
                prefixIcon: const Icon(Icons.qr_code_scanner_outlined, color: Color(0xFF8A919E)),
                filled: true,
                fillColor: const Color(0xFF13151C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF222632))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF222632))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2970FF))),
              ),
            ),
            const SizedBox(height: 24),

            // AVAILABLE BALANCE & USE MAX
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available: ${_selectedChain == 'BTC' ? '₿ ${_btcBalance.toStringAsFixed(6)}' : 'Ξ ${_ethBalance.toStringAsFixed(4)}'}',
                  style: const TextStyle(color: Color(0xFF8A919E), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: _applyMaxBalance,
                  child: const Text(
                    'USE MAX',
                    style: TextStyle(color: Color(0xFF2970FF), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // AMOUNT FIELD
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: const TextStyle(color: Color(0xFF8A919E)),
                prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFF8A919E)),
                suffixText: _selectedChain,
                suffixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: const Color(0xFF13151C),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF222632))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF222632))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2970FF))),
              ),
            ),
            const SizedBox(height: 36),

            // EXECUTE BUTTON
            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedChain == 'BTC' ? const Color(0xFFF7931A) : const Color(0xFF2970FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _executeWithdrawal,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Send $_selectedChain via Non-Custodial Key',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard({
    required String symbol,
    required String network,
    required String address,
    required String balance,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.08) : const Color(0xFF13151C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.5) : const Color(0xFF222632),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  symbol,
                  style: TextStyle(
                    color: isSelected ? accentColor : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 16,
                  color: isSelected ? accentColor : const Color(0xFF8A919E),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isLoadingBalances ? 'Scanning...' : _truncateAddress(address),
              style: const TextStyle(color: Color(0xFF8A919E), fontSize: 11, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Text(
              _isLoadingBalances ? '...' : balance,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}