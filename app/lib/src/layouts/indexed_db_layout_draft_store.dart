// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'layout_draft_models.dart';
import 'layout_draft_repository.dart';

class IndexedDbLayoutDraftStore implements LayoutDraftStore {
  const IndexedDbLayoutDraftStore();

  @override
  Future<void> putLayoutDraft(DraftJson draft) {
    return _put(layoutDraftsStoreName, draft);
  }

  @override
  Future<DraftJson?> getLayoutDraft(String draftKey) {
    return _get(layoutDraftsStoreName, draftKey);
  }

  @override
  Future<void> deleteLayoutDraft(String draftKey) {
    return _delete(layoutDraftsStoreName, draftKey);
  }

  @override
  Future<void> putProjectCache(DraftJson cache) {
    return _put(projectCacheStoreName, cache);
  }

  @override
  Future<DraftJson?> getProjectCache(String cacheKey) {
    return _get(projectCacheStoreName, cacheKey);
  }

  @override
  Future<void> deleteProjectCache(String cacheKey) {
    return _delete(projectCacheStoreName, cacheKey);
  }

  Future<void> _put(String storeName, DraftJson value) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transactionStore(storeName, 'readwrite');
      await transaction.objectStore(storeName).put(value);
      await transaction.completed;
    } finally {
      database.close();
    }
  }

  Future<DraftJson?> _get(String storeName, String key) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transactionStore(storeName, 'readonly');
      final value = await transaction.objectStore(storeName).getObject(key);
      await transaction.completed;
      return _recordValueOrNull(value);
    } finally {
      database.close();
    }
  }

  Future<void> _delete(String storeName, String key) async {
    final database = await _openDatabase();
    try {
      final transaction = database.transactionStore(storeName, 'readwrite');
      await transaction.objectStore(storeName).delete(key);
      await transaction.completed;
    } finally {
      database.close();
    }
  }

  Future<dynamic> _openDatabase() {
    final dynamic factory = html.window.indexedDB;
    if (factory == null) {
      return Future.error(
        UnsupportedError('IndexedDB is not available in this browser.'),
      );
    }
    return factory.open(
      roomForgeDraftDatabaseName,
      version: roomForgeDraftDatabaseVersion,
      onUpgradeNeeded: _upgradeDatabase,
    );
  }

  void _upgradeDatabase(dynamic event) {
    final dynamic database = event.target.result;
    final stores = database.objectStoreNames ?? const <String>[];
    if (!stores.contains(layoutDraftsStoreName)) {
      database.createObjectStore(layoutDraftsStoreName, keyPath: 'draft_key');
    }
    if (!stores.contains(projectCacheStoreName)) {
      database.createObjectStore(projectCacheStoreName, keyPath: 'cache_key');
    }
  }

  DraftJson? _recordValueOrNull(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, Object?>) {
      return value;
    }
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }
    return null;
  }
}
