import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/movie/movie.dart';
import '../../services/collections/collections_service.dart';
import '../../services/collections/curated_collection.dart';
import '../../services/storage/app_image_cache.dart';
import '../../services/theme/design_tokens.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/common/poster_skeleton.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/movie/movie_card.dart';
import 'collection_grid_page.dart';

/// Browse vertical listing every curated film pack, grouped by kind.
///
/// Nothing on this screen is fetched in its own right: every collection comes
/// from [CollectionsService], whose cards carry a metahub poster URL, so the hub
/// paints in full without a request. That list is the bundled set until a TMDb
/// key is configured, when the 1990s era tiles show their ranked films.
class CollectionsPage extends StatelessWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.bg,
      body: ValueListenableBuilder<List<CuratedCollection>>(
        valueListenable: CollectionsService.collections,
        builder: (context, collections, _) {
          final sagas = [
            for (final collection in collections)
              if (collection.kind == CuratedKind.saga) collection,
          ];
          final eras = [
            for (final collection in collections)
              if (collection.kind == CuratedKind.era) collection,
          ];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _PageHeader()),
              if (sagas.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Group(label: 'Franchises', collections: sagas),
                ),
              if (eras.isNotEmpty)
                SliverToBoxAdapter(
                  child: _Group(label: 'Memory Lane', collections: eras),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      ZplaySpacing.s24 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZplaySpacing.s20,
        ZplaySpacing.s20,
        ZplaySpacing.s20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: tokens.accent,
                  borderRadius: ZplayRadius.xsAll,
                ),
              ),
              const SizedBox(width: ZplaySpacing.s12),
              Text(
                'Collections',
                style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: ZplaySpacing.s8),
          Text(
            'Hand-picked film packs, in watch order.',
            style: ZplayType.body.toStyle(color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String label;
  final List<CuratedCollection> collections;

  const _Group({required this.label, required this.collections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: ZplaySpacing.s24),
        SectionHeader(title: label, count: collections.length),
        const SizedBox(height: ZplaySpacing.s16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s20),
          child: Wrap(
            spacing: ZplaySpacing.s16,
            runSpacing: ZplaySpacing.s24,
            children: [
              for (final collection in collections)
                CollectionTile(collection: collection),
            ],
          ),
        ),
      ],
    );
  }
}

/// One collection in the hub: a poster mosaic over the title, film count and the
/// collection's own subtitle. Sized like a [MovieCard] so the hub reads as the
/// same grid language as the rest of the app.
class CollectionTile extends StatelessWidget {
  final CuratedCollection collection;

  const CollectionTile({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final width = MovieCardSizing.fromWidth(
      MediaQuery.sizeOf(context).width,
    ).cardWidth;

    return SizedBox(
      width: width,
      child: FocusableCard(
        onTap: () {
          Navigator.push(
            context,
            LiquidRevealRoute(page: CollectionGridPage(collection: collection)),
          );
        },
        builder: (context, state) => AnimatedScale(
          duration: ZplayMotion.fast,
          curve: ZplayMotion.standard,
          scale: state.pressed ? 0.98 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardFocusRing(
                focused: state.focused,
                radius: ZplayRadius.mdAll,
                child: _Mosaic(
                  movies: CollectionsService.moviesFor(collection),
                  width: width,
                ),
              ),
              const SizedBox(height: ZplaySpacing.s8),
              Text(
                collection.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZplayType.subtitle.toStyle(color: tokens.textPrimary),
              ),
              const SizedBox(height: ZplaySpacing.s4),
              Text(
                collection.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ZplayType.caption.toStyle(color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Up to three posters side by side. The slot height is fixed to what three
/// poster columns need, so a one-film pack keeps the same tile height as a
/// nine-film one and the wrap rows stay flush.
class _Mosaic extends StatelessWidget {
  final List<Movie> movies;
  final double width;

  const _Mosaic({required this.movies, required this.width});

  static const double _posterAspect = 1.48;

  @override
  Widget build(BuildContext context) {
    final slots = movies.take(3).toList();
    final height = ((width - ZplaySpacing.s4 * 2) / 3) * _posterAspect;

    return ClipRRect(
      borderRadius: ZplayRadius.mdAll,
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: context.tokens.surface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < slots.length; index++) ...[
                if (index > 0) const SizedBox(width: ZplaySpacing.s4),
                Expanded(child: _slot(slots[index])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(Movie movie) {
    final poster = movie.poster;
    if (poster == null || poster.isEmpty) return const MissingPoster();

    return CachedNetworkImage(
      imageUrl: poster,
      cacheManager: AppImageCache.manager,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      placeholder: (context, url) => const SizedBox.expand(),
      errorWidget: (context, url, error) => const MissingPoster(),
    );
  }
}
