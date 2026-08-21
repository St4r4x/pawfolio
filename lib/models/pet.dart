import '../date_only.dart';

class Pet {
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.photoUrl,
  });

  final String id;
  final String ownerId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final String? photoUrl;

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        species: json['species'] as String,
        breed: json['breed'] as String?,
        birthDate: json['birth_date'] == null ? null : DateTime.parse(json['birth_date'] as String),
        photoUrl: json['photo_url'] as String?,
      );

  // Always sent, even when null: toInsertJson is reused for update(), and an
  // omitted key leaves the existing column untouched instead of clearing it.
  Map<String, dynamic> toInsertJson({required String ownerId}) => {
        'owner_id': ownerId,
        'name': name,
        'species': species,
        'breed': breed,
        'birth_date': birthDate == null ? null : dateOnly(birthDate!),
        'photo_url': photoUrl,
      };
}

const _speciesLabels = {'dog': 'Chien', 'cat': 'Chat', 'other': 'Autre'};

String speciesLabel(String species) => _speciesLabels[species] ?? species;
