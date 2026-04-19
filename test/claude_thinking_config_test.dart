import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/chat_api_service.dart';

void main() {
  group('Claude thinking config', () {
    test('uses adaptive summarized thinking for claude-opus-4-7', () {
      final body = ChatApiService.buildClaudeThinkingConfigForTest(
        modelId: 'claude-opus-4-7',
        isReasoning: true,
        thinkingBudget: 8000,
      );

      expect(body['thinking'], {'type': 'adaptive', 'display': 'summarized'});
      expect(body['output_config'], {'effort': 'medium'});
    });

    test('uses summarized manual thinking for older Claude models', () {
      final body = ChatApiService.buildClaudeThinkingConfigForTest(
        modelId: 'claude-opus-4-5@20251101',
        isReasoning: true,
        thinkingBudget: 8000,
      );

      expect(body['thinking'], {
        'type': 'enabled',
        'budget_tokens': 8000,
        'display': 'summarized',
      });
      expect(body.containsKey('output_config'), isFalse);
    });

    test('defaults Claude max tokens to 16384 in helper path', () {
      final body = ChatApiService.buildClaudeThinkingConfigForTest(
        modelId: 'claude-opus-4-5@20251101',
        isReasoning: true,
        thinkingBudget: null,
      );

      expect(body['max_tokens'], 16384);
      expect(body['thinking'], {
        'type': 'enabled',
        'budget_tokens': 2048,
        'display': 'summarized',
      });
    });

    test('omits thinking config when reasoning is off', () {
      final body = ChatApiService.buildClaudeThinkingConfigForTest(
        modelId: 'claude-opus-4-7',
        isReasoning: true,
        thinkingBudget: 0,
      );

      expect(body.containsKey('thinking'), isFalse);
      expect(body.containsKey('output_config'), isFalse);
    });
  });
}
