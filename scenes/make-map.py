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

TILE_IDS = [TILE_OCEAN, TILE_WATER,TILE_SHALLOW, TILE_SWAMP,
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

    lines =[]
    for y in range(MAP_HEIGHT):
        for x in range(MAP_WIDTH):
            h = hmap[y][x]
            s = influence(x, y, swamp_cs)
            f = influence(x, y, forest_cs)
            tid = choose_tile(h, s, f)
            lines.append(f'world.set_cell(Vector21({x-MAP_WIDTH/2},{y-MAP_HEIGHT/2}),{tid},Vector21(0,0),0)') 
            # Pack cell: x,y,source_index,atlas_x,atlas_y,alternative
            
    return lines

def write_scene():
    lines = generate_data()
    
    scene = f"""[gd_scene load_steps=4 format=4]
[ext_resource type="TileSet" uid="uid://br0h1p1uc07xg" path="res://res/euphoric.tres" id="1_elqb8"]

[node name="Node2D" type="Node2D"]

[node name="world" type="TileMapLayer" parent="."]

tile_set = ExtResource("1_elqb8")
tile_size = Vector2i(32, 32)

{'\n'.join(lines)}
"""
    open("map.tscn","w").write(scene)
    print("map.tscn written.")

if __name__=="__main__":
    write_scene()

