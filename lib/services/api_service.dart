import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../models/withdrawal_response.dart';

class ApiService {
  // Replace with your Windows machine's local IPv4 address
  static const String baseUrl = 'http://192.168.100.16:3000';

  // These must perfectly match the .env file in your Node.js backend
  static const String appApiKey = 'your_custom_mobile_app_key';
  static const String appApiSecret = 'your_custom_mobile_app_secret';

  // Generates the HMAC-SHA256 signature to authorize the app with the Node server
  static Map<String, String> _generateAuthHeaders(String serializedBody) {
    final String nonce = DateTime.now().millisecondsSinceEpoch.toString();
    final String payload = nonce + serializedBody;
    final hmac = Hmac(sha256, utf8.encode(appApiSecret));
    final String signature = hmac.convert(utf8.encode(payload)).toString();

    return {
      'Content-Type': 'application/json',
      'x-api-key': appApiKey,
      'x-signature': signature,
      'x-nonce': nonce,
    };
  }

  // Fetch Live Balances
  static Future<Map<String, dynamic>> fetchBalance({
    required String exchangeId,
    required String apiKey,
    required String apiSecret,
    String? password,
  }) async {
    final url = Uri.parse('$baseUrl/api/balance');
    final Map<String, dynamic> bodyData = {
      'exchangeId': exchangeId,
      'exchangeApiKey': apiKey,
      'exchangeApiSecret': apiSecret,
      if (password != null && password.isNotEmpty) 'exchangePassword': password,
    };
    
    final String serializedBody = jsonEncode(bodyData);

    try {
      final response = await http.post(
        url, 
        headers: _generateAuthHeaders(serializedBody), 
        body: serializedBody
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Request Withdrawal
  static Future<WithdrawalResponse> requestWithdrawal({
    required String exchangeId,
    required String apiKey,
    required String apiSecret,
    String? password,
    required String currency,
    required double amount,
    required String address,
  }) async {
    final url = Uri.parse('$baseUrl/api/withdraw');
    final Map<String, dynamic> bodyData = {
      'exchangeId': exchangeId,
      'exchangeApiKey': apiKey,
      'exchangeApiSecret': apiSecret,
      if (password != null && password.isNotEmpty) 'exchangePassword': password,
      'currency': currency,
      'amount': amount,
      'address': address,
    };

    final String serializedBody = jsonEncode(bodyData);

    try {
      final response = await http.post(
        url, 
        headers: _generateAuthHeaders(serializedBody), 
        body: serializedBody
      );
      return WithdrawalResponse.fromJson(jsonDecode(response.body));
    } catch (e) {
      return WithdrawalResponse(success: false, message: 'Network error: $e');
    }
  }
}