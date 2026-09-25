import 'package:ballys_reservation_app/core/constants.dart';
import 'package:ballys_reservation_app/data/repositories/duty_manager_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/models/duty_manager.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DutyManagerScreen extends ConsumerStatefulWidget {
  const DutyManagerScreen({super.key});

  @override
  ConsumerState<DutyManagerScreen> createState() => _DutyManagerScreenState();
}

class _DutyManagerScreenState extends ConsumerState<DutyManagerScreen> {
  final _repo = DutyManagerRepository(ApiService(SecureStorage.instance));
  late Future<List<DutyManager>> _future;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getOnDutyManagers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<DutyManager> _filter(List<DutyManager> managers) {
    if (_searchQuery.isEmpty) return managers;
    return managers
        .where(
          (m) =>
              m.name.toLowerCase().contains(_searchQuery) ||
              m.department.toLowerCase().contains(_searchQuery) ||
              m.designation.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  Future<void> _refresh() async {
    final future = _repo.getOnDutyManagers();
    setState(() => _future = future);
    await future.catchError((_) => <DutyManager>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by name, department or designation...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Color.fromARGB(179, 0, 0, 0)),
                ),
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              )
            : const Text('On Duty Manager'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 28),
            tooltip: _isSearching ? 'Close Search' : 'Search',
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<DutyManager>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // Same loader as the Birthdays screen.
              return Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(135, 117, 115, 115),
                ),
                child: const Center(
                  child: RefreshProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Constants.kSecondaryColor,
                    ),
                  ),
                ),
              );
            }
            if (snapshot.hasError) {
              return _message('Failed to load duty managers');
            }
            final all = snapshot.data ?? [];
            if (all.isEmpty) {
              return _message('No managers on duty');
            }
            final managers = _filter(all);
            if (managers.isEmpty) {
              return _message('No matching managers');
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: managers.length,
              itemBuilder: (context, index) => _managerCard(managers[index]),
            );
          },
        ),
      ),
    );
  }

  // Wrapped in a scrollable so pull-to-refresh still works on empty/error.
  Widget _message(String text) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 200),
        Center(
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _managerCard(DutyManager m) {
    final fontSettings = ref.watch(fontSettingsProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color.fromARGB(255, 21, 101, 192),
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize,
                      fontWeight: fontSettings.fontWeight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.designation,
                    style: TextStyle(
                      fontSize: fontSettings.fontSize - 1,
                      fontWeight: fontSettings.fontWeight,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                 
                  Row(
                    children: [
                      Text(
                        'In Time : ',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 1,
                          fontWeight: fontSettings.fontWeight,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        m.inTime,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 1,
                          fontWeight: fontSettings.fontWeight,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                    const SizedBox(height: 4),
                     Row(
                    children: [
                      Text(
                        'Department : ',
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 1,
                          fontWeight: fontSettings.fontWeight,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        m.department,
                        style: TextStyle(
                          fontSize: fontSettings.fontSize - 1,
                          fontWeight: fontSettings.fontWeight,
                          // color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  // Text(
                  //   m.department,
                  //   style: TextStyle(
                  //     fontSize: fontSettings.fontSize - 3,
                  //     fontWeight: fontSettings.fontWeight,
                  //     color: Colors.grey.shade600,
                  //   ),
                  // ),
                 
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
