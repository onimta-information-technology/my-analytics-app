// lib/screens/member/cdd_names_screen.dart

import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/models/cdd/cdd_history_item.dart';
import 'package:ballys_reservation_app/providers/cdd_history_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CddNamesScreen extends ConsumerWidget {
  const CddNamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHistory = ref.watch(cddHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/memberMain'),
        ),
        title: const Text('Customer Due Diligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,size: 30,),
            onPressed: () =>
                ref.read(cddHistoryProvider.notifier).refresh(),
          ),
        ],
      ),

      // ── + FAB → new CDD form ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        backgroundColor: Constants.kPrimaryColor,
        onPressed: () => context.push('/memberMain/cdd/new'),
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: asyncHistory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(cddHistoryProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No records found.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // Group items by name (text6)
          final Map<String, List<CddHistoryItem>> grouped = {};
          for (final item in items) {
            grouped.putIfAbsent(item.text6, () => []).add(item);
          }

          final names = grouped.keys.toList();

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(cddHistoryProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: names.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final name = names[index];
                final count = grouped[name]!.length;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor:
                        Constants.kPrimaryColor.withOpacity(0.12),
                    child: Text(
                      // First letter of name
                      name.isNotEmpty
                          ? name.trimLeft()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Constants.kPrimaryColor,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    '$count submission${count > 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 13, color: const Color.fromARGB(255, 0, 0, 0)),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Color.fromARGB(255, 0, 0, 0)),
                  onTap: () => context.push(
                    '/memberMain/cdd/cards',
                    extra: grouped[name]!,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}