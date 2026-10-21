/// The two companions available in Infinite. Stored by stable enum name.
enum InfinitePet {
  cat('Mướp', '🐈'),
  dog('Cún', '🐕');

  const InfinitePet(this.label, this.placeholder);

  final String label;
  final String placeholder;

  static InfinitePet fromStored(String? value) =>
      values.where((pet) => pet.name == value).firstOrNull ?? cat;
}
