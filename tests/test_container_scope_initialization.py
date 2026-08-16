from pathlib import Path
import unittest


SOURCE = Path("addons/tscn_scanner/runtime/container_scope.gd").read_text()
INITIALIZE = SOURCE.split("func _ensure_initialized() -> void:", 1)[1].split(
    "func _inject_dependencies() -> bool:", 1
)[0]


class ContainerScopeInitializationTest(unittest.TestCase):
    def test_root_scope_reaches_container_creation_without_parent_lookup(self) -> None:
        parent_branch = INITIALIZE.index("if not definition.parent_scope_id.is_empty():")
        container_creation = INITIALIZE.index(
            "_container = InjectionContainer.new(parent_container)"
        )

        self.assertLess(parent_branch, container_creation)
        self.assertIn("var parent_container: InjectionContainer = null", INITIALIZE)

    def test_child_initializes_parent_and_uses_its_container(self) -> None:
        self.assertIn("var parent_scope := _find_parent_scope()", INITIALIZE)
        self.assertIn("parent_scope._ensure_initialized()", INITIALIZE)
        self.assertIn("parent_container = parent_scope._container", INITIALIZE)

    def test_missing_parent_starts_initialization_retry(self) -> None:
        missing_parent_branch = INITIALIZE.split(
            "if parent_scope == null:", 1
        )[1].split("parent_scope._ensure_initialized()", 1)[0]

        self.assertIn("_start_initialization_retry()", missing_parent_branch)
        self.assertIn("return", missing_parent_branch)

    def test_missing_scope_definition_is_a_configuration_error(self) -> None:
        definition_check = INITIALIZE.split("if definition == null:", 1)[1].split(
            "var parent_container", 1
        )[0]

        self.assertIn("push_error", definition_check)
        self.assertIn("_stop_initialization_retry()", definition_check)
        self.assertNotIn("_start_initialization_retry()", definition_check)
        self.assertIn("return", definition_check)


if __name__ == "__main__":
    unittest.main()
