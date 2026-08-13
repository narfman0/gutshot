## Physics layer registry — the single source of truth for collision layers.
## docs/architecture.md: layer 2 is cover/walls and is what LOS raycasts test.
class_name Layers

const GROUND := 1 << 0    # walkable floor, receives movement clicks
const COVER := 1 << 1     # cover props + walls — blocks LOS and shots
const SQUAD := 1 << 2     # player-team character bodies
const ENEMIES := 1 << 3   # enemy-team character bodies
const BARRIERS := 1 << 4  # invisible boundary walls (never clickable)

## Mouse picking: ground for movement, enemies for sticky aim.
const CLICK_MASK := GROUND | ENEMIES
## Line-of-sight / cover exposure raycasts test only cover geometry.
const LOS_MASK := COVER

static func body_layer(team: int) -> int:
	return SQUAD if team == 0 else ENEMIES

static func enemy_mask_for(team: int) -> int:
	return ENEMIES if team == 0 else SQUAD
