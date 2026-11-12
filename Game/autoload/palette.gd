extends Node


const NAVY = Color("#1F2340")
const NAVY_LIGHT = Color("#3B4070")
const NAVY_MID = Color("#2E3463")
const YELLOW = Color("#FACC15")
const WHITE = Color("#FFFFFF")
const TEXT_DIM = Color("#B8BEDD")
const CARD = Color("#F8F4E3")
const GRASS = Color("#9AD16F")
const GRID_LINE = Color("#8CC463")
const TREE = Color("#3F9B3A")
const TREE_DARK = Color("#2F7A2C")
const ROCK = Color("#8A8FA3")
const ROCK_DARK = Color("#6B7086")
const WATER = Color("#5BB8F0")
const WAVE = Color("#A5DDFF")
const ASPHALT = Color("#4A4E69")
const LANE_DASH = Color("#F8F4E3")
const BRIDGE_DECK = Color("#C89B5E")
const BRIDGE_RAIL = Color("#7A4B22")
const BLUE = Color("#3B82F6")
const BLUE_DARK = Color("#1D4ED8")
const RED = Color("#EF4444")
const RED_DARK = Color("#B91C1C")
const URGENT = Color("#FACC15")
const URGENT_DARK = Color("#CA8A04")
const URGENT_RING = Color("#F59E0B")
const SORTER = Color("#A855F7")
const SORTER_DARK = Color("#7E22CE")
const OK = Color("#22C55E")
const BUSY = Color("#FACC15")
const JAM = Color("#EF4444")
const HEATMAP_BTN = Color("#F97316")
const LIGHT_BOX = Color("#111426")
const LIGHT_OFF = Color("#3A3F5C")
const STAR_OFF = Color("#C9CCDA")


func cargo(d: int) -> Color:
	if d == 0:
		return BLUE
	if d == 1:
		return RED
	return URGENT


func cargo_dark(d: int) -> Color:
	if d == 0:
		return BLUE_DARK
	if d == 1:
		return RED_DARK
	return URGENT_DARK


func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
