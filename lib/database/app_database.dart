import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'app_database.g.dart';

// 1. Таблица пользователей
class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get email => text().unique()(); // Email должен быть уникальным
  DateTimeColumn get createdAt => dateTime()();
}

// 2. Таблица проектов
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text()(); // активный, завершённый, архивный
}

// 3. Таблица участников проектов (Many-to-Many связка + роли)
class ProjectMembers extends Table {
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // Owner, Admin, Member

  @override
  Set<Column> get primaryKey => {projectId, userId}; // Составной первичный ключ
}

// 4. Таблица задач (включая Soft Delete поле deletedAt)
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get projectId => integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  IntColumn get assigneeId => integer().nullable().references(Users, #id, onDelete: KeyAction.setNull)();
  TextColumn get priority => text()(); // low, medium, high, critical
  TextColumn get status => text()(); // todo, inProgress, done, cancelled
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()(); // Для корзины задач (Soft Delete)
}

// 5. Таблица комментариев
// 5. Таблица комментариев
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get commentText => text()(); // Заменили 'text' на 'commentText'
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get authorId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();
}

// 6. Таблица вложений (пути к файлам)
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();
}

// 7. Таблица истории изменений задач
class TaskHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId => integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get previousStatus => text().nullable()();
  TextColumn get newStatus => text()();
  IntColumn get userId => integer().references(Users, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();
}

// Основной класс базы данных
@DriftDatabase(tables: [
  Users,
  Projects,
  ProjectMembers,
  Tasks,
  Comments,
  Attachments,
  TaskHistory,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

// Функция открытия соединения с SQLite
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'taskflow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}