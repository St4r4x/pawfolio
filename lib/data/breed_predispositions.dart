typedef BreedPredisposition = ({String condition, String note});

const _vetFollowUpNote = 'Race avec une prédisposition connue, un suivi vétérinaire régulier est recommandé.';
const _hipDysplasiaNote = 'Fréquente chez les grandes races à croissance rapide.';
const _brachycephalicNote = 'Difficultés respiratoires liées au museau court, surtout par forte chaleur ou à l\'effort.';
const _skinFoldsNote = 'Les plis cutanés demandent un nettoyage régulier pour éviter les irritations.';
const _floppyEarsNote = 'Les oreilles tombantes retiennent l\'humidité, un nettoyage régulier limite les infections.';
const _longBackNote = 'Le dos allongé rend cette race plus sensible aux problèmes de colonne vertébrale.';
const _patellarLuxationSmallNote = 'Fréquente chez les petites races.';
const _dentalSmallBreedNote = 'Les petites races sont plus sujettes au tartre et à la perte de dents.';
const _epilepsyNote = 'Race avec une prédisposition connue aux crises convulsives.';
const _prominentEyesNote = 'Les yeux proéminents sont plus exposés aux blessures et irritations.';

const breedPredispositions = <String, List<BreedPredisposition>>{
  'Berger Allemand': [
    (condition: 'Dysplasie de la hanche et du coude', note: _hipDysplasiaNote),
    (condition: 'Myélopathie dégénérative', note: 'Maladie neurologique progressive touchant l\'arrière-train, plus fréquente avec l\'âge.'),
  ],
  'Labrador': [
    (condition: 'Dysplasie de la hanche', note: _hipDysplasiaNote),
    (condition: 'Surpoids', note: 'Race sujette à la prise de poids, surveiller l\'alimentation et l\'exercice.'),
  ],
  'Golden Retriever': [
    (condition: 'Dysplasie de la hanche', note: _hipDysplasiaNote),
    (condition: 'Certains cancers (lymphome, hémangiosarcome)', note: _vetFollowUpNote),
  ],
  'Bouledogue Français': [
    (condition: 'Syndrome brachycéphale', note: _brachycephalicNote),
  ],
  'Bouledogue Anglais': [
    (condition: 'Syndrome brachycéphale', note: _brachycephalicNote),
    (condition: 'Problèmes de peau', note: _skinFoldsNote),
  ],
  'Carlin': [
    (condition: 'Syndrome brachycéphale', note: _brachycephalicNote),
    (condition: 'Problèmes oculaires', note: _prominentEyesNote),
  ],
  'Shih Tzu': [
    (condition: 'Syndrome brachycéphale', note: _brachycephalicNote),
    (condition: 'Problèmes oculaires', note: _prominentEyesNote),
  ],
  'Boxer': [
    (condition: 'Cardiomyopathie', note: 'Race avec une prédisposition connue aux troubles du rythme cardiaque, un suivi vétérinaire régulier est recommandé.'),
  ],
  'Rottweiler': [
    (condition: 'Dysplasie de la hanche et du coude', note: _hipDysplasiaNote),
  ],
  'Teckel': [
    (condition: 'Hernie discale', note: _longBackNote),
  ],
  'Cocker Spaniel': [
    (condition: 'Otites', note: _floppyEarsNote),
  ],
  'Shar Pei': [
    (condition: 'Problèmes de peau', note: _skinFoldsNote),
    (condition: 'Fièvre périodique du Shar Pei', note: 'Épisodes de fièvre et d\'inflammation des articulations propres à la race.'),
  ],
  'Doberman': [
    (condition: 'Cardiomyopathie dilatée', note: _vetFollowUpNote),
  ],
  'Basset Hound': [
    (condition: 'Problèmes de dos', note: _longBackNote),
    (condition: 'Otites', note: _floppyEarsNote),
  ],
  'Border Collie': [
    (condition: 'Anomalie de l\'œil du Colley', note: 'Malformation oculaire congénitale, un dépistage précoce est possible.'),
    (condition: 'Épilepsie', note: _epilepsyNote),
  ],
  'Caniche': [
    (condition: 'Luxation de la rotule', note: 'Fréquente chez les petites et moyennes races.'),
    (condition: 'Épilepsie', note: _epilepsyNote),
  ],
  'Yorkshire Terrier': [
    (condition: 'Luxation de la rotule', note: _patellarLuxationSmallNote),
    (condition: 'Problèmes dentaires', note: _dentalSmallBreedNote),
  ],
  'Chihuahua': [
    (condition: 'Luxation de la rotule', note: _patellarLuxationSmallNote),
    (condition: 'Problèmes dentaires', note: _dentalSmallBreedNote),
  ],
  'Husky Sibérien': [
    (condition: 'Problèmes oculaires', note: 'Cataracte et atrophie rétinienne progressive sont plus fréquentes dans cette race.'),
  ],
  'Saint-Bernard': [
    (condition: 'Dysplasie de la hanche', note: _hipDysplasiaNote),
    (condition: 'Torsion d\'estomac', note: 'Les grandes races à poitrine profonde y sont plus sujettes, surtout après un repas copieux.'),
  ],
  'Dalmatien': [
    (condition: 'Calculs urinaires', note: 'Particularité métabolique de la race nécessitant une attention à l\'hydratation et à l\'alimentation.'),
    (condition: 'Surdité congénitale', note: 'Plus fréquente que dans la population canine générale, surtout chez les chiots à robe très blanche.'),
  ],
  'Persan': [
    (condition: 'Syndrome brachycéphale', note: 'Difficultés respiratoires liées au museau plat, surtout par forte chaleur ou à l\'effort.'),
    (condition: 'Polykystose rénale', note: 'Maladie héréditaire des reins, un dépistage est possible.'),
  ],
  'Maine Coon': [
    (condition: 'Cardiomyopathie hypertrophique', note: _vetFollowUpNote),
    (condition: 'Dysplasie de la hanche', note: 'Plus fréquente que chez les autres races de chat, du fait de sa grande taille.'),
  ],
  'British Shorthair': [
    (condition: 'Cardiomyopathie hypertrophique', note: _vetFollowUpNote),
  ],
  'Scottish Fold': [
    (condition: 'Maladie ostéo-articulaire', note: 'Liée à la mutation génétique responsable des oreilles pliées, peut toucher cartilages et articulations.'),
  ],
  'Sphynx': [
    (condition: 'Cardiomyopathie hypertrophique', note: _vetFollowUpNote),
    (condition: 'Sensibilité cutanée', note: 'L\'absence de pelage expose davantage au froid, au soleil, et aux irritations.'),
  ],
  'Siamois': [
    (condition: 'Problèmes respiratoires et dentaires', note: 'La conformation du museau et de la mâchoire peut prédisposer à ces troubles.'),
    (condition: 'Amylose', note: 'Maladie touchant certains organes (foie, reins), avec une prédisposition connue dans la race.'),
  ],
};

// Built once: breed names reach this lookup verbatim from a free-text field
// (Autocomplete suggests lib/data/breeds.dart's canonical names but doesn't
// enforce them), so matching is case-insensitive.
final _byLowerName = {
  for (final entry in breedPredispositions.entries) entry.key.toLowerCase(): entry.value,
};

List<BreedPredisposition> predispositionsForBreed(String breed) => _byLowerName[breed.trim().toLowerCase()] ?? const [];
