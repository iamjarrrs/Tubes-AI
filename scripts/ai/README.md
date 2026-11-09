# Automated Planner Contract

`automated_planner.gd` is a synchronous, UI-independent forward A* planner. It loads the action schema from `res://data/domain_planning.json`.

Pass the current state as a `Dictionary` whose `predicates` value is an array of known predicate strings. `at_item` means the NPC has reached the selected potion/item's current map location; it does not imply a physical chest. An optional `context` dictionary can carry target data such as an item ID or map position for the controller. The planner does not use this context to search, but includes it when detecting state changes.

```gdscript
var initial_state := {
	"predicates": ["at_start", "item_available"],
	"context": {"item_id": "potion_01", "item_position": Vector2(420, 180)}
}
```

Pass the KB Engine goal as a `String`: one predicate (for example, `at_mc`) or a conjunction separated by `AND`, `&&`, or commas (for example, `item_used AND at_mc`). Predicate names are case-insensitive.

```gdscript
var planner = load("res://scripts/ai/automated_planner.gd").new()
var actions: Array[String] = planner.update_request(initial_state, "item_used AND at_mc")
```

`request_plan(state, goal)` always invalidates the stored plan and searches again. `update_request(latest_state, latest_goal)` compares the supplied state and goal with the last request; it invalidates and searches again when either changes, and otherwise returns a copy of the current plan. Anggota 3 should call `update_request` when map facts or the KB goal change, including when the selected item's position changes in `context`. `invalidate_plan()` clears the stored result explicitly. Successful results are action names such as `["move_to_chest", "take_item", "use_item", "move_to_mc"]`; an already-satisfied goal also returns an empty array.

Check `last_status` to distinguish an empty successful plan (`success`) from failure: `unknown_goal` for malformed or unrecognized goals, `unreachable` for valid goals with no applicable path, `invalid_initial_state` for malformed/unknown state predicates, and `domain_error` if the JSON schema cannot be loaded. Failure results are always an empty `Array[String]`; `last_error` gives a short explanation. `plan_revision` increases whenever a plan is invalidated/requested.

All action costs are 1. A* uses the number of unsatisfied goal predicates as its heuristic; each action in this domain adds at most one predicate, making that count a lower bound. The domain models one selected quest item/potion, represented by `item_available`, `has_item`, and `item_used`; the map controller resolves the `move_to_chest` action to that item's current world position.