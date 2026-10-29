import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/city_guide.dart';
import '../data/models.dart';

/// Native presentation of the web app's Picamo city campaign.
class PicamoCityHero extends StatelessWidget {
  const PicamoCityHero({super.key, required this.atlas});
  final Atlas atlas;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: Stack(
      children: [
        Positioned.fill(
          child: Photo(
            url:
                stringValue(
                  mapValue(atlas.data['chat_guide'])['banner_url'],
                ).isNotEmpty
                ? stringValue(mapValue(atlas.data['chat_guide'])['banner_url'])
                : atlas.image,
            asset: atlas.localImage,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xF0083D2C),
                  Color(0xE61A4935),
                  Color(0xCC162F25),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 550;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow(
                    'Your curious city guide',
                    color: Color(0xFFD4E4CE),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Picamo Knows',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${atlas.name}.',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Palette.gold,
                      fontSize: wide ? 48 : 42,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    cityGuideTagline(atlas),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.55,
                    ),
                  ),
                ],
              );
              Widget mascot(double width) => Image.asset(
                'assets/images/picamo-city-guide.webp',
                width: width,
                fit: BoxFit.contain,
                semanticLabel:
                    'Picamo welcoming you to ${atlas.name} with a city map',
              );
              const introduction = Text(
                'Your curious guide to the city, powered by LivingWiki.',
                style: TextStyle(
                  color: Color(0xFFDFE9D9),
                  fontSize: 12,
                  height: 1.65,
                ),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 20),
                            introduction,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    mascot(190),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 24),
                          child: introduction,
                        ),
                      ),
                      const SizedBox(width: 12),
                      mascot(constraints.maxWidth < 260 ? 100 : 124),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}

class PicamoCityStarters extends StatelessWidget {
  const PicamoCityStarters({
    super.key,
    required this.atlas,
    required this.onSelected,
  });
  final Atlas atlas;
  final ValueChanged<CityStarter> onSelected;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/images/picamo.webp',
              width: 38,
              height: 38,
              semanticLabel: 'Picamo',
            ),
            const SizedBox(width: 12),
            const Expanded(child: Eyebrow('Ask Picamo')),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'What would you like to explore?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        for (final starter in cityGuideStarters(atlas))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(switch (starter.title) {
              'A local dinner spot' => Icons.restaurant_outlined,
              'Plan my afternoon' => Icons.wb_sunny_outlined,
              _ => Icons.explore_outlined,
            }, size: 20),
            title: Text(starter.title, style: const TextStyle(fontSize: 13)),
            trailing: const Icon(Icons.north_east_rounded, size: 17),
            onTap: () => onSelected(starter),
          ),
      ],
    ),
  );
}
