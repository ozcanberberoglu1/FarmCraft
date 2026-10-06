# Balance

`tools/balance_sim.gd` plays a sensible player against the real tables (items, crops,
animals, recipes, projects, farm levels and what they unlock, orders) and prints the
money and level curve, milestones and what each machine earns. A year is 40 days
(10 per season):

    godot --headless --path . -s res://tools/balance_sim.gd -- --days=120 --seed=7

## Money

Money is in dollars and comes **only from selling**: the town market, the shipping
bin (the courier keeps a quarter), a pickup's whole load at the market counter, animals
sold, and the orders on the town board. Story goals and achievements give farm
experience, never money.

A new farm starts with **$150** (Economy.STARTING_MONEY). The first day's story
spends it: two hens at the poultry stall ($50 each) leave $50, the coop kit takes $25
of that (and 15 wood). Grandpa's ripe carrots and the first eggs go through the
shipping bin, so the next morning there is about $45. The second day's story first
has the player **earn $20** by selling (the ripe wheat, the eggs: the bin pays in the
morning, the town market at once), then buy the **workbench kit** at the construction
board ($40 and 10 wood; put up near the house in a minute, like the coop kit), which
leaves about $25 for the fishing rod's **rope** (2 × $4) and **bait** ($1 a worm or a
dough ball; dough is also kneaded at the bench from 2 wheat). The market sells the
workbench ready bundled for $55 (no wood). Grandpa's pickup comes with the farm with
20 L in the tank; fuel is $0.50 a litre.

| | Prices ($) |
|---|---|
| Seeds | wheat 1, carrot 2, potato 2, corn 4, tomato 5, eggplant 6, strawberry 10, pumpkin 12 |
| Crops (sell) | wheat 2, potato 3, tomato 3, carrot 4, corn 4, eggplant 5, strawberry 5, pumpkin 45 |
| Animal goods | egg 5, milk 13, wool 30 |
| Artisan goods | flour 17, tomato paste 32, jam 35, pickles 36, yarn 45, cheese 50 |
| Supplies | feed 1, hay 3, big feed sack 36 and big hay bale 43 (each fills a feeder: 40 feed, 16 hay, less a tenth), fertilizer 5, medicine 20, wood 2, stone 2, iron ore 6 |
| Workbench goods (market) | nails 1, rope 4 |
| Bait (market; each draws its own fish, data/fish_table.gd) | worms 1, dough 1, maggots 2, sweetcorn 2, cheese 3, live minnows 4, spinner 15 (a lure: kept on a cast, lost on a snag or to a fish that gets away) |
| Rods (workbench; durability = casts) | cane pole 2 wood + 1 rope (50), rod 3 wood + 2 rope (150), carbon rod 4 wood, 3 rope, 6 nails, 3 ore (320, level 2), carp rod 6 wood, 4 rope, 10 nails, 6 ore (500, level 3) |
| Grills (market; Grill) | mangal 60 (6 places on the grate), big grill 140 (12 places); both burn 5 hours on the charcoal they come with, wood adds an hour like the campfire's. Against the campfire (8 stone + 6 wood, about $28 of materials, 3 places) the mangal is a comfort buy after the first sales; the big grill for a farm that fishes a lot |
| Fish (sell; trophy 10x) | bleak, gudgeon 2; rudd, crucian, roach 3; perch 4; bream 6; crayfish 6; chub 7; carp 9; tench 10; barbel, silver carp 12; grass carp 15; rainbow trout 16; eel 16; brown trout 20; zander 22; pike 30; wels catfish 55; sturgeon 95 |
| Tools | hoe, scythe, pickaxe, axe, brush 40; watering can, pitchfork 50; milk pail 75; shears 90; repair 0.25 a point of wear; upgrades 60 / 180 (and ore) |
| Animals (grown / young) | hen 50 / 20, sheep 225 / 90, cow 375 / 150, horse 600 / 225 |
| Males (grown; Breeding.MALE_PRICE) | ram 250, bull 420, stallion 650: a little over the female (25 to 50 more), bought once for the herd. A ram still gives wool, a bull no milk, a stallion is ridden like a mare |
| Young born on the farm (Breeding) | a female kept healthy (60+), fed (35+ at dawn) and content (55+) in the same barn as a grown male conceives each dawn with a chance of 0.6 (sheep), 0.5 (cow), 0.45 (horse); she carries 3 / 4 / 5 mornings and rests 3 / 4 / 5 days after the birth, so a pair gives a young one about every 8 / 10 / 12 days. One young at a time, 40% of them male; a place free in the barn is needed (she waits otherwise). It grows up in its kind's grow_days (5 / 6 / 6 fed days) and sells like a bought animal: a lamb about 75, grown about 180; a calf about 125, grown 300; a foal about 200, grown 475 (AnimalData.sale_value: condition and hearts move it). A ram pays for himself with the second lamb sold grown; the barn's places (4, closed barn 8) and the hay (1 a day a sheep, 2 a cow or a horse) are what holds a herd back |
| Buildings | coop kit 25, workbench kit 40 (market: 55 bundled), coop expansion I 100 (+20 wood, 10 nails), II 200 (+35 wood, 20 nails, 10 stone), open barn 200, field expansion I 250, II 900, III 2,400, bigger warehouse 900, closed barn 1,350, house extension I 1,500, II 4,500 |
| Other | the dealership's pickup 550; the vet 10 plus 30% of the animal's value |

Orders pay 1.6× the market (in steps of $5, at least $5). Sales give a point of farm
experience per $6, orders 20 plus a point per $7 (Progress).

## What the farm level opens (UnlockTable)

| Level | Day (sim) | Opens |
|---|---|---|
| 1 | 1 | wheat, carrot, potato; chickens (the coop kit); the workbench kit: knife, fishing rod, bow and arrows, campfire, bait (dough), feed, axe, pickaxe, hoe, scythe, watering can; millstone |
| 2 | ~3 | strawberry, tomato; field expansion I; fertilizer; pitchfork |
| 3 | ~7 | corn; open barn, sheep; bigger warehouse; coop expansion I; sprinkler, pickle barrel, spinning wheel, shears; tool upgrade +1 |
| 4 | ~12 | eggplant, pumpkin; cows; field expansion II; cheese press, milk pail |
| 5 | ~20 | house extension I; coop expansion II; jam kettle |
| 6 | ~29 | horse; closed barn; tool upgrade +2 |
| 7 | ~41 | field expansion III |
| 8 | ~48 | house extension II |
| 9 | ~57 | a fourth order on the board |
| 10 | ~66 | orders pay 25% more |

A coop put up from a kit holds 8 birds. The construction board's **coop expansion**
makes one coop longer at its east end, twice: 8 → 14 → 20 birds, 3 → 5 → 7 nest boxes,
a longer feeder and waterer (16 → 28 → 40 rations) and a second roost; a minute of play
(or a night's sleep) while the hens live on in it. Step I ($100, 20 wood, 10 nails) opens
at level 3, about when the first coop is full; step II ($200, 35 wood, 20 nails, 10
stone) at level 5, with some 16 hens on the farm. A place in it costs more than one in a
second kit ($25 and 15 wood for 8: the first day's price): what it buys is one door to
shut against the wolves, one feeder and waterer to fill and one yard (the 11 × 10 m plot
stays as it is), not cheaper room. Filling step I's six places with hens costs $300 more;
at about $5.50 a hen a day in eggs (less her feed) hens and step pay for themselves in two
weeks. (The balance sim still adds second kits.)

Each crop opens in time for its season in the first year (strawberries late in
spring, corn with summer, pumpkins before autumn). The story's chapters follow the same
ladder: the barn at 3, the dairy at 4, the house at 5.

## Three years (seed 7)

| Day | Money | Level | Farm |
|---|---|---|---|
| 1 | 50 | 1 | 2 hens and the coop kit ($25 left), Grandpa's carrots in the bin |
| 2 | 69 | 1 | workbench kit, rope and bait (the day's sales pay for them) |
| 5 | 62 | 2 | a third hen, fertilizer |
| 10 | 212 | 3 | 8 hens, a second coop kit |
| 20 | 224 | 5 | 16 hens, open barn, a cow, cheese press |
| 30 | 571 | 6 | a second field, sheep, spinning wheel, jam kettle |
| 40 | 354 | 6 | three fields (36 beds), the dealership's pickup |
| 60 | 2,198 | 9 | bigger warehouse, closed barn, house extension I |
| 80 | 1,861 | 10 | four fields (48 beds), house extension II |

Income over three years: crops 9.3k, animal products 9.3k, artisan goods 18.2k,
orders 2.3k.

The first days are tight on purpose: after the first day's hens and coop the farm runs
on a few dollars a day from crops and eggs and adds a hen or two at a time; the barn
and the dairy come in the first summer, the big buildings in the second year.

## Machines (value added per batch at base prices)

| Machine | In → out | Added | Time |
|---|---|---|---|
| Cheese press | 2 milk → cheese | +24 (+92%) | 12 h |
| Spinning wheel | 1 wool → yarn | +15 (+50%) | 8 h |
| Pickle barrel | 5 carrots / 4 eggplants → pickles | +16 (+80%) | 36 h |
| Jam kettle | 4 strawberries → jam, 6 tomatoes → paste | +15 / +14 | 6 / 8 h |
| Millstone | 5 wheat → flour | +7 (+70%) | 3 h |

Fertilizer: +30% growth speed and 15% gold quality.

## The workbench (RecipeTable)

Made from the bag's materials; wood and stone are gathered, iron ore comes from the
quarry or the market ($6), nails and rope from the town market. Making a farm tool at
the bench costs about half its shop price in bought materials (an axe: 3 wood and 3 ore,
$18 of ore against $40), so a worn-out tool is replaced cheaply once there is a bench.

| Recipe | Materials | Makes |
|---|---|---|
| Knife | 2 wood, 3 stone | 1 |
| Fishing rod | 3 wood, 2 rope | 1 |
| Bow | 4 wood, 4 nails, 2 rope | 1 |
| Arrows | 2 wood, 1 stone | 5 (a shot takes one; picked up again where it landed, some break in a body) |
| Campfire | 8 stone, 6 wood | 1 (burns 5 hours) |
| Dough (bait) | 2 wheat ($4) | 4 |
| Chicken feed | 2 wheat ($4) | 5 ($5 at the market) |
| Axe, hoe | 3 wood, 3 iron ore | 1 |
| Pickaxe | 3 wood, 4 iron ore | 1 |
| Scythe | 4 wood, 4 iron ore | 1 |
| Watering can | 5 iron ore, 2 nails | 1 |
| Pitchfork (level 2) | 4 wood, 3 iron ore, 2 nails | 1 |
| Shears (level 3) | 4 iron ore, 1 wood | 1 |
| Milk pail (level 4) | 6 wood, 4 nails | 1 |
| Fence panel | 3 wood, 2 nails | 2 (2 m each) |
| Fence gate | 4 wood, 6 nails | 1 |
| Lantern post | 3 wood, 1 iron ore, 1 rope | 1 |

## Giant fish on the grill

A giant (trophy) fish doesn't fit over the campfire; on a grill it takes two places side
by side and cooks in the usual 10 seconds into "<id>_trophy_cooked": it fills three times
what the whole grilled fish does (at least 60, at most 100 of 100 hunger) and sells for
1.3x the raw giant (a carp: raw $90, grilled $117, 96 hunger).


## Pastures (Pastures, FencePiece, LanternPost)

The farmer fences his own grazing: a closed loop of panels with at least one gate is a
pasture ("mera"). A first one of 8 panels and a gate (the side goal's) costs 12 wood, 8
nails for the panels and 4 wood, 6 nails for the gate: 16 wood and $14 of nails for about
16 m²; the barn pen's own fence can be one side of the loop, which saves panels. A
pasture of 48 m² (8 x 6 m) takes 13 panels and a gate: 24 wood, $20 of nails.

A sheep, cow or horse let go of the halter inside a pasture stays there and grazes; one
in a pasture that takes in the ground in front of the barn pen's gateway walks out by
itself after 06:30 and home at 18:30 (or when it rains). Grazing there by day (06:00 to
20:00, not in winter or under snow):

| | In the pen | At pasture |
|---|---|---|
| Contentment an hour (fed, watered, dry) | +2 | +4 (PASTURE_HAPPY 2 on top) |
| Water | its trough | the grass and its dew: +6 an hour up to 75 of 100, no trough needed by day |
| Feed | grazes (+9 an hour for a sheep) and eats from its trough under 75 | grazes the same and eats nothing from the trough |
| After 3 hours of it that day | | "well grazed": hunger 50% slower until the next morning (PASTURE_SAVING) |

So a sheep that spent the day at pasture and is led home at dusk loses about 21 fullness
over a ten-hour night instead of 42: starting the night full (110) it wakes at 89 and
takes nothing from the trough, where a sheep kept in the pen is down at 75 before
morning and eats a ration of hay. A cow (2 rations a day) saves the same share. A day at
pasture is also worth +28 contentment over fourteen hours, which is what the second egg,
breeding (60) and the quality of milk and wool look at.

Left at pasture overnight the animals are out in the night: rain and the cold hurt them
as any animal left outside, and the wolves can get to them (a fence stops no wolf: it
leaps anything up to 1.3 m; the panels are 1.2 m). A lit lantern post (lit 18:30 to
06:15) keeps wolves 8 m off, as a burning campfire does 6 m. A night slept through counts
the animals of a pasture whose whole ground is within 8 m of a lantern post as protected
and the others as out in the open; one lantern in the middle covers a pasture up to about
11 x 11 m, a 48 m² one easily. The dusk note (18:00) says how many animals are still out
and whether the lanterns cover them. They are still there the next morning; winter and
snow bring them home with the morning (nothing to graze).
