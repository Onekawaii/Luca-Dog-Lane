extends RigidBody3D
# One-shot destructive game prop. Game owns authoritative voxel edits and physics.
const EXPLOSION_RADIUS := 4.5
const EXPLOSION_DAMAGE := 44.0
var game: Node
var integrity := 20.0
var detonated := false

func _ready() -> void:
    add_to_group("explosive_barrel")
    add_to_group("sandbox_prop")
    contact_monitor = true
    max_contacts_reported = 4

func take_damage(amount: float, _impulse := Vector3.ZERO, _source := Vector3.ZERO) -> String:
    if detonated:
        return "Barrel already detonated"
    integrity -= maxf(0.0, amount)
    if integrity <= 0.0:
        detonate()
        return "BARREL DETONATED"
    return "BARREL DAMAGED // %.0f" % integrity

func detonate() -> void:
    if detonated:
        return
    detonated = true
    var blast_at := global_position
    if game != null and is_instance_valid(game):
        game.call("trigger_build_explosion", blast_at, EXPLOSION_RADIUS, EXPLOSION_DAMAGE, self)
    hide()
    collision_layer = 0
    collision_mask = 0
    queue_free()
