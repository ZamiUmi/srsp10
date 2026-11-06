import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../repositories/app_repository.dart';

// Провайдер базы данных (доступен во всем приложении)
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Провайдер репозитория
final appRepositoryProvider = Provider<AppRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AppRepository(db);
});

// Реактивный провайдер списка пользователей
final usersStreamProvider = StreamProvider<List<User>>((ref) {
  final repository = ref.watch(appRepositoryProvider);
  return repository.watchUsers();
});

// Реактивный провайдер списка проектов
final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final repository = ref.watch(appRepositoryProvider);
  return repository.watchProjects();
});
// Реактивный провайдер списка задач
final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final repository = ref.watch(appRepositoryProvider);
  return repository.watchTasks();
});
// Провайдер для получения задач конкретного проекта
final tasksForProjectStreamProvider = StreamProvider.family<List<Task>, int>((ref, projectId) {
  return ref.watch(appRepositoryProvider).watchTasksForProject(projectId);
});

// Провайдер для получения удаленных задач (корзины)
final deletedTasksStreamProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(appRepositoryProvider).watchDeletedTasks();
});