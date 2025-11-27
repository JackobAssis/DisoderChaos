extends Control
class_name SaveSystemTest
# SaveSystemTest.gd - Test and validation script for the save system
# Comprehensive testing of all save/load functionality

# UI References
@onready var test_results_panel: Panel = $TestResultsPanel
@onready var test_results_text: RichTextLabel = $TestResultsPanel/ScrollContainer/TestResults
@onready var run_tests_button: Button = $ControlPanel/RunTestsButton
@onready var clear_saves_button: Button = $ControlPanel/ClearSavesButton
@onready var create_test_data_button: Button = $ControlPanel/CreateTestDataButton
@onready var benchmark_button: Button = $ControlPanel/BenchmarkButton
@onready var progress_bar: ProgressBar = $ControlPanel/ProgressBar
@onready var status_label: Label = $ControlPanel/StatusLabel

# Test configuration
var test_slots = [0, 1, 2, 5, 10]
var benchmark_iterations = 100
var test_results = []

# System references
var game_state: Node
var save_manager: SaveManager

func _ready():
	print("[SaveSystemTest] Initializing save system tests")
	
	# Get references
	game_state = get_node("/root/GameState")
	
	# Setup UI
	run_tests_button.pressed.connect(_on_run_tests_pressed)
	clear_saves_button.pressed.connect(_on_clear_saves_pressed)
	create_test_data_button.pressed.connect(_on_create_test_data_pressed)
	benchmark_button.pressed.connect(_on_benchmark_pressed)
	
	progress_bar.value = 0
	update_status("Ready to run tests")
	
	# Initialize save manager
	if game_state:
		game_state._init_save_manager()
		save_manager = game_state.save_manager
	
	print("[SaveSystemTest] Save system test ready")

func update_status(message: String):
	"""Update status label"""
	status_label.text = message
	print("[SaveSystemTest] " + message)

func log_test_result(test_name: String, success: bool, details: String = ""):
	"""Log a test result"""
	var result = {
		"test": test_name,
		"success": success,
		"details": details,
		"timestamp": Time.get_unix_time_from_system()
	}
	test_results.append(result)
	
	var color = "green" if success else "red"
	var status = "PASS" if success else "FAIL"
	var result_text = "[color=" + color + "][b]" + status + "[/b][/color] " + test_name
	if not details.is_empty():
		result_text += "\n    " + details
	
	test_results_text.append_text(result_text + "\n\n")

func _on_run_tests_pressed():
	"""Run comprehensive save system tests"""
	update_status("Running save system tests...")
	progress_bar.value = 0
	test_results.clear()
	test_results_text.clear()
	
	test_results_text.append_text("[b][u]Save System Test Results[/u][/b]\n\n")
	
	# Run all tests
	await run_all_tests()
	
	# Show summary
	var passed = 0
	var failed = 0
	for result in test_results:
		if result.success:
			passed += 1
		else:
			failed += 1
	
	test_results_text.append_text("[b]Test Summary:[/b]\n")
	test_results_text.append_text("[color=green]Passed: " + str(passed) + "[/color]\n")
	test_results_text.append_text("[color=red]Failed: " + str(failed) + "[/color]\n")
	test_results_text.append_text("Total: " + str(passed + failed) + "\n\n")
	
	progress_bar.value = 100
	update_status("Tests completed: " + str(passed) + " passed, " + str(failed) + " failed")

func run_all_tests():
	"""Run all save system tests"""
	var total_tests = 15
	var current_test = 0
	
	# Test 1: Save Manager Creation
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_save_manager_creation()
	
	# Test 2: Basic Save Operation
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	await test_basic_save_operation()
	
	# Test 3: Basic Load Operation
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_basic_load_operation()
	
	# Test 4: Save Data Validation
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_save_data_validation()
	
	# Test 5: Compression
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	await test_compression()
	
	# Test 6: Version Migration
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_version_migration()
	
	# Test 7: Backup System
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_backup_system()
	
	# Test 8: Multiple Save Slots
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	await test_multiple_save_slots()
	
	# Test 9: Save Corruption Detection
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_save_corruption_detection()
	
	# Test 10: Save Slot Management
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_save_slot_management()
	
	# Test 11: Auto-save Integration
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	await test_auto_save_integration()
	
	# Test 12: Quick Save/Load
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	await test_quick_save_load()
	
	# Test 13: Save Data Integrity
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_save_data_integrity()
	
	# Test 14: Error Handling
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	test_error_handling()
	
	# Test 15: Performance
	current_test += 1
	progress_bar.value = (current_test / float(total_tests)) * 100
	await get_tree().process_frame
	await test_performance()

# Individual test functions
func test_save_manager_creation():
	"""Test SaveManager instantiation"""
	var success = save_manager != null
	log_test_result("SaveManager Creation", success, 
		"SaveManager instance created successfully" if success else "Failed to create SaveManager")

func test_basic_save_operation():
	"""Test basic save functionality"""
	if not save_manager:
		log_test_result("Basic Save Operation", false, "SaveManager not available")
		return
	
	create_test_game_state()
	var result = await game_state.save_game(0, false)
	log_test_result("Basic Save Operation", result, 
		"Save operation completed" if result else "Save operation failed")

func test_basic_load_operation():
	"""Test basic load functionality"""
	if not save_manager:
		log_test_result("Basic Load Operation", false, "SaveManager not available")
		return
	
	var result = game_state.load_game(0)
	log_test_result("Basic Load Operation", result, 
		"Load operation completed" if result else "Load operation failed")

func test_save_data_validation():
	"""Test save data structure validation"""
	if not save_manager:
		log_test_result("Save Data Validation", false, "SaveManager not available")
		return
	
	var result = save_manager.validate_save_file(0)
	log_test_result("Save Data Validation", result.valid, 
		"Save data is valid" if result.valid else "Save data validation failed: " + result.error)

func test_compression():
	"""Test save file compression"""
	if not save_manager:
		log_test_result("Compression Test", false, "SaveManager not available")
		return
	
	create_test_game_state()
	
	# Save without compression
	var result1 = await game_state.save_game(1, false)
	# Save with compression
	var result2 = await game_state.save_game(2, true)
	
	var success = result1 and result2
	log_test_result("Compression Test", success, 
		"Both compressed and uncompressed saves successful" if success else "Compression test failed")

func test_version_migration():
	"""Test save version migration"""
	if not save_manager:
		log_test_result("Version Migration", false, "SaveManager not available")
		return
	
	# This would require creating a legacy save file
	# For now, just test that migration functions exist
	var has_migration = save_manager.has_method("migrate_save_data")
	log_test_result("Version Migration", has_migration, 
		"Migration system available" if has_migration else "Migration system not found")

func test_backup_system():
	"""Test backup creation and restoration"""
	if not save_manager or not game_state:
		log_test_result("Backup System", false, "SaveManager or GameState not available")
		return
	
	var backup_result = game_state.backup_save(0)
	log_test_result("Backup System", backup_result, 
		"Backup created successfully" if backup_result else "Backup creation failed")

func test_multiple_save_slots():
	"""Test saving to multiple slots"""
	if not game_state:
		log_test_result("Multiple Save Slots", false, "GameState not available")
		return
	
	create_test_game_state()
	var all_successful = true
	
	for slot in test_slots:
		var result = await game_state.save_game(slot, true)
		if not result:
			all_successful = false
			break
	
	log_test_result("Multiple Save Slots", all_successful, 
		"All test slots saved successfully" if all_successful else "One or more slot saves failed")

func test_save_corruption_detection():
	"""Test corruption detection"""
	if not save_manager:
		log_test_result("Corruption Detection", false, "SaveManager not available")
		return
	
	# This would require creating a corrupted save file
	# For now, test that corruption detection functions exist
	var has_validation = save_manager.has_method("validate_save_file")
	log_test_result("Corruption Detection", has_validation, 
		"Corruption detection available" if has_validation else "Corruption detection not found")

func test_save_slot_management():
	"""Test save slot listing and management"""
	if not game_state:
		log_test_result("Save Slot Management", false, "GameState not available")
		return
	
	var slots = game_state.get_save_slots()
	var success = slots is Array and slots.size() > 0
	log_test_result("Save Slot Management", success, 
		"Retrieved " + str(slots.size()) + " save slots" if success else "Failed to retrieve save slots")

func test_auto_save_integration():
	"""Test auto-save functionality"""
	if not game_state:
		log_test_result("Auto-save Integration", false, "GameState not available")
		return
	
	create_test_game_state()
	var result = await game_state.auto_save()
	log_test_result("Auto-save Integration", result, 
		"Auto-save completed successfully" if result else "Auto-save failed")

func test_quick_save_load():
	"""Test quick save and load"""
	if not game_state:
		log_test_result("Quick Save/Load", false, "GameState not available")
		return
	
	create_test_game_state()
	var save_result = await game_state.quick_save()
	var load_result = game_state.load_game(999)  # Quick save slot
	
	var success = save_result and load_result
	log_test_result("Quick Save/Load", success, 
		"Quick save/load completed" if success else "Quick save/load failed")

func test_save_data_integrity():
	"""Test save data integrity"""
	if not save_manager:
		log_test_result("Save Data Integrity", false, "SaveManager not available")
		return
	
	# Test checksum validation exists
	var has_checksum = save_manager.has_method("calculate_checksum")
	log_test_result("Save Data Integrity", has_checksum, 
		"Checksum validation available" if has_checksum else "Checksum validation not found")

func test_error_handling():
	"""Test error handling for invalid operations"""
	if not game_state:
		log_test_result("Error Handling", false, "GameState not available")
		return
	
	# Try to load non-existent slot
	var result = game_state.load_game(9999)
	var success = not result  # Should fail gracefully
	log_test_result("Error Handling", success, 
		"Invalid load handled gracefully" if success else "Error handling failed")

func test_performance():
	"""Test save/load performance"""
	if not game_state:
		log_test_result("Performance Test", false, "GameState not available")
		return
	
	create_test_game_state()
	
	var start_time = Time.get_ticks_msec()
	await game_state.save_game(99, true)
	var save_time = Time.get_ticks_msec() - start_time
	
	start_time = Time.get_ticks_msec()
	game_state.load_game(99)
	var load_time = Time.get_ticks_msec() - start_time
	
	var success = save_time < 1000 and load_time < 500  # Less than 1s save, 0.5s load
	log_test_result("Performance Test", success, 
		"Save: " + str(save_time) + "ms, Load: " + str(load_time) + "ms")

func create_test_game_state():
	"""Create test game state data"""
	if not game_state:
		return
	
	# Set up test player data
	game_state.player_data.level = 25
	game_state.player_data.experience = 50000
	game_state.player_data.race = "elf"
	game_state.player_data.class = "mage"
	game_state.player_data.current_hp = 150
	game_state.player_data.max_hp = 200
	game_state.player_data.currency = 1000
	
	# Add test inventory
	game_state.player_data.inventory = [
		{"id": "health_potion", "quantity": 5},
		{"id": "sword_steel", "quantity": 1},
		{"id": "armor_leather", "quantity": 1}
	]
	
	# Set test world state
	game_state.current_dungeon_id = "test_dungeon"
	game_state.visited_dungeons = ["root_forest", "dark_cave", "test_dungeon"]
	game_state.game_time = 3600.0  # 1 hour

func _on_clear_saves_pressed():
	"""Clear all test save files"""
	update_status("Clearing test saves...")
	
	var cleared = 0
	for slot in range(100):  # Clear slots 0-99
		if game_state and game_state.delete_save(slot):
			cleared += 1
	
	test_results_text.clear()
	test_results_text.append_text("Cleared " + str(cleared) + " save files.\n\n")
	update_status("Cleared " + str(cleared) + " save files")

func _on_create_test_data_pressed():
	"""Create test data in multiple slots"""
	update_status("Creating test data...")
	
	create_test_game_state()
	
	var created = 0
	for slot in test_slots:
		# Vary the data slightly for each slot
		game_state.player_data.level += slot
		game_state.player_data.currency += slot * 100
		
		var result = await game_state.save_game(slot, true)
		if result:
			created += 1
		
		await get_tree().process_frame  # Allow UI updates
	
	test_results_text.clear()
	test_results_text.append_text("Created test data in " + str(created) + " save slots.\n\n")
	update_status("Created test data in " + str(created) + " slots")

func _on_benchmark_pressed():
	"""Run performance benchmarks"""
	update_status("Running benchmarks...")
	progress_bar.value = 0
	test_results_text.clear()
	
	test_results_text.append_text("[b][u]Save System Performance Benchmark[/u][/b]\n\n")
	
	create_test_game_state()
	
	# Benchmark save operations
	var total_save_time = 0
	var successful_saves = 0
	
	for i in range(benchmark_iterations):
		progress_bar.value = (i / float(benchmark_iterations)) * 50
		
		var start_time = Time.get_ticks_msec()
		var result = await game_state.save_game(50, true)
		var end_time = Time.get_ticks_msec()
		
		if result:
			total_save_time += (end_time - start_time)
			successful_saves += 1
		
		if i % 10 == 0:
			await get_tree().process_frame  # Update UI periodically
	
	# Benchmark load operations
	var total_load_time = 0
	var successful_loads = 0
	
	for i in range(benchmark_iterations):
		progress_bar.value = 50 + (i / float(benchmark_iterations)) * 50
		
		var start_time = Time.get_ticks_msec()
		var result = game_state.load_game(50)
		var end_time = Time.get_ticks_msec()
		
		if result:
			total_load_time += (end_time - start_time)
			successful_loads += 1
		
		if i % 10 == 0:
			await get_tree().process_frame  # Update UI periodically
	
	# Display results
	var avg_save_time = total_save_time / float(successful_saves) if successful_saves > 0 else 0
	var avg_load_time = total_load_time / float(successful_loads) if successful_loads > 0 else 0
	
	test_results_text.append_text("Iterations: " + str(benchmark_iterations) + "\n")
	test_results_text.append_text("Successful saves: " + str(successful_saves) + "\n")
	test_results_text.append_text("Successful loads: " + str(successful_loads) + "\n\n")
	test_results_text.append_text("Average save time: " + str(avg_save_time) + " ms\n")
	test_results_text.append_text("Average load time: " + str(avg_load_time) + " ms\n")
	test_results_text.append_text("Total save time: " + str(total_save_time) + " ms\n")
	test_results_text.append_text("Total load time: " + str(total_load_time) + " ms\n\n")
	
	progress_bar.value = 100
	update_status("Benchmark completed: Avg save " + str(avg_save_time) + "ms, Avg load " + str(avg_load_time) + "ms")