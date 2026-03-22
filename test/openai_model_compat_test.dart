import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/utils/openai_model_compat.dart';

void main() {
  group('openAINormalizeReasoningEffort', () {
    test('maps off to none for GPT-5.4', () {
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.4'), 'none');
    });

    test('falls back from xhigh to high when unsupported', () {
      expect(openAINormalizeReasoningEffort('xhigh', 'gpt-5.1'), 'high');
    });

    test('keeps xhigh for supported GPT-5.2', () {
      expect(openAINormalizeReasoningEffort('xhigh', 'gpt-5.2'), 'xhigh');
    });
  });

  group('openAIAllowsSamplingParams', () {
    test('disallows sampling for GPT-5.4 with high effort', () {
      expect(openAIAllowsSamplingParams('gpt-5.4', effort: 'high'), isFalse);
    });

    test('allows sampling for GPT-5.4 with off effort', () {
      expect(openAIAllowsSamplingParams('gpt-5.4', effort: 'off'), isTrue);
    });

    test('allows sampling for non GPT-5 models', () {
      expect(openAIAllowsSamplingParams('gpt-4o', effort: 'high'), isTrue);
    });
  });
}
