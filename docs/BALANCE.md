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
| Supplies | feed 1, hay 3, fertilizer 5, medicine 20, wood 2, stone 2, iron ore 6 |
| Workbench goods (market) | nails 1, rope 4, worms 1, dough 1 |
| Tools | hoe, scythe, pickaxe, axe, brush 40; watering can, pitchfork 50; milk pail 75; shears 90; repair 0.25 a point of wear; upgrades 60 / 180 (and ore) |
| Animals (grown / young) | hen 50 / 20, sheep 225 / 90, cow 375 / 150, horse 600 / 225 |
| Buildings | coop kit 25, workbench kit 40 (market: 55 bundled), open barn 200, field expansion I 250, II 900, III 2,400, bigger warehouse 900, closed barn 1,350, house extension I 1,500, II 4,500 |
| Other | the dealership's pickup 550; the vet 10 plus 30% of the animal's value |

Orders pay 1.6× the market (in steps of $5, at least $5). Sales give a point of farm
experience per $6, orders 20 plus a point per $7 (Progress).

## What the farm level opens (UnlockTable)

| Level | Day (sim) | Opens |
|---|---|---|
| 1 | 1 | wheat, carrot, potato; chickens (the coop kit); the workbench kit: knife, fishing rod, bow, campfire, bait (dough), feed, axe, pickaxe, hoe, scythe, watering can; millstone |
| 2 | ~3 | strawberry, tomato; field expansion I; fertilizer; pitchfork |
| 3 | ~7 | corn; open barn, sheep; bigger warehouse; sprinkler, pickle barrel, spinning wheel, shears; tool upgrade +1 |
| 4 | ~12 | eggplant, pumpkin; cows; field expansion II; cheese press, milk pail |
| 5 | ~20 | house extension I; jam kettle |
| 6 | ~29 | horse; closed barn; tool upgrade +2 |
| 7 | ~41 | field expansion III |
| 8 | ~48 | house extension II |
| 9 | ~57 | a fourth order on the board |
| 10 | ~66 | orders pay 25% more |

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
