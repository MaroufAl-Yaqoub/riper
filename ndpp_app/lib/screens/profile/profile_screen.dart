import 'package:flutter/material.dart';

import '../../data/mock_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = MockData.user;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFFCCFBF1),
                    child: Icon(Icons.person, size: 34, color: Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 14),
                  Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(user.role, style: const TextStyle(color: Color(0xFF64748B))),
                  const SizedBox(height: 18),
                  _InfoTile(label: 'البريد الإلكتروني', value: user.email),
                  const SizedBox(height: 12),
                  _InfoTile(label: 'رقم الهاتف', value: user.phone),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('ملخص النشاط', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(title: 'إجمالي البلاغات', value: '${MockData.reports.length}')),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: 'فحوصات Deepfake', value: '${MockData.deepfakeHistory.length}')),
            ],
          ),
          const SizedBox(height: 20),
          const Text('آخر الحالات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...MockData.reports.take(3).map(
            (report) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text(report.categoryTitle),
                  subtitle: Text(MockData.statusLabel(report.statusKey)),
                  trailing: Text(report.createdAtLabel, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
