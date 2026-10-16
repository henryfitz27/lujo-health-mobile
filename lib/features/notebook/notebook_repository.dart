import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';

/// Estado del cuaderno en memoria: entradas y colecciones propias, más los cambios pendientes
/// de enviar cuando no hay conexión.
class NotebookState {
  const NotebookState({
    required this.entries,
    required this.collections,
    required this.pending,
    required this.lastSync,
    required this.offline,
  });

  final List<NotebookEntry> entries;
  final List<NotebookCollection> collections;

  /// Operaciones locales pendientes (create / update / delete) en orden.
  final List<PendingOp> pending;
  final DateTime? lastSync;

  /// `true` cuando la última sincronización falló por red: la UI muestra el aviso.
  final bool offline;

  NotebookState copyWith({
    List<NotebookEntry>? entries,
    List<NotebookCollection>? collections,
    List<PendingOp>? pending,
    DateTime? lastSync,
    bool? offline,
  }) => NotebookState(
    entries: entries ?? this.entries,
    collections: collections ?? this.collections,
    pending: pending ?? this.pending,
    lastSync: lastSync ?? this.lastSync,
    offline: offline ?? this.offline,
  );

  static const empty = NotebookState(
    entries: [],
    collections: [],
    pending: [],
    lastSync: null,
    offline: false,
  );

  List<NotebookEntry> get favorites =>
      entries.where((e) => e.favorite).toList();

  List<NotebookEntry> inCollection(String id) =>
      entries.where((e) => e.collectionIds.contains(id)).toList();

  NotebookEntry? entry(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}

/// Operación pendiente de sincronizar. Los ids locales empiezan por `local-` hasta que la API
/// devuelve el definitivo.
class PendingOp {
  const PendingOp({
    required this.op,
    required this.entryId,
    required this.input,
    required this.at,
  });

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
    op: json['op'] as String,
    entryId: json['entryId'] as String,
    input: json['input'] as Map<String, dynamic>? ?? const {},
    at: DateTime.parse(json['at'] as String),
  );

  final String op; // create | update | delete
  final String entryId;
  final Map<String, dynamic> input;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'op': op,
    'entryId': entryId,
    'input': input,
    'at': at.toUtc().toIso8601String(),
  };
}

/// Caché en disco (JSON) del cuaderno. Es suficiente para el MVP; si el volumen crece se
/// migra a drift sin cambiar la interfaz del notifier.
class NotebookCache {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/notebook.json');
  }

  Future<NotebookState> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return NotebookState.empty;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return NotebookState(
        entries: NotebookEntry.listFromJson(json['entries']),
        collections: NotebookCollection.listFromJson(json['collections']),
        pending: [
          for (final p in json['pending'] as List? ?? const [])
            PendingOp.fromJson(p as Map<String, dynamic>),
        ],
        lastSync: json['lastSync'] == null
            ? null
            : DateTime.parse(json['lastSync'] as String),
        offline: false,
      );
    } catch (e) {
      debugPrint('caché del cuaderno ilegible: $e');
      return NotebookState.empty;
    }
  }

  Future<void> save(NotebookState s) async {
    try {
      final f = await _file();
      await f.writeAsString(
        jsonEncode({
          'entries': [for (final e in s.entries) e.toJson()],
          'collections': [for (final c in s.collections) c.toJson()],
          'pending': [for (final p in s.pending) p.toJson()],
          'lastSync': s.lastSync?.toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('no se pudo guardar la caché del cuaderno: $e');
    }
  }

  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

bool _isNetworkError(Object e) =>
    e is ApiException && (e.code == 'network' || e.statusCode == 0);

/// Fuente de verdad del cuaderno en la app. Carga la caché al instante, sincroniza con
/// `updated_since` y encola los cambios hechos sin conexión.
class NotebookNotifier extends AsyncNotifier<NotebookState> {
  final _cache = NotebookCache();

  @override
  Future<NotebookState> build() async {
    final cached = await _cache.load();
    // Sincroniza en segundo plano sin bloquear la primera pintura.
    Future.microtask(sync);
    return cached;
  }

  NotebookState get _current => state.value ?? NotebookState.empty;

  Future<void> _set(NotebookState s) async {
    state = AsyncData(s);
    await _cache.save(s);
  }

  /// Envía lo pendiente y trae los cambios del servidor desde la última sincronización.
  Future<void> sync() async {
    final api = ref.read(apiClientProvider);
    var s = _current;
    try {
      s = await _flush(api, s);
      final since = s.lastSync;
      final now = DateTime.now();
      final remoteEntries = await api.notebookEntries(updatedSince: since);
      final remoteCollections = await api.notebookCollections(
        updatedSince: since,
      );
      // Si no había caché, también hay que traer todo lo demás.
      final entries = since == null
          ? remoteEntries.where((e) => e.deletedAt == null).toList()
          : _merge(s.entries, remoteEntries);
      final collections = since == null
          ? remoteCollections.where((c) => c.deletedAt == null).toList()
          : _mergeCollections(s.collections, remoteCollections);
      await _set(
        s.copyWith(
          entries: _sorted(entries),
          collections: collections,
          lastSync: now,
          offline: false,
        ),
      );
    } catch (e) {
      if (_isNetworkError(e)) {
        await _set(s.copyWith(offline: true));
      } else {
        debugPrint('sincronización del cuaderno: $e');
        await _set(s.copyWith(offline: false));
      }
    }
  }

  List<NotebookEntry> _sorted(List<NotebookEntry> list) =>
      list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<NotebookEntry> _merge(
    List<NotebookEntry> local,
    List<NotebookEntry> remote,
  ) {
    final byId = {for (final e in local) e.id: e};
    for (final r in remote) {
      final l = byId[r.id];
      // Los cambios locales pendientes prevalecen hasta que se envíen.
      if (l != null && l.pendingSync) continue;
      if (r.deletedAt != null) {
        byId.remove(r.id);
      } else {
        byId[r.id] = r;
      }
    }
    return byId.values.toList();
  }

  List<NotebookCollection> _mergeCollections(
    List<NotebookCollection> local,
    List<NotebookCollection> remote,
  ) {
    final byId = {for (final c in local) c.id: c};
    for (final r in remote) {
      if (r.deletedAt != null) {
        byId.remove(r.id);
      } else {
        byId[r.id] = r;
      }
    }
    final out = byId.values.toList()
      ..sort((a, b) {
        final byCount = b.entriesCount.compareTo(a.entriesCount);
        return byCount != 0 ? byCount : a.position.compareTo(b.position);
      });
    return out;
  }

  /// Envía las operaciones pendientes en orden. Si falla por red se detiene y conserva el resto.
  Future<NotebookState> _flush(ApiClient api, NotebookState s) async {
    if (s.pending.isEmpty) return s;
    final remaining = [...s.pending];
    var entries = [...s.entries];
    final idMap = <String, String>{};
    while (remaining.isNotEmpty) {
      final op = remaining.first;
      final id = idMap[op.entryId] ?? op.entryId;
      try {
        switch (op.op) {
          case 'create':
            final created = await api.createNotebookEntry(op.input);
            idMap[op.entryId] = created.id;
            entries = [
              for (final e in entries)
                if (e.id == op.entryId) created else e,
            ];
          case 'update':
            if (id.startsWith('local-')) break; // su creación falló antes
            try {
              final updated = await api.updateNotebookEntry(id, op.input);
              entries = [
                for (final e in entries)
                  if (e.id == id) updated else e,
              ];
            } on ApiException catch (e) {
              // Conflicto: gana el servidor; el usuario ve la versión actual.
              if (e.code != 'conflict') rethrow;
              final current = await api.notebookEntry(id);
              entries = [
                for (final e in entries)
                  if (e.id == id) current else e,
              ];
            }
          case 'delete':
            if (!id.startsWith('local-')) {
              try {
                await api.deleteNotebookEntry(id);
              } on ApiException catch (e) {
                if (e.statusCode != 404) rethrow;
              }
            }
            entries = entries.where((e) => e.id != id).toList();
        }
        remaining.removeAt(0);
      } catch (e) {
        if (_isNetworkError(e)) {
          return s.copyWith(
            entries: entries,
            pending: remaining,
            offline: true,
          );
        }
        // Error de validación u otro: se descarta la operación para no bloquear la cola.
        debugPrint('operación del cuaderno descartada: $e');
        remaining.removeAt(0);
        if (op.op == 'create') {
          entries = entries.where((e) => e.id != op.entryId).toList();
        }
      }
    }
    return s.copyWith(entries: entries, pending: remaining, offline: false);
  }

  /// Recarga las colecciones (los contadores cambian al guardar o borrar entradas).
  Future<void> _refreshCollections() async {
    try {
      final cols = await ref.read(apiClientProvider).notebookCollections();
      await _set(
        _current.copyWith(collections: _mergeCollections(const [], cols)),
      );
    } catch (_) {}
  }

  // --- Operaciones del usuario ---

  /// Crea una entrada. Si no hay red, queda local con id temporal y se envía después.
  Future<NotebookEntry> create(Map<String, dynamic> input) async {
    final api = ref.read(apiClientProvider);
    final s = _current;
    try {
      final created = await api.createNotebookEntry(input);
      await _set(
        s.copyWith(entries: _sorted([created, ...s.entries]), offline: false),
      );
      _refreshCollections();
      return created;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final now = DateTime.now();
      final local = NotebookEntry.fromJson({
        ...input,
        'id': 'local-${now.microsecondsSinceEpoch}',
        'createdAt': now.toUtc().toIso8601String(),
        'updatedAt': now.toUtc().toIso8601String(),
        'access': 'owner',
        'pendingSync': true,
        'media': null,
        'post': null,
        'recipe': null,
        'ingredient': null,
      });
      await _set(
        s.copyWith(
          entries: [local, ...s.entries],
          pending: [
            ...s.pending,
            PendingOp(op: 'create', entryId: local.id, input: input, at: now),
          ],
          offline: true,
        ),
      );
      return local;
    }
  }

  Future<NotebookEntry> save(NotebookEntry entry) async {
    final api = ref.read(apiClientProvider);
    final s = _current;
    final now = DateTime.now();
    final input = entry.toInput(clientUpdatedAt: now);
    if (entry.id.startsWith('local-')) {
      // Aún no existe en la API: se actualiza la operación de creación pendiente.
      final pending = [
        for (final p in s.pending)
          if (p.entryId == entry.id && p.op == 'create')
            PendingOp(op: 'create', entryId: p.entryId, input: input, at: now)
          else
            p,
      ];
      final local = entry.copyWith(updatedAt: now, pendingSync: true);
      await _set(
        s.copyWith(
          entries: _sorted([
            for (final e in s.entries)
              if (e.id == entry.id) local else e,
          ]),
          pending: pending,
        ),
      );
      return local;
    }
    try {
      final updated = await api.updateNotebookEntry(entry.id, input);
      await _set(
        s.copyWith(
          entries: _sorted([
            for (final e in s.entries)
              if (e.id == entry.id) updated else e,
          ]),
          offline: false,
        ),
      );
      _refreshCollections();
      return updated;
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      final local = entry.copyWith(updatedAt: now, pendingSync: true);
      await _set(
        s.copyWith(
          entries: _sorted([
            for (final e in s.entries)
              if (e.id == entry.id) local else e,
          ]),
          pending: [
            ...s.pending,
            PendingOp(op: 'update', entryId: entry.id, input: input, at: now),
          ],
          offline: true,
        ),
      );
      return local;
    }
  }

  Future<void> delete(String id) async {
    final api = ref.read(apiClientProvider);
    final s = _current;
    final without = s.entries.where((e) => e.id != id).toList();
    if (id.startsWith('local-')) {
      await _set(
        s.copyWith(
          entries: without,
          pending: s.pending.where((p) => p.entryId != id).toList(),
        ),
      );
      return;
    }
    try {
      await api.deleteNotebookEntry(id);
      await _set(s.copyWith(entries: without, offline: false));
      _refreshCollections();
    } catch (e) {
      if (!_isNetworkError(e)) rethrow;
      await _set(
        s.copyWith(
          entries: without,
          pending: [
            ...s.pending,
            PendingOp(
              op: 'delete',
              entryId: id,
              input: const {},
              at: DateTime.now(),
            ),
          ],
          offline: true,
        ),
      );
    }
  }

  Future<void> setFavorite(NotebookEntry entry, bool favorite) =>
      save(entry.copyWith(favorite: favorite));

  /// Marca o desmarca un elemento de una lista de preguntas o tareas.
  Future<void> toggleItem(NotebookEntry entry, int index) => save(
    entry.copyWith(
      items: [
        for (var i = 0; i < entry.items.length; i++)
          i == index
              ? entry.items[i].copyWith(done: !entry.items[i].done)
              : entry.items[i],
      ],
    ),
  );

  // --- Colecciones (requieren red; son poco frecuentes) ---

  Future<NotebookCollection> createCollection(
    Map<String, dynamic> input,
  ) async {
    final c = await ref.read(apiClientProvider).createCollection(input);
    await _set(_current.copyWith(collections: [..._current.collections, c]));
    return c;
  }

  Future<NotebookCollection> updateCollection(
    String id,
    Map<String, dynamic> input,
  ) async {
    final c = await ref.read(apiClientProvider).updateCollection(id, input);
    await _set(
      _current.copyWith(
        collections: [
          for (final x in _current.collections)
            if (x.id == id) c else x,
        ],
      ),
    );
    return c;
  }

  Future<void> deleteCollection(String id) async {
    await ref.read(apiClientProvider).deleteCollection(id);
    final s = _current;
    await _set(
      s.copyWith(
        collections: s.collections.where((c) => c.id != id).toList(),
        entries: [
          for (final e in s.entries)
            e.collectionIds.contains(id)
                ? e.copyWith(
                    collectionIds: e.collectionIds
                        .where((c) => c != id)
                        .toList(),
                  )
                : e,
        ],
      ),
    );
  }

  /// Búsqueda local inmediata (título, cuerpo, etiquetas, elementos) para modo sin conexión.
  List<NotebookEntry> searchLocal(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _current.entries.where((e) {
      final hay = [
        e.title,
        e.body,
        e.transcript,
        e.modifications,
        e.url,
        ...e.tags,
        ...e.items.map((i) => i.text),
        e.post?.title ?? '',
        e.recipe?.title ?? '',
        e.ingredient?.name ?? '',
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  /// Borra la caché local (al cerrar sesión o eliminar la cuenta).
  Future<void> clearLocal() async {
    await _cache.clear();
    state = const AsyncData(NotebookState.empty);
  }
}

final notebookProvider = AsyncNotifierProvider<NotebookNotifier, NotebookState>(
  NotebookNotifier.new,
);
