extends SceneTree


const TEST_SCRIPTS: PackedStringArray = [
	"res://tests/editor/scope_index_test.gd",
	"res://tests/runtime/container/service_registration_test.gd",
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var failed_suites: PackedStringArray = []
	for test_script in TEST_SCRIPTS:
		print("\n=== %s ===" % test_script)
		var exit_code := OS.execute(
			OS.get_executable_path(),
			["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", test_script],
		)
		if exit_code != 0:
			failed_suites.append("%s (exit code: %d)" % [test_script, exit_code])

	# 子プロセス内の非同期テストと、その最終フレームの出力が完了してから集計します。
	await process_frame
	if failed_suites.is_empty():
		print("\nAll test suites passed")
		quit()
		return

	for failed_suite in failed_suites:
		push_error("Test suite failed: %s" % failed_suite)
	quit(1)
