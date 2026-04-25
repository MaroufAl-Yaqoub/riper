
import 'package:flutter_test/flutter_test.dart';

import 'package:ndpp_app/app.dart';

void main() {

  testWidgets('App loads successfully', (WidgetTester tester) async {
    // تشغيل التطبيق
    await tester.pumpWidget(const NdppApp());

    // تأكد أن التطبيق اشتغل (مثلاً وجود نص من الصفحة الرئيسية)
    expect(find.text('الرئيسية'), findsOneWidget);
  });
}