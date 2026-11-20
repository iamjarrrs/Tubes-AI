extends Node

# =========================================================
# 1. DATABASE ITEM & ATRIBUT (KEY LENGKAP & KONSISTEN)
# =========================================================
const MAX_WEIGHT: int = 65

const WEAPONS = [
	{"name": "Dagger", "atk": 5, "power": 5, "def": 0, "defense": 0, "weight": 10, "element": "Neutral"},
	{"name": "Aqua Wand", "atk": 12, "power": 12, "def": 0, "defense": 0, "weight": 20, "element": "Water"},
	{"name": "Leaf Blade", "atk": 14, "power": 14, "def": 0, "defense": 0, "weight": 25, "element": "Nature"},
	{"name": "Flame Sword", "atk": 15, "power": 15, "def": 0, "defense": 0, "weight": 30, "element": "Fire"}
]

const ARMORS = [
	{"name": "Leather Vest", "atk": 0, "power": 0, "def": 5, "defense": 5, "weight": 15, "element": "Neutral"},
	{"name": "Forest Cloak", "atk": 0, "power": 0, "def": 8, "defense": 8, "weight": 20, "element": "Nature"},
	{"name": "Ocean Shield", "atk": 0, "power": 0, "def": 10, "defense": 10, "weight": 25, "element": "Water"},
	{"name": "Flame Mail", "atk": 0, "power": 0, "def": 12, "defense": 12, "weight": 35, "element": "Fire"}
]

const ACCESSORIES = [
	{"name": "None", "atk": 0, "power": 0, "def": 0, "defense": 0, "weight": 0, "hp": 0, "element": "Neutral"},
	{"name": "Apothecary Charm", "atk": 2, "power": 2, "def": 3, "defense": 3, "weight": 15, "hp": 0, "element": "Neutral"},
	{"name": "Elemental Gem", "atk": 5, "power": 5, "def": 5, "defense": 5, "weight": 20, "hp": 0, "element": "Neutral"},
	{"name": "Guardian Pendant", "atk": 0, "power": 0, "def": 0, "defense": 0, "weight": 20, "hp": 0, "damage_reduction": 10, "element": "Neutral"},
	{"name": "Berserker Amulet", "atk": 10, "power": 10, "def": -5, "defense": -5, "weight": 25, "hp": 0, "element": "Neutral"}
]

# =========================================================
# 2. CSP SOLVER (FILTER KOMBINASI VALID)
# =========================================================
func get_valid_combinations(npc_elem: String = "") -> Array:
	var valid_list = []
	for w in WEAPONS:
		if not _item_matches_element(w, npc_elem):
			continue
		for a in ARMORS:
			if not _item_matches_element(a, npc_elem):
				continue
			for acc in ACCESSORIES:
				if not _item_matches_element(acc, npc_elem):
					continue
				var total_weight = w["weight"] + a["weight"] + acc["weight"]
				if total_weight <= MAX_WEIGHT:
					valid_list.append({
						"weapon": w,
						"armor": a,
						"accessory": acc,
						"total_weight": total_weight
					})
	return valid_list

func _item_matches_element(item: Dictionary, element: String) -> bool:
	return element.is_empty() or item["element"] == "Neutral" or item["element"] == element

# =========================================================
# 3. KALKULASI POWER & FITNESS (DDA)
# =========================================================
func calculate_power(w: Dictionary, a: Dictionary, acc: Dictionary, npc_elem: String, mc_elem: String) -> float:
	var base_atk = w["atk"] + acc["atk"]
	var base_def = a["def"] + acc["def"]
	
	var mult = 1.0
	if (npc_elem == "Fire" and mc_elem == "Nature") or \
	   (npc_elem == "Nature" and mc_elem == "Water") or \
	   (npc_elem == "Water" and mc_elem == "Fire"):
		mult = 1.3
	elif (npc_elem == "Nature" and mc_elem == "Fire") or \
		 (npc_elem == "Water" and mc_elem == "Nature") or \
		 (npc_elem == "Fire" and mc_elem == "Water"):
		mult = 0.85
		
	return (base_atk * mult) + base_def + float(acc.get("hp", 0)) * 0.5 + float(acc.get("damage_reduction", 0)) * 0.5

func evaluate_fitness(combination: Dictionary, npc_elem: String, mc_power: float, mc_elem: String) -> float:
	var npc_power = calculate_power(combination["weapon"], combination["armor"], combination["accessory"], npc_elem, mc_elem)
	return -abs(npc_power - mc_power)

# =========================================================
# 4. LOCAL SEARCH (SIMULATED ANNEALING)
# =========================================================
func run_simulated_annealing(mc_power: float, mc_elem: String, npc_elem: String) -> Dictionary:
	var valid_space = get_valid_combinations(npc_elem)
	if valid_space.is_empty():
		return {}
		
	var current_state = valid_space[randi() % valid_space.size()]
	var current_fitness = evaluate_fitness(current_state, npc_elem, mc_power, mc_elem)
	
	var best_state = current_state
	var best_fitness = current_fitness
	
	var temp: float = 100.0
	var cooling_rate: float = 0.95
	var min_temp: float = 0.1
	
	while temp > min_temp:
		var neighbor_state = valid_space[randi() % valid_space.size()]
		var neighbor_fitness = evaluate_fitness(neighbor_state, npc_elem, mc_power, mc_elem)
		var delta = neighbor_fitness - current_fitness
		
		if delta > 0 or exp(delta / temp) > randf():
			current_state = neighbor_state
			current_fitness = neighbor_fitness
			if current_fitness > best_fitness:
				best_state = current_state
				best_fitness = current_fitness
				
		temp *= cooling_rate
		
	return best_state
