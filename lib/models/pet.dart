import '../date_only.dart';

class Pet {
  const Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
  });

  final String id;
  final String ownerId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;

  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        species: json['species'] as String,
        breed: json['breed'] as String?,
        birthDate: json['birth_date'] == null ? null : DateTime.parse(json['birth_date'] as String),
      );

  Map<String, dynamic> toInsertJson({required String ownerId}) => {
        'owner_id': ownerId,
        'name': name,
        'species': species,
        if (breed != null) 'breed': breed,
        if (birthDate != null) 'birth_date': dateOnly(birthDate!),
      };
}
