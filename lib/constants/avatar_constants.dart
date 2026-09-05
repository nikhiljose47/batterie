class AvatarConstants {
  const AvatarConstants._();

  static const String defaultAvatarId = 'avatar-boy-01';
  static const List<String> avatars = <String>[
    'avatar-boy-01',
    'avatar-boy-02',
    'avatar-boy-03',
    'avatar-boy-04',
    'avatar-girl-01',
    'avatar-girl-02',
    'avatar-girl-03',
    'avatar-girl-04',
  ];

  static const List<String> samplePeopleNames = <String>[
    'Alf',
    'Maya',
    'Ravi',
    'Nora',
    'Isha',
    'Dev',
    'Sara',
    'Omar',
    'Lina',
    'Noah',
    'Anya',
    'Kabir',
    'Mira',
    'Leo',
    'Tara',
    'Sam',
    'Zoya',
    'Arjun',
    'Eva',
    'Rian',
  ];

  static String assetPath(String id) => 'assets/avatars/$id.svg';
}
