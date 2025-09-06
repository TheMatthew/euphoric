import random, math, struct, base64,tqdm

MAP_WIDTH = 80
MAP_HEIGHT = 60
N_MOUNTAIN_CENTROIDS = 8
N_SWAMP_CENTROIDS = 3
N_FOREST_CENTROIDS = 5

# Tiles
TILE_OCEAN     = 0
TILE_WATER     = 1
TILE_SHALLOW   = 2
TILE_SWAMP     = 3
TILE_GRASS     = 4
TILE_SHRUB     = 5
TILE_FOREST    = 6
TILE_HILL      = 7
TILE_MOUNTAIN  = 8

TILE_IDS = [TILE_OCEAN, TILE_WATER, TILE_SWAMP,
            TILE_GRASS, TILE_SHRUB, TILE_FOREST,
            TILE_HILL, TILE_MOUNTAIN]

TILE_INDEX = {tid: tid for tid in TILE_IDS}

def noise_height(x, y, centroids):
    h = 0
    for cx, cy in centroids:
        d = math.sqrt((x - cx)**2 + (y - cy)**2) + 1
        h += 1.0 / d
    return h + random.uniform(-0.02, 0.02)

def place_centroids(num, hmap, min_h=0.05):
    pts = []
    while len(pts) < num:
        x = random.randrange(MAP_WIDTH)
        y = random.randrange(MAP_HEIGHT)
        if hmap[y][x] > min_h:
            pts.append((x, y))
    return pts

def influence(x, y, centroids, power=1.0):
    v = 0
    for cx, cy in centroids:
        d = math.sqrt((x - cx)**2 + (y - cy)**2) + 1
        v = max(v, power/d)
    return v

def choose_tile(h, swamp_inf, forest_inf):
    if h < 0.02: return TILE_OCEAN
    if h < 0.03: return TILE_WATER
    if swamp_inf > 0.2 and h < 0.06: return TILE_SWAMP
    if forest_inf > 0.15: return TILE_FOREST if random.random()<0.7 else TILE_SHRUB
    if h < 0.06: return TILE_GRASS
    if h < 0.1: return TILE_HILL
    return TILE_MOUNTAIN

def generate_data():
    # mountain height base
    mountain_cs = [(random.randrange(MAP_WIDTH), random.randrange(MAP_HEIGHT))
                   for _ in range(N_MOUNTAIN_CENTROIDS)]
    hmap = [[noise_height(x, y, mountain_cs) for x in range(MAP_WIDTH)]
            for y in range(MAP_HEIGHT)]

    swamp_cs = place_centroids(N_SWAMP_CENTROIDS, hmap)
    forest_cs = place_centroids(N_FOREST_CENTROIDS, hmap)

    buf = bytearray()
    for y in range(MAP_HEIGHT):
        for x in range(MAP_WIDTH):
            h = hmap[y][x]
            s = influence(x, y, swamp_cs)
            f = influence(x, y, forest_cs)
            tid = choose_tile(h, s, f)
            idx = TILE_INDEX[tid]

            # Pack cell: x,y,source_index,atlas_x,atlas_y,alternative
            buf.extend(struct.pack("<iiiiii", x, y, idx, 0, 0, 0))
    return buf

def write_scene():
    raw = generate_data()
    b64 = base64.b64encode(raw).decode("ascii")
    
    # Insert '\\\n' every 80 characters
    width = 80
    lines = [b64[i:i+width] for i in range(0, len(b64), width)]
    b64_with_escapes = '\\\n'.join(lines)
    scene = f"""[gd_scene load_steps=4 format=4]
[ext_resource type="TileSet" uid="uid://br0h1p1uc07xg" path="res://res/euphoric.tres" id="1_elqb8"]

[node name="Node2D" type="Node2D"]

[node name="TileMapLayer" type="TileMapLayer" parent="."]

tile_set = ExtResource("1_elqb8")
tile_size = Vector2i(32, 32)

tile_map_data = PackedByteArray("{b64_with_escapes}")
"""
    open("map.tscn","w").write(scene)
    print("map.tscn written.")

def write_minimal_test():
    """Generate the most minimal test possible - just one tile"""
    buf = bytearray()
    
    # Place just one grass tile at (0,0)
    buf.extend(struct.pack("<iiiiii", 0, 0, TILE_GRASS, 0, 0, 0))
    
    b64 = base64.b64encode(buf).decode("ascii")
    
    scene = f"""[gd_scene load_steps=2 format=3]

[ext_resource type="TileSet" uid="uid://br0h1p1uc07xg" path="res://res/euphoric.tres" id="1_elqb8"]

[node name="MinimalTest" type="Node2D"]

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(16, 16)
zoom = Vector2(4, 4)

[node name="TileMapLayer" type="TileMapLayer" parent="."]
tile_set = ExtResource("1_elqb8")
tile_map_data = PackedByteArray("{b64}")

[node name="Label" type="Label" parent="."]
offset_left = 50.0
offset_right = 250.0
offset_bottom = 50.0
text = "Minimal test: 1 tile with ID {TILE_GRASS}"
"""
    
    with open("minimal_test.tscn", "w") as f:
        f.write(scene)
    print(f"minimal_test.tscn written (single tile with ID {TILE_GRASS})")

def check_all_tiles():
    """Generate a test scene with all tile types"""
    buf = bytearray()
    
    # Place each tile type in a row
    for i, tile_id in enumerate(TILE_IDS):
        buf.extend(struct.pack("<iiiiii", i, 0, tile_id, 0, 0, 0))
    
    b64 = base64.b64encode(buf).decode("ascii")
    
    scene = f"""[gd_scene load_steps=2 format=3]

[ext_resource type="TileSet" uid="uid://br0h1p1uc07xg" path="res://res/euphoric.tres" id="1_elqb8"]

[node name="AllTilesTest" type="Node2D"]

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2({len(TILE_IDS) * 16}, 16)
zoom = Vector2(2, 2)

[node name="TileMapLayer" type="TileMapLayer" parent="."]
tile_set = ExtResource("1_elqb8")
tile_map_data = PackedByteArray("{b64}")

[node name="Label" type="Label" parent="."]
offset_right = 400.0
offset_bottom = 50.0
text = "All tiles test: {', '.join(map(str, TILE_IDS))}"
"""
    
    with open("all_tiles_test.tscn", "w") as f:
        f.write(scene)
    print(f"all_tiles_test.tscn written (all {len(TILE_IDS)} tile types)")

# Add these to your main execution for testing
if __name__ == "__main__":
    write_scene()
    write_minimal_test()
    check_all_tiles()
