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

@warning_ignore("unused_signal")
signal level_ready


@warning_ignore("unused_signal")
signal player_area_entered(event_type)
@warning_ignore("unused_signal")
signal player_area_exited(event_type)

@warning_ignore("unused_signal")
signal game_ended(motive, action, action_name)

@warning_ignore("unused_signal")
signal level_restarted()

@warning_ignore("unused_signal")
signal enemy_died(enemy)

@warning_ignore("unused_signal")
signal start_level_1()

@warning_ignore("unused_signal")
signal next_level
