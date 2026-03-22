import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';

void main() {
  test('Assistant roundtrip preserves phase 2 fields', () {
    const assistant = Assistant(
      id: 'a1',
      name: 'Planner',
      useAssistantAvatar: true,
      useAssistantName: true,
      enableRecentChatsReference: true,
      recentChatsSummaryMessageCount: 10,
      isEnabled: false,
      excludeAssistantMessages: true,
      chatFontScale: 1.2,
    );

    final decoded = Assistant.fromJson(assistant.toJson());

    expect(decoded.useAssistantAvatar, isTrue);
    expect(decoded.useAssistantName, isTrue);
    expect(decoded.enableRecentChatsReference, isTrue);
    expect(decoded.recentChatsSummaryMessageCount, 10);
    expect(decoded.isEnabled, isFalse);
    expect(decoded.excludeAssistantMessages, isTrue);
    expect(decoded.chatFontScale, 1.2);
  });

  test(
    'Assistant defaults recent chat summary frequency when missing or invalid',
    () {
      final missing = Assistant.fromJson(<String, dynamic>{
        'id': 'a1',
        'name': 'Planner',
      });
      final invalid = Assistant.fromJson(<String, dynamic>{
        'id': 'a2',
        'name': 'Writer',
        'recentChatsSummaryMessageCount': 0,
      });

      expect(
        missing.recentChatsSummaryMessageCount,
        Assistant.defaultRecentChatsSummaryMessageCount,
      );
      expect(
        invalid.recentChatsSummaryMessageCount,
        Assistant.defaultRecentChatsSummaryMessageCount,
      );
      expect(missing.useAssistantName, isFalse);
    },
  );
}
