/// Page de Classement des utilisateurs et Dashboards communautaires Terebi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../domain/models/leaderboard_entry.dart';
import 'media_detail_page.dart';

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dashboardAsync = ref.watch(communityDashboardProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      appBar: Navigator.canPop(context)
          ? AppBar(
              title: const Text('Classement de la Communauté'),
            )
          : null,
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Erreur de chargement du classement : $err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: () => ref.refresh(communityDashboardProvider),
              ),
            ],
          ),
        ),
        data: (data) {
          final users = data.users;
          final top1 = users.isNotEmpty ? users[0] : null;
          final top2 = users.length > 1 ? users[1] : null;
          final top3 = users.length > 2 ? users[2] : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- TITRE ET BOUTON RAFRAÎCHIR ---
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Classement de la Communauté',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Découvre les membres les plus passionnés et les tops de Terebi',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualiser le classement',
                          onPressed: () => ref.refresh(communityDashboardProvider),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- DASHBOARDS D'INFORMATIONS COMMUNAUTAIRES ---
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide ? 3 : 1,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isWide ? 2.5 : 3.5,
                          children: [
                            _buildKpiCard(
                              context,
                              title: 'Membres Terebi',
                              value: '${data.totalUsers}',
                              subtitle: 'Comptes Terebi Cloud',
                              icon: Icons.people_outline,
                              color: colorScheme.primary,
                            ),
                            _buildKpiCard(
                              context,
                              title: 'Heures Cumulées',
                              value: '${data.totalHours.toStringAsFixed(1)} h',
                              subtitle: 'De visionnage d\'anime',
                              icon: Icons.timelapse,
                              color: Colors.purple,
                            ),
                            _buildKpiCard(
                              context,
                              title: 'Animes Différents',
                              value: '${data.uniqueAnimes}',
                              subtitle: 'Ajoutés en bibliothèques',
                              icon: Icons.movie_filter_outlined,
                              color: Colors.teal,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // --- TOP ANIMES LES PLUS POPULAIRES DANS LA COMMUNAUTÉ ---
                    if (data.topAnimes.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Les animes les plus suivis dans la communauté',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 150,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: data.topAnimes.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final anime = data.topAnimes[i];
                            return _buildTopAnimeCard(context, anime);
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // --- LE PODIUM DES 3 PREMIERS UTILISATEURS ---
                    if (users.isNotEmpty) ...[
                      Text(
                        'Podium des Meilleurs Visionneurs',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // 2ème place
                            if (top2 != null)
                              _buildPodiumStep(
                                context,
                                user: top2,
                                rank: 2,
                                height: 110,
                                medalColor: const Color(0xFFC0C0C0),
                                medalIcon: '🥈',
                              )
                            else
                              _buildEmptyPodiumSlot(
                                context,
                                rank: 2,
                                height: 110,
                                medalIcon: '🥈',
                                medalColor: const Color(0xFFC0C0C0),
                              ),

                            // 1ère place (plus haute)
                            if (top1 != null)
                              _buildPodiumStep(
                                context,
                                user: top1,
                                rank: 1,
                                height: 140,
                                medalColor: const Color(0xFFFFD700),
                                medalIcon: '👑',
                              ),

                            // 3ème place
                            if (top3 != null)
                              _buildPodiumStep(
                                context,
                                user: top3,
                                rank: 3,
                                height: 90,
                                medalColor: const Color(0xFFCD7F32),
                                medalIcon: '🥉',
                              )
                            else
                              _buildEmptyPodiumSlot(
                                context,
                                rank: 3,
                                height: 90,
                                medalIcon: '🥉',
                                medalColor: const Color(0xFFCD7F32),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // --- TABLEAU DE CLASSEMENT COMPLET ---
                    Text(
                      'Classement Général',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (users.isEmpty)
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            children: [
                              Icon(Icons.emoji_events_outlined, size: 48, color: colorScheme.outlineVariant),
                              const SizedBox(height: 12),
                              Text(
                                'Aucun membre classé pour l\'instant',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Synchronisez votre bibliothèque pour apparaître en tête du podium !',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final u = users[idx];
                          final isMe = currentUser != null && currentUser.id == u.id;
                          return ListTile(
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '#${u.rank}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: u.rank == 1
                                          ? Colors.amber
                                          : (u.rank == 2
                                              ? Colors.blueGrey
                                              : (u.rank == 3
                                                  ? Colors.brown
                                                  : colorScheme.onSurfaceVariant)),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isMe ? colorScheme.primary : colorScheme.outlineVariant,
                                      width: isMe ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    u.avatarPngUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Text(
                                  u.username,
                                  style: TextStyle(
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                                    color: isMe ? colorScheme.primary : null,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Moi',
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              u.bio.isNotEmpty ? u.bio : 'Membre Terebi',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildBadgeMetric(
                                  icon: Icons.movie_outlined,
                                  text: '${u.completedCount} finis',
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                _buildBadgeMetric(
                                  icon: Icons.play_arrow_outlined,
                                  text: '${u.episodesWatched} eps',
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                _buildBadgeMetric(
                                  icon: Icons.timer_outlined,
                                  text: '${u.watchedHours.toStringAsFixed(1)} h',
                                  color: Colors.purple,
                                  isBold: true,
                                ),
                              ],
                            ),
                            onTap: () => _showUserDetailModal(context, u),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAnimeCard(BuildContext context, CommunityTopAnime anime) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaDetailPage(
              mediaId: anime.mediaId,
              displayTitle: anime.title,
            ),
          ),
        );
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            if (anime.coverUrl != null && anime.coverUrl!.isNotEmpty)
              Image.network(
                anime.coverUrl!,
                width: 60,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  color: Colors.grey.shade800,
                  child: const Icon(Icons.movie, color: Colors.white54),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      anime.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '🔥 ${anime.trackingUsers} membres',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumStep(
    BuildContext context, {
    required LeaderboardUser user,
    required int rank,
    required double height,
    required Color medalColor,
    required String medalIcon,
  }) {
    final theme = Theme.of(context);
    final avatarSize = rank == 1 ? 74.0 : 60.0;

    return InkWell(
      onTap: () => _showUserDetailModal(context, user),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medalIcon, style: TextStyle(fontSize: rank == 1 ? 26 : 22)),
          const SizedBox(height: 4),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: medalColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: medalColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              user.avatarPngUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.username,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${user.watchedHours.toStringAsFixed(1)} h · ${user.episodesWatched} eps',
            style: theme.textTheme.labelSmall?.copyWith(
              color: medalColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medalColor.withValues(alpha: 0.7),
                  medalColor.withValues(alpha: 0.2),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPodiumSlot(
    BuildContext context, {
    required int rank,
    required double height,
    required String medalIcon,
    required Color medalColor,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medalIcon, style: const TextStyle(fontSize: 22, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: medalColor.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(Icons.person_outline, color: medalColor.withValues(alpha: 0.4), size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          'Place libre',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          'En attente',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 10),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: medalColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          alignment: Alignment.center,
          child: Text(
            '#$rank',
            style: TextStyle(
              color: medalColor.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeMetric({
    required IconData icon,
    required String text,
    required Color color,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailModal(BuildContext context, LeaderboardUser user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  user.avatarPngUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.username,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rang #${user.rank}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                user.bio.isNotEmpty ? user.bio : 'Membre de la communauté Terebi',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _modalStatCol(theme, 'Heures', '${user.watchedHours.toStringAsFixed(1)} h', Colors.purple),
                  _modalStatCol(theme, 'Épisodes', '${user.episodesWatched}', Colors.orange),
                  _modalStatCol(theme, 'Complétés', '${user.completedCount}', Colors.green),
                  _modalStatCol(theme, 'Total Liste', '${user.totalAnimes}', colorScheme.primary),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _modalStatCol(ThemeData theme, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
