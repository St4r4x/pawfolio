import 'package:flutter/material.dart';

/// Species picker shared by the add/edit pet sheet and onboarding.
class SpeciesDropdown extends StatelessWidget {
  const SpeciesDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      items: const [
        DropdownMenuItem(value: 'dog', child: Text('Chien')),
        DropdownMenuItem(value: 'cat', child: Text('Chat')),
        DropdownMenuItem(value: 'other', child: Text('Autre')),
      ],
      onChanged: (v) => onChanged(v!),
    );
  }
}
