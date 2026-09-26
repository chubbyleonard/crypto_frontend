import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';
import 'package:bdk_flutter/bdk_flutter.dart';
import 'transaction_service.dart'; 

class WithdrawScreen extends StatefulWidget {
  // Required injected state from the bottom navigation bar
  final String ethPrivateKeyHex;
  final Web3Client ethClient;
  final Wallet bdkWallet;

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
  String _selectedChain = 'BTC'; 

  Future<void> _executeWithdrawal() async {
    final address = _addressController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    if (address.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid address and amount'),
          backgroundColor: Colors.redAccent,
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
        // BTC expects Satoshis (1 BTC = 100,000,000 Sats)
        final amountInSats = (amount * 100000000).toInt();
        txHash = await _txService.withdrawBtc(
          bdkWallet: widget.bdkWallet,
          toAddress: address,
          amountInSats: amountInSats,
        );
      }

      // Display the final Blockchain Receipt
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E2336),
            title: const Text('Transfer Sent', style: TextStyle(color: Colors.white)),
            content: Text('TxID:\n$txHash', style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _addressController.clear();
                  _amountController.clear();
                },
                child: const Text('OK', style: TextStyle(color: Color(0xFF00E599))),
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
            backgroundColor: Colors.redAccent,
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
      backgroundColor: const Color(0xFF0B0F19), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Withdraw Funds', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Network Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNetworkButton('BTC', 'Native Bitcoin'),
                _buildNetworkButton('ETH', 'Ethereum (EVM)'),
              ],
            ),
            const SizedBox(height: 30),
            
            // Destination Address Input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF191D2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _addressController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Destination Address',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Amount Input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF191D2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Amount in $_selectedChain',
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const Spacer(),
            
            // Confirm Transfer Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E599), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isLoading ? null : _executeWithdrawal,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Confirm Transfer',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkButton(String chain, String label) {
    final isSelected = _selectedChain == chain;
    return GestureDetector(
      onPressed: () => setState(() => _selectedChain = chain),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E599).withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? const Color(0xFF00E599) : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00E599) : Colors.white54,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}