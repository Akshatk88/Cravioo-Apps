/// CMS page served by `GET /food/pages/:key?role=restaurant`
/// (keys: `privacy`, `terms`, `support`). `data` is null on the backend when
/// the admin has not published the page yet — [PageContentModel.empty] covers it.
class PageContentModel {
  const PageContentModel({
    required this.title,
    required this.content,
    required this.updatedAt,
    required this.contactNumber,
    required this.email,
    required this.faqs,
  });

  factory PageContentModel.empty(String fallbackTitle) => PageContentModel(
    title: fallbackTitle,
    content: '',
    updatedAt: null,
    contactNumber: '',
    email: '',
    faqs: const [],
  );

  factory PageContentModel.fromJson(
    Map<String, dynamic> json, {
    required String fallbackTitle,
  }) {
    final rawFaqs = json['faqs'];
    final faqs = <PageFaq>[];
    if (rawFaqs is List) {
      for (final item in rawFaqs) {
        if (item is Map) {
          final q = (item['question'] ?? '').toString().trim();
          final a = (item['answer'] ?? '').toString().trim();
          if (q.isNotEmpty || a.isNotEmpty) {
            faqs.add(PageFaq(question: q, answer: a));
          }
        }
      }
    }
    final title = (json['title'] ?? '').toString().trim();
    return PageContentModel(
      title: title.isEmpty ? fallbackTitle : title,
      content: (json['content'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
      contactNumber: (json['contactNumber'] ?? '').toString().trim(),
      email: (json['email'] ?? '').toString().trim(),
      faqs: faqs,
    );
  }

  final String title;

  /// HTML authored in the admin panel.
  final String content;
  final DateTime? updatedAt;
  final String contactNumber;
  final String email;
  final List<PageFaq> faqs;

  bool get isEmpty =>
      content.trim().isEmpty &&
      faqs.isEmpty &&
      contactNumber.isEmpty &&
      email.isEmpty;
}

class PageFaq {
  const PageFaq({required this.question, required this.answer});

  final String question;

  /// HTML.
  final String answer;
}
