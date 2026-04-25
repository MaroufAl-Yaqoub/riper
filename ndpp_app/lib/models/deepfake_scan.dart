class DeepfakeScan {
  final String id;
  final String fileName;
  final String result;
  final double confidence;
  final String createdAt;

  const DeepfakeScan({
    required this.id,
    required this.fileName,
    required this.result,
    required this.confidence,
    required this.createdAt,
  });
}
