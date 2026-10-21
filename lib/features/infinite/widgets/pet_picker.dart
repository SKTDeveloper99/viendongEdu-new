import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../pet.dart';
import 'pet_companion.dart';

/// One locally saved companion, independent of quest rewards and equipment.
class PetPicker extends StatelessWidget {
  const PetPicker({super.key, required this.pet, required this.onSelected});

  final InfinitePet pet;
  final ValueChanged<InfinitePet>? onSelected;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    color: context.vd.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(28),
      side: BorderSide(color: context.vd.hairline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Thú cưng của bạn',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.vd.ink,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final choice in InfinitePet.values)
                ChoiceChip(
                  label: Text(choice.pickerLabel),
                  labelStyle: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: context.vd.ink),
                  selected: pet == choice,
                  onSelected: onSelected == null
                      ? null
                      : (_) => onSelected!(choice),
                ),
            ],
          ),
          PetCompanion(pet: pet),
        ],
      ),
    ),
  );
}
