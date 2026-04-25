import 'package:flutter/material.dart';

class ReportSubmitSuccessScreen extends StatelessWidget {
  final String categoryTitle;
  final String? incidentId;

  const ReportSubmitSuccessScreen({
    super.key,
    required this.categoryTitle,
    this.incidentId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تم الإرسال')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFFDCFCE7),
                    child: Icon(
                      Icons.check,
                      color: Color(0xFF166534),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تم إرسال البلاغ بنجاح',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'نوع البلاغ: $categoryTitle',
                    textAlign: TextAlign.center,
                  ),
                  if (incidentId != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'رقم البلاغ: $incidentId',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: const Text('العودة للرئيسية'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}