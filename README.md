# Babrak2 – HD-2D RPG (Godot 4.7)

Ovládání: WASD/šipky chůze, Shift běh, E/Enter/mezerník mluvit, I inventář, J úkoly, C družina/dovednosti/výbava/nastavení,
T položit past, Esc pauza + ukládání, F9 zkušební souboj.

Generování map: `godot --headless --path . -s res://tools/build_sample.gd`, potom `-s res://tools/build_maps.gd`.
Export: Projekt → Export (předvolby Windows a Linux jsou připravené). Doporučený renderer: Forward+ (hloubka ostrosti, AO, objemová mlha).

Systémy: fx/atmo.gd (denní doba, počasí, paprsky), battle/rules.gd (prvky, statusy, zbraně, dovednosti, limity, prostředí),
battle/map_enemy.gd (nepřátelé na mapě, způsoby vstupu do boje), loot/party.gd (parťáci), ui/party_menu.gd, loot/settings.gd.
