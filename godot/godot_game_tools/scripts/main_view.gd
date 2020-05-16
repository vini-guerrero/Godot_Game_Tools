tool 

extends ScrollContainer

# Buttons
onready var export_filepath_btn = $HBoxContainer/VBoxContainer/SetExportPathBtn
onready var load_file_btn = $HBoxContainer/VBoxContainer/SelectCharFileBtn
onready var export_file_btn = $HBoxContainer/VBoxContainer/StateMachineExportBtn
onready var armature_setup_btn = $HBoxContainer/VBoxContainer/ArmatureSetupBtn
onready var statemachine_setup_btn = $HBoxContainer/VBoxContainer/StateMachineSetupBtn

# Import Settings
onready var load_file = $HBoxContainer/VBoxContainer/CharFilePath/LoadFileDialog
onready var load_file_label = $HBoxContainer/VBoxContainer/CharFilePath/PathField
onready var armature_collision_toggle = $HBoxContainer/VBoxContainer/ArmatureSettings/CollisionShapeToggle
onready var armature_rootmotion_view_toggle = $HBoxContainer/VBoxContainer/ArmatureSettings/RootMotionToggle

# Export Settings
onready var export_file = $HBoxContainer/VBoxContainer/ExportPresetPath/ExportPathFileDialog
onready var export_file_preset = $HBoxContainer/VBoxContainer/ExportPresetName/PresetName
onready var export_file_author = $HBoxContainer/VBoxContainer/ExportPresetAuthor/PresetAuthor
onready var export_file_version = $HBoxContainer/VBoxContainer/ExportPresetVersion/PresetVersion
onready var export_file_path = $HBoxContainer/VBoxContainer/ExportPresetPath/ExportPathField


var popup_window_size : Vector2 = Vector2(1000, 1000)
var character_file : Dictionary
var armature_collision : bool = false
var armature_rootmotion_view : bool = false
var animation_tree_node_name : String = "AnimationTree"
var statemachine_name : String = "StateMachine"
var states : Array = [
	"Idle",
	"Walking",
	"Running",
	"BlendSpace",
	"Node1D"
]

func _ready() -> void:
	armature_collision_toggle.connect("toggled", self, "_toggleArmatureCollision")
	armature_rootmotion_view_toggle.connect("toggled", self, "_toggleArmatureRootMotionView")
	statemachine_setup_btn.connect("button_down", self, "_stateMachineSetup")
	armature_setup_btn.connect("button_down", self, "_armatureSetup")
	load_file_btn.connect("button_down", self, "_loadCharFile")
	export_filepath_btn.connect("button_down", self, "_loadCharFileExport")
	load_file.connect("file_selected", self, "_fileSelected")
	export_file.connect("dir_selected", self, "_exportPathSelected")
	export_file_btn.connect("button_down", self, "_generateAnimationTreeExport")

func _armatureSetup() -> void:
	if not character_file.empty():
		var current_scene = _getCurrentScene()
		var root_motion_bone = character_file.rootMotionBone
		var state_machine_name = character_file.nodeName
		_addArmatureBasicSetup(current_scene, root_motion_bone, state_machine_name)


func _stateMachineSetup() -> void:
	if not character_file.empty():
		var current_scene = _getCurrentScene()
		_addStateMachine(current_scene, character_file)


func _fileSelected(_filePath : String) -> void:
	load_file_label.text = str(_filePath)
	var charfile_content = _readJsonData(_filePath)
	var current_scene = _getCurrentScene()
	if charfile_content: character_file = charfile_content


func _readJsonData(_filePath : String) -> Dictionary:
	var file = File.new()
	file.open(_filePath, file.READ)
	var json = JSON.parse(file.get_as_text())
	file.close()
	return json.result


func _exportPathSelected(_filePath : String): export_file_path.text = str(_filePath)
func _toggleArmatureCollision(new_value : bool): armature_collision = new_value
func _toggleArmatureRootMotionView(new_value : bool): armature_rootmotion_view = new_value
func _loadCharFile(): load_file.popup_centered_minsize(popup_window_size)
func _loadCharFileExport(): export_file.popup_centered_minsize(popup_window_size)
func _getCurrentScene(): return get_tree().get_edited_scene_root()


func _addArmatureBasicSetup(current_scene, rootmotion_bone, statemachine_name) -> void:
	if current_scene:
		# Script Variables
#		var armatureSkeleton = "Armature/Skeleton:"
#		var armaturePath = str(armatureSkeleton) + str(rootmotion_bone)
#		var rootMotionTrackPath = armaturePath
		var animationPlayerPath = current_scene.find_node("AnimationPlayer", true).get_path()
		var animationNodeName : String = str(statemachine_name)
		var animationNodePosition : Vector2 =  Vector2(40, 80)
		var outputNodePosition : Vector2 =  Vector2(400, 80)
		var outputNode : String = "output"
		var blendTree : AnimationNodeBlendTree
		var stateMachine : AnimationNodeStateMachine
		var animationTree : AnimationTree
		var rootMotionView: RootMotionView
		var characterCollision : CollisionShape
		var characterCollisionCapsule : CapsuleShape
		
		# Collision Shape
		if armature_collision:
			characterCollision = CollisionShape.new()
			characterCollisionCapsule = CapsuleShape.new()
			characterCollisionCapsule.radius = 0.5
			characterCollision.set_shape(characterCollisionCapsule)
			characterCollision.rotation_degrees.x = 90
			characterCollision.translation.y = 1
			current_scene.add_child(characterCollision)
			characterCollision.set_owner(current_scene)
	
		# Blend Tree
		blendTree = AnimationNodeBlendTree.new()
		stateMachine = AnimationNodeStateMachine.new()
		blendTree.add_node(animationNodeName, stateMachine, Vector2.ZERO)
		blendTree.connect_node(outputNode, 0, animationNodeName)
		
		# AnimationTree Position
		blendTree.set_node_position(animationNodeName, animationNodePosition)
		blendTree.set_node_position(outputNode, outputNodePosition)

		# Animation Tree
		animationTree = AnimationTree.new()
		animationTree.anim_player = animationPlayerPath
		animationTree.process_mode = AnimationTree.ANIMATION_PROCESS_PHYSICS
#		animationTree.root_motion_track = rootMotionTrackPath
		animationTree.tree_root = blendTree
		animationTree.active = true
		current_scene.add_child(animationTree)
		animationTree.set_owner(current_scene)

		# RootMotion View
		if armature_rootmotion_view:
			rootMotionView = RootMotionView.new()
	#		rootMotionView.animation_path = animationPlayerPath
			current_scene.add_child(rootMotionView)
			rootMotionView.set_owner(current_scene)


func _addStateNode(stateMachine, animation, statePosition) -> void:
	var newAnimation = AnimationNodeAnimation.new()
	newAnimation.animation = animation
	stateMachine.add_node(animation, newAnimation)
	stateMachine.set_node_position(animation, statePosition)


func _addStateMachine(currentScene, stateMachineData) -> void:
	# State Machine Params
	var stateMachineNodeName = stateMachineData.nodeName
	var states = stateMachineData.states
	var stateTransitions = stateMachineData.stateTransitions

	# Get Animation Tree
	var animationTreeNode = currentScene.find_node(animation_tree_node_name, true).tree_root
	if animationTreeNode.has_node(stateMachineNodeName):

		# Procedural StateMachine Generation
		var stateMachine = animationTreeNode.get_node(stateMachineNodeName)
		var initialAnimation
		# Generate States
		for state in states: 
			var stateName = state["name"]
			if not initialAnimation: initialAnimation = stateName
			var statePosition = Vector2(state["positionX"], state["positionY"])
			_addStateNode(stateMachine, stateName, statePosition)

		# Connect States Transitions
		for transition in stateTransitions:
			var fromT = transition["from"]
			var toT = transition["to"]
			var xFadeTimeT = transition["xFadeTime"]
			var switchModeIndex = transition["switchMode"]
			_addStateTransition(stateMachine, fromT, toT, xFadeTimeT, switchModeIndex)

		# Add Animation States
		for state in states:
			# Remove Loop Names
			var stateName = state["name"]
			var animationNameLoopLess = stateName.replace("-loop", "")
			stateMachine.rename_node(stateName, animationNameLoopLess)

		# Setup Initial Animation
		if initialAnimation: 
			initialAnimation = initialAnimation.replace("-loop", "")
			stateMachine.set_start_node(initialAnimation)


func _addStateTransition(stateMachine, from, to, xFadeTime, switchModeIndex) -> void:
	var newTransition = AnimationNodeStateMachineTransition.new()
	newTransition.xfade_time = xFadeTime
	var switchMode
	if switchModeIndex == 0: switchMode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
	if switchModeIndex == 1: switchMode = AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
	if switchModeIndex == 2: switchMode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
	newTransition.switch_mode = switchMode
	stateMachine.add_transition(from, to, newTransition)


func _generateAnimationTreeExport() -> void:
	# Prepare Export Dictionary
	var animation_tree_preset : Dictionary
	animation_tree_preset["animations"] = []
	animation_tree_preset["stateTransitions"] = []
	animation_tree_preset["states"] = []
	# Get Current Scene
	var current_scene = _getCurrentScene()
	# Get Animation Tree
	var animationTreeNode = current_scene.find_node(animation_tree_node_name, true).tree_root
	if animationTreeNode.has_node(statemachine_name):
		# Procedural StateMachine Generation
		var state_machine = animationTreeNode.get_node(statemachine_name)
		var start_node = state_machine.get_start_node()
		var end_node = state_machine.get_end_node()
		for state in range(states.size()):
			var state_name = states[state]
			var node = state_machine.get_node(state_name)
			# Treat AnimationNodeBlendSpace1D / AnimationNodeBlendSpace2D
			var children_nodes : Dictionary
			children_nodes["points_animations"] = []
			if node is AnimationNodeBlendSpace1D || node is AnimationNodeBlendSpace2D: 
				var points_count = node.get_blend_point_count()
				children_nodes["points_count"] = points_count
				for point in points_count:
					var animation_name = node.get_blend_point_node(point).animation
					var animation_position = node.get_blend_point_position(point)
					var new_animation_point = {
						"index": point,
						"animation": animation_name,
						"position": animation_position
					}
					children_nodes["points_animations"].append(new_animation_point)
			# Remove Unnecessary Props
			if node is AnimationNodeAnimation: children_nodes.erase("points_animations")
			# Export State Transitions
			var node_transition = state_machine.get_transition(state)
			var transition_to = state_machine.get_transition_to(state)
			var transition_from = state_machine.get_transition_from(state)
			var new_transition = {
				"from": transition_from,
				"switchMode": node_transition.switch_mode,
				"xFadeTime": node_transition.xfade_time,
				"to": transition_to
			}
			# Export State
			var node_position = state_machine.get_node_position(state_name)
			var is_start_node : bool
			var is_end_node : bool
			is_start_node = true if state_name == start_node else false
			is_end_node = true if state_name == end_node else false
			var new_state = {
				"name": state_name,
				"positionX": node_position.x,
				"positionY": node_position.y,
				"start": is_start_node,
				"end": is_end_node,
				"children_nodes": children_nodes,
				"type": node.get_class()
			}
			# Export Animations
			animation_tree_preset["animations"].append(state_name)
			animation_tree_preset["states"].append(new_state)
			animation_tree_preset["stateTransitions"].append(new_transition)
			animation_tree_preset["preset_name"] = str(export_file_preset.text)
			animation_tree_preset["preset_creator"] = str(export_file_author.text)
			animation_tree_preset["preset_version"] = str(export_file_version.text)
			animation_tree_preset["preset_creation_date"] = str(_getDatetime())
			
	# Save Local File
	_exportJSONFile(animation_tree_preset)


func _getDatetime() -> String:
	var date_time : String
	var current_time = OS.get_time()
	var hour = str(current_time.hour)
	var minute = str(current_time.minute)
	var seconds = str(current_time.second)
	var current_date = OS.get_datetime()
	var year = str(current_date.year)
	var month = str(current_date.month)
	var day = str(current_date.day)
	date_time = day + "/" + month + "/" + year
	date_time += " " + hour + ":" + minute + ":" + seconds
	return date_time


func _exportJSONFile(data : Dictionary) -> void:
	var save_data = File.new()
	var file_name = str(export_file_path.text) + "/" + str(export_file_preset.text) + ".json"
	save_data.open(file_name, File.WRITE)
	save_data.store_line(to_json(data))
	save_data.close()
