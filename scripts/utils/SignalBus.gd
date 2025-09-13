extends Node

@warning_ignore("unused_signal")
signal control_glitched(control)
@warning_ignore("unused_signal")
signal control_back_to_normal(control)

@warning_ignore("unused_signal")
signal bullet_number_changed(left_bullets)
@warning_ignore("unused_signal")
signal special_state_changed(special_state)
@warning_ignore("unused_signal")
signal health_changed(health, max_health)

@warning_ignore("unused_signal")
signal bullet_hit(target, shooter, bullet)
