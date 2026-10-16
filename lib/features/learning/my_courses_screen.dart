import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import 'learning_widgets.dart';

/// Mis cursos: en curso y terminados, con el mismo progreso que en la web.
class MyCoursesScreen extends ConsumerStatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  ConsumerState<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends ConsumerState<MyCoursesScreen> {
  late Future<(List<Enrollment>, int)> _active = _load('active');
  late Future<(List<Enrollment>, int)> _completed = _load('completed');

  Future<(List<Enrollment>, int)> _load(String scope) =>
      ref.read(lmsClientProvider).myEnrollments(scope: scope);

  Future<void> _reload() async {
    final a = _load('active');
    final c = _load('completed');
    setState(() {
      _active = a;
      _completed = c;
    });
    await Future.wait([a, c]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis cursos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En curso'),
              Tab(text: 'Terminados'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _List(
              future: _active,
              onReload: _reload,
              emptyText:
                  'Todavía no estás en ningún curso. Explora el catálogo.',
            ),
            _List(
              future: _completed,
              onReload: _reload,
              emptyText: 'Cuando termines un curso aparecerá aquí.',
            ),
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.future,
    required this.onReload,
    required this.emptyText,
  });

  final Future<(List<Enrollment>, int)> future;
  final Future<void> Function() onReload;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onReload,
      child: FutureBuilder<(List<Enrollment>, int)>(
        future: future,
        builder: (context, snap) {
          if (snap.hasError) {
            final e = snap.error;
            return errorView(
              e is ApiException ? e.message : 'No se pudo cargar.',
              onRetry: onReload,
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (items, _) = snap.data!;
          if (items.isEmpty) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(emptyText, textAlign: TextAlign.center),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [for (final e in items) EnrollmentTile(enrollment: e)],
          );
        },
      ),
    );
  }
}
