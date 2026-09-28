# Balance

`tools/balance_sim.gd` plays a sensible player against the real tables (items, crops,
animals, recipes, projects, farm levels and what they unlock, orders) and prints the
money and level curve, milestones and what each machine earns. A year is 40 days
(10 per season):

    godot --headless --path . -s res://tools/balance_sim.gd -- --days=120 --seed=7

## What the farm level opens (UnlockTable)

| Level | Day (sim) | Opens |
|---|---|---|
| 1 | 1 | wheat, carrot, potato; millstone |
| 2 | ~5 | strawberry, tomato; chicken run, chickens; field expansion I; fertilizer |
| 3 | ~9 | corn; open barn, sheep; bigger warehouse; sprinkler, pickle barrel, spinning wheel; tool upgrade +1 |
| 4 | ~18 | eggplant, pumpkin; cows; field expansion II; cheese press |
| 5 | ~30 | closed coop; house extension I; jam kettle |
| 6 | ~46 | horse; closed barn; tool upgrade +2 |
| 7 | ~54 | field expansion III |
| 8 | ~60 | house extension II |
| 9 | ~69 | a fourth order on the board |
| 10 | ~85 | orders pay 25% more |

Each crop opens in time for its season in the first year (strawberries late in
spring, corn with summer, pumpkins before autumn). The story's chapters follow the same
ladder: the coop at level 2, the barn at 3, the dairy at 4, the house at 5.

## Three years (seed 7)

| Day | Money | Level | Farm |
|---|---|---|---|
| 1 | 604 | 1 | pickup bought straight away (2,500 start), millstone |
| 10 | 282 | 3 | chicken run, 3 chickens, fertilizer |
| 20 | 813 | 4 | open barn |
| 30 | 519 | 5 | a cow and a sheep, cheese press, spinning wheel |
| 40 | 368 | 5 | 8 animals, jam kettle |
| 60 | 3,397 | 8 | second and third fields (36 beds), closed coop and barn |
| 80 | 7,534 | 9 | four fields (48 beds), 16 animals |

Income over three years: crops 28.7k, animal products 15.8k, artisan goods 61.0k,
orders 5.8k.

## Machines (value added per batch at base prices)

| Machine | In → out | Added | Time |
|---|---|---|---|
| Cheese press | 2 milk → cheese | +90 (+90%) | 12 h |
| Spinning wheel | 1 wool → yarn | +60 (+50%) | 8 h |
| Pickle barrel | 5 carrots / 4 eggplants → pickles | +55 (+85%) | 36 h |
| Jam kettle | 4 strawberries → jam, 6 tomatoes → paste | +53 / +55 | 6 / 8 h |
| Millstone | 5 wheat → flour | +25 (+71%) | 3 h |

Tuning done: the pickle barrel was 48 h / 110 gold (the weakest by far), now 36 h /
120. Orders pay 1.6× the market. Fertilizer: +30% growth speed and 15% gold quality.

Things to watch: buying the pickup on day one leaves little for seeds (the story leads
players to it after the first harvest); levels 6–10 come in the second and third year,
the long-term goal (the horse, the big buildings, better orders).
