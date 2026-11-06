import 'package:drift/drift.dart';
import '../database/app_database.dart';

class AppRepository {
  final AppDatabase _db;

  AppRepository(this._db);

  // --- ПОЛЬЗОВАТЕЛИ ---
  Stream<List<User>> watchUsers() => _db.select(_db.users).watch();

  Future<int> createUser(String name, String email) async {
    return await _db.into(_db.users).insert(
          UsersCompanion.insert(
            name: name,
            email: email,
            createdAt: DateTime.now(),
          ),
        );
  }

  // --- ПРОЕКТЫ ---
  Stream<List<Project>> watchProjects() => _db.select(_db.projects).watch();

  Future<int> createProject(String name, String? description, DateTime? dueDate, String status) async {
    return await _db.into(_db.projects).insert(
          ProjectsCompanion.insert(
            name: name,
            description: Value(description),
            createdAt: DateTime.now(),
            dueDate: Value(dueDate),
            status: status,
          ),
        );
  }

  // Мягкое удаление задачи (Soft Delete вместо полного удаления из БД)
  Future<void> softDeleteTask(int taskId, int currentUserId) async {
    await _db.transaction(() async {
      // 1. Помечаем задачу как удаленную, проставляя дату удаления
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          deletedAt: Value(DateTime.now()),
        ),
      );

      // 2. Логируем это действие в таблицу истории
      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: const Value('deleted'),
              newStatus: 'deleted',
              userId: currentUserId,
              createdAt: DateTime.now(),
            ),
          );
    });
  }

  // Получить историю изменений для конкретной задачи (реактивно)
  Stream<List<TaskHistoryData>> watchTaskHistory(int taskId) {
    return (_db.select(_db.taskHistory)
          ..where((h) => h.taskId.equals(taskId))
          ..orderBy([(h) => OrderingTerm.desc(h.createdAt)]))
        .watch();
  }

  // Получить задачи только для определенного проекта (реактивно)
  Stream<List<Task>> watchTasksForProject(int projectId) {
    return (_db.select(_db.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull()))
        .watch();
  }

  // Изменить статус задачи (с автоматическим обновлением даты изменения)
  Future<void> updateTaskStatusSimple(int taskId, String newStatus) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: Value(newStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Получить список только удаленных задач (для корзины, реактивно)
  Stream<List<Task>> watchDeletedTasks() {
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNotNull()))
        .watch();
  }

  // Восстановить удаленную задачу (сбрасываем deleted_at в null)
  Future<void> restoreTask(int taskId, int currentUserId) async {
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        const TasksCompanion(
          deletedAt: Value(null),
        ),
      );

      // Записываем в историю факт восстановления
      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: const Value('deleted'),
              newStatus: 'restored',
              userId: currentUserId,
              createdAt: DateTime.now(),
            ),
          );
    });
  }

  // --- ЗАДАЧИ ---
  Stream<List<Task>> watchTasks() => _db.select(_db.tasks).watch();

  Future<void> createTask({
    required String title,
    required String? description,
    required int projectId,
    required int? assigneeId,
    required String priority,
    required String status,
    required DateTime dueDate,
    required int currentUserId,
  }) async {
    await _db.transaction(() async {
      final taskId = await _db.into(_db.tasks).insert(
            TasksCompanion.insert(
              title: title,
              description: Value(description),
              projectId: projectId,
              assigneeId: Value(assigneeId),
              priority: priority,
              status: status,
              dueDate: dueDate,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      await _db.into(_db.taskHistory).insert(
            TaskHistoryCompanion.insert(
              taskId: taskId,
              previousStatus: const Value(null),
              newStatus: status,
              userId: currentUserId,
              createdAt: DateTime.now(),
            ),
          );
    });
  }

  Future<void> updateTaskStatus({
    required int taskId,
    required String newStatus,
    required int currentUserId,
  }) async {
    await _db.transaction(() async {
      final task = await (_db.select(_db.tasks)
            ..where((t) => t.id.equals(taskId)))
          .getSingle();

      final oldStatus = task.status;

      if (oldStatus != newStatus) {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
          TasksCompanion(
            status: Value(newStatus),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await _db.into(_db.taskHistory).insert(
              TaskHistoryCompanion.insert(
                taskId: taskId,
                previousStatus: Value(oldStatus),
                newStatus: newStatus,
                userId: currentUserId,
                createdAt: DateTime.now(),
              ),
            );
      }
    });
  }

  // --- СТАТИСТИКА (Dashboard) ---
  Future getStatistics() async {
    const projectCountQuery = 'SELECT COUNT(*) FROM projects;';
    final projectCountRes = await _db.customSelect(projectCountQuery).getSingle();
    final totalProjects = projectCountRes.read<int>('COUNT(*)');

    const taskCountQuery = 'SELECT COUNT(*) FROM tasks;';
    final taskCountRes = await _db.customSelect(taskCountQuery).getSingle();
    final totalTasks = taskCountRes.read<int>('COUNT(*)');

    // Исправлено: двойные кавычки заменены на одинарные
    const completedTasksQuery = "SELECT COUNT(*) FROM tasks WHERE status = 'done';";
    final completedRes = await _db.customSelect(completedTasksQuery).getSingle();
    final completedTasks = completedRes.read<int>('COUNT(*)');

    // Исправлено: двойные кавычки заменены на одинарные
    const incompleteTasksQuery = "SELECT COUNT(*) FROM tasks WHERE status != 'done';";
    final incompleteRes = await _db.customSelect(incompleteTasksQuery).getSingle();
    final incompleteTasks = incompleteRes.read<int>('COUNT(*)');

    final nowStr = DateTime.now().toIso8601String();
    // Исправлено: двойные кавычки заменены на одинарные
    final overdueQuery = "SELECT COUNT(*) FROM tasks WHERE due_date < ? AND status != 'done' AND status != 'cancelled';";
    final overdueRes = await _db.customSelect(overdueQuery, variables: [Variable.withString(nowStr)]).getSingle();
    final overdueTasks = overdueRes.read<int>('COUNT(*)');

    return {
      'totalProjects': totalProjects,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'incompleteTasks': incompleteTasks,
      'overdueTasks': overdueTasks,
    };
  }
}