import 'package:flutter/material.dart';

class MoveOutThankYouPage extends StatelessWidget {
  const MoveOutThankYouPage(
      {super.key, required this.tenantName, this.chinese = false});
  final String tenantName;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1C67CF);
    final paragraphs = chinese
        ? [
            '感谢您选择在这里居住，也感谢您在租住期间给予我的信任。很高兴能与您相处，我真心珍惜这段缘分。',
            '如果您在居住期间遇到任何不便，我在此诚挚地向您道歉。感谢您的耐心与理解。',
            '在您迈向人生下一个阶段之际，祝愿您一切顺心、生活舒适，找到一个真正有家的感觉的地方。希望将来我们有机会再次相遇，也期待有一天能再次欢迎您回来。',
            '请多保重，再次感谢您。',
          ]
        : [
            'Thank you for choosing to stay with us and for trusting me throughout your tenancy. It has been a pleasure having you here, and I truly appreciate the time we’ve shared.',
            'If anything during your stay caused you inconvenience, I’m sincerely sorry. Thank you for your patience and understanding.',
            'As you move on to your next chapter, I wish you happiness, comfort, and a place that feels like home. I hope our paths cross again—it would be lovely to welcome you back someday.',
            'Take care, and thank you once again.',
          ];
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F6FA),
        foregroundColor: blue,
        leading: IconButton(
            tooltip: chinese ? '返回' : 'Back',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context)),
        title: Text(chinese ? '申请已提交' : 'Request submitted'),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.favorite_outline_rounded,
                        color: blue, size: 38),
                    const SizedBox(height: 20),
                    Text(chinese ? '亲爱的$tenantName，' : 'Hi $tenantName,',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    for (final paragraph in paragraphs)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Text(paragraph,
                              style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.65,
                                  color: Color(0xFF334155)))),
                    Text(chinese ? '诚挚祝福，\nAlex' : 'Warm regards,\nAlex',
                        style: const TextStyle(
                            fontSize: 17,
                            height: 1.6,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE8F2FF),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(chinese
                                      ? '搬出申请已提交，等待业主确认。'
                                      : 'Your move-out request has been submitted and is awaiting owner confirmation.')),
                            ])),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(chinese ? '完成' : 'Done'))),
                  ],
                )),
          ),
        )),
      )),
    );
  }
}
