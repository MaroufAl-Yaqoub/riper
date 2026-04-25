import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../reports/report_form_screen.dart';
import '../reports/reports_catalog_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topCategories = MockData.categories.take(4).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('منصة الحماية الرقمية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF155E75)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'قدّم بلاغك بسهولة وأمان',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'اختر نوع البلاغ، عبّئ المعلومات المطلوبة، وتابع حالة البلاغ من حسابك.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsCatalogScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('إنشاء بلاغ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('أكثر البلاغات شيوعًا', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...topCategories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  title: Text(category.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(category.subtitle),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReportFormScreen(category: category)),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsCatalogScreen()),
              );
            },
            child: const Text('عرض جميع البلاغات'),
          ),
        ],
      ),
    );
  }
}
