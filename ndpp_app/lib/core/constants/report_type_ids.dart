class ReportTypeIds {
  static const Map<String, int> byCategoryId = {
    'phishing_sms': 1,
    'email_phishing': 2,
    'bank_impersonation': 3,
    'whatsapp_scams': 4,
    'suspicious_links': 5,
    'account_hacking': 6,
    'identity_theft': 7,
    'shopping_fraud': 8,
    'blackmail': 9,
    'fake_gov': 10,
    'qr_scam': 11,
    'deepfake': 12,
  };

  static int fromCategoryId(String categoryId) {
    return byCategoryId[categoryId] ?? 1;
  }
}
