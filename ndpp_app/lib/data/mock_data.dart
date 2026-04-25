import '../models/deepfake_scan.dart';
import '../models/incident_report.dart';
import '../models/report_category.dart';
import '../models/user_profile.dart';

class MockData {
  static const user = UserProfile(
    fullName: 'أحمد الياقوب',
    email: 'anmadsy23@gmail.com',
    phone: '+962 7 9000 0000',
    role: 'مواطن',
  );

  static const categories = <ReportCategory>[
    ReportCategory(
      id: 'phishing_sms',
      title: 'رسائل تصيّد SMS',
      subtitle: 'رسائل تنتحل جهات موثوقة لسرقة بياناتك',
      description: 'استخدم هذا البلاغ عند استلام رسالة نصية تطلب معلومات حساسة أو تحتوي على رابط مشبوه.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان مختصر', hint: 'مثال: رسالة بنك مزيفة'),
        ReportField(key: 'phone', label: 'رقم المُرسل', hint: 'أدخل رقم الهاتف أو الاسم الظاهر'),
        ReportField(key: 'message', label: 'نص الرسالة', hint: 'انسخ محتوى الرسالة', maxLines: 4),
        ReportField(key: 'link', label: 'الرابط المشبوه', hint: 'أدخل الرابط إن وجد', required: false),
      ],
    ),
    ReportCategory(
      id: 'email_phishing',
      title: 'تصيّد عبر البريد الإلكتروني',
      subtitle: 'رسائل بريد مزيفة تطلب كلمات مرور أو بيانات',
      description: 'مخصص لحالات الإيميلات المشبوهة التي تطلب منك الضغط على رابط أو تحديث الحساب.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: إيميل تغيير كلمة المرور'),
        ReportField(key: 'sender', label: 'البريد المرسل', hint: 'أدخل البريد الإلكتروني للمرسل'),
        ReportField(key: 'subject', label: 'عنوان الرسالة', hint: 'أدخل عنوان الإيميل'),
        ReportField(key: 'details', label: 'تفاصيل إضافية', hint: 'اشرح سبب الشك', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'bank_impersonation',
      title: 'انتحال صفة بنك',
      subtitle: 'رسائل أو اتصالات تدّعي أنها من بنك',
      description: 'للبلاغ عن أي جهة ادعت أنها بنك وطلبت OTP أو بيانات بنكية أو تحويل مالي.',
      riskLevel: 'حرج',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: انتحال بنك محلي'),
        ReportField(key: 'channel', label: 'قناة التواصل', hint: 'SMS / WhatsApp / مكالمة'),
        ReportField(key: 'bank_name', label: 'اسم البنك المذكور', hint: 'أدخل الاسم الظاهر في الرسالة'),
        ReportField(key: 'details', label: 'وصف الحالة', hint: 'اشرح ما حدث', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'whatsapp_scams',
      title: 'احتيال واتساب',
      subtitle: 'رسائل جوائز وهمية أو طلبات مساعدة عاجلة',
      description: 'اختر هذا البلاغ إذا وصلك احتيال عبر واتساب من رقم أو حساب غير موثوق.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: رسالة جائزة وهمية'),
        ReportField(key: 'whatsapp_number', label: 'رقم واتساب', hint: 'أدخل الرقم أو اسم الحساب'),
        ReportField(key: 'content', label: 'محتوى الرسالة', hint: 'انسخ الرسالة أو صفها', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'suspicious_links',
      title: 'روابط مشبوهة',
      subtitle: 'روابط دفع أو تسجيل دخول مزيفة',
      description: 'للإبلاغ عن أي رابط يبدو احتياليًا أو يقود إلى صفحة تقلد جهة معروفة.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: رابط دفع مزيف'),
        ReportField(key: 'link', label: 'الرابط', hint: 'ألصق الرابط بالكامل'),
        ReportField(key: 'source', label: 'مصدر الرابط', hint: 'SMS / Email / Social Media'),
        ReportField(key: 'details', label: 'ملاحظات', hint: 'اشرح أين وصل الرابط وكيف', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'account_hacking',
      title: 'اختراق حساب',
      subtitle: 'الوصول غير المصرح به إلى حساباتك',
      description: 'إذا تم اختراق بريدك أو فيسبوك أو أي حساب شخصي آخر، استخدم هذا البلاغ.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: اختراق حساب فيسبوك'),
        ReportField(key: 'platform', label: 'المنصة', hint: 'Facebook / Gmail / Instagram'),
        ReportField(key: 'incident_date', label: 'تاريخ الملاحظة', hint: 'متى اكتشفت المشكلة؟'),
        ReportField(key: 'details', label: 'تفاصيل الاختراق', hint: 'اشرح ما حدث', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'identity_theft',
      title: 'سرقة هوية',
      subtitle: 'استخدام بياناتك الشخصية بشكل غير قانوني',
      description: 'اختر هذا البلاغ إذا تم استخدام اسمك أو هويتك أو بياناتك في نشاط احتيالي.',
      riskLevel: 'حرج',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: استخدام بياناتي في حساب مزيف'),
        ReportField(key: 'used_data', label: 'البيانات المستخدمة', hint: 'هوية / اسم / رقم هاتف'),
        ReportField(key: 'details', label: 'تفاصيل الحالة', hint: 'اشرح أين تم استخدام بياناتك', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'shopping_fraud',
      title: 'احتيال التسوق الإلكتروني',
      subtitle: 'متاجر وهمية أو طلبات دفع مسبق مشبوهة',
      description: 'للإبلاغ عن متجر أو صفحة بيع مشبوهة طلبت منك الدفع ولم تسلّم الخدمة أو المنتج.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: متجر إنستغرام وهمي'),
        ReportField(key: 'store_name', label: 'اسم المتجر أو الصفحة', hint: 'أدخل الاسم إن وجد'),
        ReportField(key: 'amount', label: 'المبلغ المدفوع', hint: 'اختياري', required: false),
        ReportField(key: 'details', label: 'تفاصيل البلاغ', hint: 'اشرح ما حدث', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'blackmail',
      title: 'ابتزاز / Blackmail',
      subtitle: 'تهديد بنشر محتوى خاص مقابل مال أو طلبات',
      description: 'للإبلاغ عن أي محاولة ابتزاز رقمي أو تهديد أو ضغط لنشر صور أو معلومات شخصية.',
      riskLevel: 'حرج',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: ابتزاز عبر تيليجرام'),
        ReportField(key: 'channel', label: 'وسيلة التواصل', hint: 'Telegram / Instagram / Email'),
        ReportField(key: 'details', label: 'تفاصيل التهديد', hint: 'اشرح التهديد باختصار', maxLines: 5),
      ],
    ),
    ReportCategory(
      id: 'fake_gov',
      title: 'رسائل حكومية مزيفة',
      subtitle: 'رسائل تنتحل صفة جهة رسمية',
      description: 'إذا وصلك إشعار أو رسالة تدعي أنها من جهة حكومية وتطلب دفعًا أو معلومات حساسة.',
      riskLevel: 'حرج',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: رسالة مخالفة حكومية مزيفة'),
        ReportField(key: 'source', label: 'مصدر الرسالة', hint: 'SMS / WhatsApp / Email'),
        ReportField(key: 'details', label: 'محتوى الرسالة', hint: 'انسخ النص أو صفه', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'qr_scam',
      title: 'احتيال QR',
      subtitle: 'رمز QR يقود إلى صفحة أو دفع احتيالي',
      description: 'أبلغ عن أي كود QR يوجّهك إلى صفحة مزيفة أو طلب مالي غير موثوق.',
      riskLevel: 'مرتفع',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: QR دفع مزيف'),
        ReportField(key: 'location', label: 'مكان العثور على الرمز', hint: 'مثال: متجر / منشور / رسالة'),
        ReportField(key: 'details', label: 'تفاصيل البلاغ', hint: 'اشرح كيف استخدمت الرمز', maxLines: 4),
      ],
    ),
    ReportCategory(
      id: 'deepfake',
      title: 'محتوى Deepfake',
      subtitle: 'صورة أو محتوى مزيف مولّد بالذكاء الاصطناعي',
      description: 'استخدم هذا الخيار عند الاشتباه بأن الصورة مزيفة أو مولدة بالذكاء الاصطناعي.',
      riskLevel: 'حرج',
      fields: [
        ReportField(key: 'title', label: 'عنوان البلاغ', hint: 'مثال: صورة شخصية مزيفة'),
        ReportField(key: 'source', label: 'مصدر الصورة', hint: 'منصة أو رابط المصدر'),
        ReportField(key: 'details', label: 'وصف الحالة', hint: 'اشرح لماذا تعتقد أنها مزيفة', maxLines: 4),
      ],
    ),
  ];

static final reports = <IncidentReport>[
  IncidentReport(
    incidentId: 1024,
    reporterUserId: 1,
    title: 'روابط مشبوهة',
    description: 'وصلني رابط دفع عبر رسالة نصية.',
    statusKey: 'SUBMITTED',
    incidentDate: DateTime(2026, 4, 22),
  ),
  IncidentReport(
    incidentId: 1019,
    reporterUserId: 1,
    title: 'اختراق حساب',
    description: 'تم تغيير كلمة مرور بريدي الإلكتروني.',
    statusKey: 'UNDER_REVIEW',
    incidentDate: DateTime(2026, 4, 20),
  ),
  IncidentReport(
    incidentId: 1008,
    reporterUserId: 1,
    title: 'انتحال صفة بنك',
    description: 'مكالمة تطلب رمز OTP بحجة تحديث الحساب.',
    statusKey: 'IN_ANALYSIS',
    incidentDate: DateTime(2026, 4, 16),
  ),
  IncidentReport(
    incidentId: 991,
    reporterUserId: 1,
    title: 'احتيال واتساب',
    description: 'حساب يطلب تحويل مبلغ بشكل عاجل.',
    statusKey: 'RESOLVED',
    incidentDate: DateTime(2026, 4, 11),
  ),
];

  static const deepfakeHistory = <DeepfakeScan>[
    DeepfakeScan(id: 'DF-201', fileName: 'profile_image_01.jpg', result: 'Fake', confidence: 0.97, createdAt: '21 أبريل 2026'),
    DeepfakeScan(id: 'DF-198', fileName: 'official_photo.png', result: 'Real', confidence: 0.89, createdAt: '18 أبريل 2026'),
    DeepfakeScan(id: 'DF-190', fileName: 'shared_image_7.jpg', result: 'Fake', confidence: 0.93, createdAt: '14 أبريل 2026'),
  ];

  static String statusLabel(String statusKey) {
    switch (statusKey) {
      case 'SUBMITTED':
        return 'تم الإرسال';
      case 'UNDER_REVIEW':
        return 'قيد المراجعة';
      case 'IN_ANALYSIS':
        return 'قيد التحليل';
      case 'RESOLVED':
        return 'تم الحل';
      case 'REJECTED':
        return 'مرفوض';
      case 'CLOSED':
        return 'مغلق';
      default:
        return statusKey;
    }
  }
}
