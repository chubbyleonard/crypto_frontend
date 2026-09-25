class WithdrawalResponse {
  final bool success;
  final String message;
  final String? id;

  WithdrawalResponse({
    required this.success,
    required this.message,
    this.id,
  });

  factory WithdrawalResponse.fromJson(Map<String, dynamic> json) {
    return WithdrawalResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      id: json['id'],
    );
  }
}