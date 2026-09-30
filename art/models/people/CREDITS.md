# Townspeople credits

The townspeople are built by `tools/fetch_people.py` (downloads) and
`tools/blender/build_people.py` (Blender 4.4, headless) from:

* **MPFB2 2.0.17** (MakeHuman for Blender), https://extensions.blender.org/add-ons/mpfb/ —
  the add-on's code is GPL-3.0 and is only used as a tool; the base mesh, targets and
  rigs it ships and everything it makes from them are CC0.
* **MakeHuman asset packs** (CC0 1.0, public domain), https://static.makehumancommunity.org/assets/assetpacks.html,
  downloaded without an account from files.makehumancommunity.org:

| Pack | Assets used | Author |
| --- | --- | --- |
| makehuman_system_assets | male_casualsuit01/03/05, male_elegantsuit01, male_worksuit01, shoes03/04/05, fedora01, hair short01/02/04, eyebrow001-004/006, eyelashes01, low-poly eyes (brown, brownlight), skins middleage_caucasian_male/female, old_caucasian_male, young_caucasian_male/male2 | MakeHuman team (Data Collection AB) |
| skins02 | middleage and old "slavic male" skins | jartur69 |
| hats01 | newsboy cap | jujube |
| bodyparts05 | viking moustache | RehmanPolanski |
| shirts01 | fisherman sweater | Margaret Toigo |
| pants01 | harem pants (şalvar) | Margaret Toigo |
| shoes01 | flats | Margaret Toigo |

Modelled in the build script (CC0, part of this game): the headscarf (yemeni) with its
printed pattern, the shop apron (bib, neck strap, waist ties and bow, shrink-wrapped over
the shirt) with its generated navy twill. Changes to the assets: bodies generated from macro
phenotypes, hidden body faces removed, heavy parts decimated, textures downsized and
re-encoded, the iris colour darkened; everything joined into one skinned mesh per person
on MPFB2's "game_engine" skeleton. Animated procedurally in game (scripts/npc).
