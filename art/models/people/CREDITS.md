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
| makehuman_system_assets | male_casualsuit01/03/05, male_elegantsuit01, male_worksuit01, female_casualsuit01 (Zeynep's jeans), shoes03/04/05, fedora01, hair short01/02/04 and ponytail01, eyebrow001-006, eyelashes01/02, low-poly eyes (brown, brownlight), skins middleage_caucasian_male/female, old_caucasian_male, young_caucasian_male/male2 | MakeHuman team (Data Collection AB) |
| skins01 | light skin with natural make-up (Zeynep) | Margaret Toigo |
| skins02 | middleage and old "slavic male" skins | jartur69 |
| hats01 | newsboy cap | jujube |
| bodyparts05 | viking moustache | RehmanPolanski |
| shirts01 | fisherman sweater (red; ecru for Zeynep) | Margaret Toigo |
| pants01 | harem pants (şalvar) | Margaret Toigo |
| shoes01 | flats, ankle boots (female) | Margaret Toigo |

Modelled in the build script (CC0, part of this game): the headscarf (yemeni) with its
printed pattern, the shop apron (bib, neck strap, waist ties and bow, shrink-wrapped over
the shirt) with its generated navy twill. Changes to the assets: bodies generated from macro
phenotypes (Zeynep's face also shaped with MakeHuman's face targets), hidden body faces
removed (and the T-shirt under Zeynep's jumper), heavy parts decimated, textures downsized
and re-encoded, the iris colour darkened, some textures recoloured (Zeynep's jumper ecru,
her boots tan, her hair dark brown, the skin's painted lips a muted rose); everything
joined into one skinned mesh per person on MPFB2's "game_engine" skeleton. Animated
procedurally in game (scripts/npc).
