import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import openai_relay


class RelayHelperTests(unittest.TestCase):
    def test_sanitize_sentence_strips_control_nulls(self):
        self.assertEqual(openai_relay.sanitize_sentence("  hi\x00 there  "), "hi there")

    def test_clamp_confidence_bounds_values(self):
        self.assertEqual(openai_relay.clamp_confidence(2), 1.0)
        self.assertEqual(openai_relay.clamp_confidence(-1), 0.0)
        self.assertEqual(openai_relay.clamp_confidence("bad"), 0.9)

    def test_parse_model_output_normalizes_result(self):
        payload = {
            "output": [
                {
                    "content": [
                        {
                            "type": "output_text",
                            "text": '{"corrected": "  I have an apple.  ", "confidence": 2}',
                        }
                    ]
                }
            ]
        }

        result = openai_relay.parse_model_output(payload)

        self.assertEqual(result["corrected"], "I have an apple.")
        self.assertEqual(result["confidence"], 1.0)


if __name__ == "__main__":
    unittest.main()
