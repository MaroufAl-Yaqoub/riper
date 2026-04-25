import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../models/report_category.dart';
import 'report_form_screen.dart';

class ReportsCatalogScreen extends StatefulWidget {
  const ReportsCatalogScreen({super.key});

  @override
  State<ReportsCatalogScreen> createState() => _ReportsCatalogScreenState();
}

class _ReportsCatalogScreenState extends State<ReportsCatalogScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final List<ReportCategory> filtered = MockData.categories
        .where((item) => item.title.contains(query) || item.subtitle.contains(query))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('اختيار نوع البلاغ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'ابحث عن نوع البلاغ',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 16),
          ...filtered.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(category.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.description),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('مستوى الخطورة: ${category.riskLevel}'),
                        ),
                      ],
                    ),
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
        ],
      ),
    );
  }
}
