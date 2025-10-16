extends CharacterBody3D

@export var animated_player_path: NodePath = NodePath("../AnimatedPlayer")
@export var torque_strength: float = 100
@export var force_strength: float = 100
@export var position_stiffness: float = 0.5
@export var rotation_stiffness: float = 0.9


var animated_skeleton: Skeleton3D
var ragdoll_skeleton: PhysicalBoneSimulator3D
var ragdoll_hips_bone: PhysicalBone3D
var ragdoll_spine_bone: PhysicalBone3D
var ragdoll_neck_bone: PhysicalBone3D
var ragdoll_head_bone: PhysicalBone3D
var ragdoll_root_rotation: Basis
var animated_player: CharacterBody3D

# Called when the node enters the scene tree for the first time.
func _ready():
	ragdoll_skeleton = $Skeleton_bare/Armature/Skeleton3D/PhysicalBoneSimulator3D
	ragdoll_hips_bone = ragdoll_skeleton.get_node("Physical Bone mixamorig_Hips") as PhysicalBone3D
	ragdoll_spine_bone = ragdoll_skeleton.get_node("Physical Bone mixamorig_Spine") as PhysicalBone3D
	ragdoll_neck_bone = ragdoll_skeleton.get_node("Physical Bone mixamorig_Neck") as PhysicalBone3D
	ragdoll_head_bone = ragdoll_skeleton.get_node("Physical Bone mixamorig_Head") as PhysicalBone3D
	
	animated_player = get_node(animated_player_path)
	animated_skeleton = animated_player.get_node("Skeleton_idle/Armature/Skeleton3D")
	
	$Skeleton_bare/Armature/Skeleton3D/PhysicalBoneSimulator3D.physical_bones_start_simulation()
		# Cache the root rotation of the ragdoll node (the -90° X rotation you applied)
	ragdoll_root_rotation = global_transform.basis
	var animated_player_root_rotation = animated_player.global_transform
	print("Ragdoll root rotation: " + str(ragdoll_root_rotation))
	print("Animated root rotation: " + str(animated_player_root_rotation))

func keep_upright(bone: PhysicalBone3D, strength: float):
	var rid: RID = bone.get_rid()
	var current_up = bone.global_transform.basis.y
	var target_up = Vector3.MODEL_FRONT
	var axis = current_up.cross(target_up)
	var angle = acos(clamp(target_up.dot(current_up), -1.0, 1.0))
	var torque = axis.normalized() * angle * (strength * bone.mass)
	if(angle < .3):
		return
	PhysicsServer3D.body_apply_torque(rid, torque)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	keep_upright(ragdoll_hips_bone, 10)
	keep_upright(ragdoll_spine_bone, 10)
	keep_upright(ragdoll_neck_bone, 2)
	keep_upright(ragdoll_head_bone, 5)
	for bone in ragdoll_skeleton.get_children():
		if not (bone is PhysicalBone3D):
			continue
			
		var bone_name = bone.name
		if bone_name.begins_with("Physical Bone "):
			bone_name = bone_name.substr(14) #14chr long prefix
		var target_idx = animated_skeleton.find_bone(bone_name)
		if target_idx == -1:
			continue
			
		var target_transform = animated_skeleton.get_bone_global_pose(target_idx) * animated_player.global_transform
		
		var current_transform = bone.global_transform * self.global_transform 
		
		# ROTATIONAL DRIVE (torque)
		var q_current = current_transform.basis.get_rotation_quaternion()
		var q_target = target_transform.basis.get_rotation_quaternion()
		var q_difference = q_current.inverse() * q_target
		
		#Getting physics server ID for bone to apply forces
		var rid : RID = bone.get_rid()
		
				# POSITIONAL DRIVE
		var pos_difference = target_transform.origin - current_transform.origin
		var force = pos_difference * bone.get("mass") * force_strength * position_stiffness
		PhysicsServer3D.body_apply_central_force(rid, force)
		
		# Convert quaternion difference to axis-angle
		var axis = Vector3(q_difference.x, q_difference.y, q_difference.z)
		if axis.length() > 1:
			axis = axis.normalized()
			var angle = 2.0 * acos(q_difference.w)
			var torque = axis * angle * torque_strength * rotation_stiffness
			PhysicsServer3D.body_apply_torque_impulse(rid, torque)
