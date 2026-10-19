# Battle test scenes

Run the sequence test without touching game state:

    godot --headless --path . res://tests/BattleTest.tscn

It starts a battle with two Dummy enemies and checks damage, miss, crit, state infliction, AOE damage and stagger, trap interruption, turn holds, automatic idle, and hit/miss branch modes.

Run the battle entry test with a real room, player, and `Battle.start`:

    godot --headless --path . res://tests/BattleEntryTest.tscn

Both scenes quit with a nonzero exit code when a check fails.
