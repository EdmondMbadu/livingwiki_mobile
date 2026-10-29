import 'models.dart';

/// Mirrors functions/src/city-guide.ts in the web app, including legacy cities
/// and explicit city-persona overrides. University guides retain their identity.
bool usesPicamoCityGuide(Atlas atlas) {
  final wikiType = atlas.data.isEmpty ? atlas.kind : atlas.data['wiki_type'];
  if (wikiType == 'university' ||
      mapValue(atlas.data['university_config'])['enabled'] == true) {
    return false;
  }
  final city = mapValue(atlas.data['city_config']);
  return (wikiType == 'city' || city['enabled'] == true) &&
      mapValue(atlas.data['chat_guide'])['city_persona_override'] != true;
}

String cityGuideTagline(Atlas atlas) {
  final name = atlas.name.toLowerCase();
  if (name.contains('las vegas')) {
    return 'Bright lights. Local stories. Unexpected discoveries.';
  }
  if (name.contains('cape may')) return 'Victorian charm. Seaside stories.';
  if (name.contains('miami')) return 'Big color. Bold culture.';
  if (name.contains('philadelphia') || name.contains('philly')) {
    return 'Historic streets. Neighborhood stories.';
  }
  return 'Local stories. Hidden gems. Endless curiosity.';
}

class CityStarter {
  const CityStarter(this.title, this.question);
  final String title, question;
}

List<CityStarter> cityGuideStarters(Atlas atlas) => [
  CityStarter(
    'A local dinner spot',
    'Help me find a local dinner spot in ${atlas.name}. Share a few source-backed options and ask about my budget or preferences if needed.',
  ),
  CityStarter(
    atlas.name.toLowerCase().contains('las vegas')
        ? 'Beyond the Strip'
        : 'Hidden gems',
    'What can I discover beyond the best-known tourist sights in ${atlas.name}? Suggest a few interesting neighborhoods or places with sources.',
  ),
  CityStarter(
    'Plan my afternoon',
    'Help me plan an afternoon exploring ${atlas.name}. Ask what I enjoy and how I will get around before suggesting an itinerary.',
  ),
];
