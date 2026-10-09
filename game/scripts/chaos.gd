class_name Chaos
extends RefCounted
## Kaotik fizik etkileşimleri: hapşırınca önündekileri savurma, yürürken
## eşyaları itme. Oyuncu ve NPC'ler ortak kullanır.

const SNEEZE_RANGE := 3.5
const SNEEZE_SPEED := 7.0
const KNOCKBACK_SPEED := 8.0


## Hapşırığın önündeki eşyaları ve karakterleri savurur. Etkilenen sayısını döner.
static func sneeze_push(source: CollisionObject3D, origin: Vector3, forward: Vector3) -> int:
	var shape := SphereShape3D.new()
	shape.radius = SNEEZE_RANGE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), origin + forward * SNEEZE_RANGE * 0.6)
	query.exclude = [source.get_rid()]
	var hits := source.get_world_3d().direct_space_state.intersect_shape(query, 48)
	var count := 0
	for hit in hits:
		var body: Node3D = hit["collider"]
		var to := body.global_position - origin
		to.y = 0.0
		if to.dot(forward) < 0.0 or to.length() > SNEEZE_RANGE * 1.4:
			continue
		var dir := (to.normalized() + Vector3.UP * 0.5).normalized()
		var falloff := clampf(1.0 - to.length() / (SNEEZE_RANGE * 1.6), 0.25, 1.0)
		if body is RigidBody3D:
			var rb := body as RigidBody3D
			rb.apply_central_impulse(dir * SNEEZE_SPEED * falloff * rb.mass)
			rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * rb.mass)
			count += 1
		elif body.has_method("knockback"):
			body.knockback(dir * KNOCKBACK_SPEED * falloff)
			count += 1
	return count


## Karakter yürürken çarptığı serbest eşyaları iter.
static func push_from_slides(body: CharacterBody3D, strength: float) -> void:
	for i in body.get_slide_collision_count():
		var col := body.get_slide_collision(i)
		var other := col.get_collider()
		if other is RigidBody3D:
			var dir := -col.get_normal()
			dir.y = 0.0
			if dir.length_squared() > 0.0001:
				(other as RigidBody3D).apply_central_impulse(dir.normalized() * strength)
