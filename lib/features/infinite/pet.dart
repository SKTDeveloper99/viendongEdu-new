/// The two companions available in Infinite. Stored by stable enum name.
enum InfinitePet {
  cat('Mướp', 'Mèo Mướp', 'assets/infinite/pets/cat.webp'),
  dog('Cún', 'Chó Cún', 'assets/infinite/pets/dog.webp');

  const InfinitePet(this.label, this.pickerLabel, this.asset);

  final String label;
  final String pickerLabel;
  final String asset;

  static InfinitePet fromStored(String? value) =>
      values.where((pet) => pet.name == value).firstOrNull ?? cat;
}
