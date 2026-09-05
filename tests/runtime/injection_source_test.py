from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
METHOD_READER = ROOT / "addons/katamusubi/runtime/injection/method_reader.gd"
INSTANCE_INJECTOR = ROOT / "addons/katamusubi/runtime/injection/instance_injector.gd"


class InjectionSourceTest(unittest.TestCase):
    def test_method_reader_does_not_report_an_unresolved_global_class(self) -> None:
        source = METHOD_READER.read_text(encoding="utf-8")
        method = source.split("func _get_global_class_script", maxsplit=1)[1]

        self.assertNotIn("push_error", method)
        self.assertIn("return null", method)

    def test_override_is_applied_before_the_final_type_check(self) -> None:
        source = INSTANCE_INJECTOR.read_text(encoding="utf-8")
        loop = source.split("for argument in arguments:", maxsplit=1)[1]

        override_position = loop.index("if args_override_dict.has(key):")
        unresolved_position = loop.index(
            "if service_type == null:\n\t\t\tpush_error", override_position
        )
        self.assertLess(override_position, unresolved_position)

    def test_final_error_explains_both_ways_to_supply_the_type(self) -> None:
        source = INSTANCE_INJECTOR.read_text(encoding="utf-8")

        self.assertIn("グローバルクラスとして宣言されていない", source)
        self.assertIn("型オーバーライドが指定されていません", source)


if __name__ == "__main__":
    unittest.main()
