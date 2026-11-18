Les icônes d'ETEA, en quatre packs au choix dans Réglages › Barre › Icônes :

- `phosphor-fill/` : [Phosphor](https://phosphoricons.com) rempli, le pack par défaut. Les traits simples (plus, croix, coche, liste) y sont en graisse Bold, que le remplissage enferme sinon dans un carré. Licence MIT, voir `phosphor/LICENSE.txt`.
- `phosphor/` : Phosphor en trait, graisse Regular. Licence MIT.
- ce dossier même : [Material Symbols](https://fonts.google.com/icons), style Rounded rempli. Licence Apache 2.0, voir `LICENSE.txt`.
- `material-light/` : Material Symbols Rounded en trait, graisse 300. Licence Apache 2.0.

Toutes sont recolorées en blanc pour être teintées par le shell, et portent les mêmes noms d'un pack à l'autre. Une icône qui manque à un pack est prise dans celui-ci.

`packs.tsv` donne pour chaque icône son nom chez Material et chez Phosphor. Pour en ajouter une : l'icône remplie dans ce dossier, une ligne dans la table, puis `scripts/icon-packs.py` refait les autres packs.
