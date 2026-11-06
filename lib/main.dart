import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';
import 'database/app_database.dart'; // <--- Добавьте эту строчку вверху файла
import 'project_detail_screen.dart';
import 'trash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: TaskFlowApp(),
    ),
  );
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Окно просмотра истории задачи
  void _showTaskHistoryDialog(BuildContext context, WidgetRef ref, Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('История: ${task.title}'),
        content: SizedBox(
          width: 350,
          height: 300, 
          child: StreamBuilder<List<TaskHistoryData>>(
            stream: ref.read(appRepositoryProvider).watchTaskHistory(task.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Ошибка: ${snapshot.error}');
              }
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return const Center(child: Text('История изменений пуста'));
              }
              return ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, size: 18, color: Colors.blue),
                    title: Text('${item.previousStatus ?? 'создание'} ➔ ${item.newStatus}'),
                    subtitle: Text('Дата: ${item.createdAt.toLocal().toString().substring(0, 16)}', style: const TextStyle(fontSize: 11)),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  // Окно панели статистики
  void _showDashboardDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Панель статистики'),
        content: FutureBuilder(
          future: ref.read(appRepositoryProvider).getStatistics(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Ошибка: ${snapshot.error}');
            }
            final stats = snapshot.data ?? {};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📁 Всего проектов: ${stats['totalProjects'] ?? 0}'),
                Text('📋 Всего задач: ${stats['totalTasks'] ?? 0}'),
                Text('✅ Завершено задач: ${stats['completedTasks'] ?? 0}'),
                Text('⏳ Незавершено задач: ${stats['incompleteTasks'] ?? 0}'),
                Text('⚠️ Просрочено задач: ${stats['overdueTasks'] ?? 0}', 
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);
    final projectsAsync = ref.watch(projectsStreamProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskFlow — Управление'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          // Кнопка Корзины
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Корзина',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrashScreen()),
              );
            },
          ),
          // Кнопка Статистики
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Статистика',
            onPressed: () => _showDashboardDialog(context, ref),
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. Секция пользователей
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Пользователи', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: usersAsync.when(
                    data: (users) {
                      if (users.isEmpty) return const Center(child: Text('Нет пользователей'));
                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.person, size: 20),
                            title: Text(user.name),
                            subtitle: Text(user.email),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Ошибка: $err')),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Пользователь'),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // 2. Секция проектов
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Проекты', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: projectsAsync.when(
                    data: (projects) {
                      if (projects.isEmpty) return const Center(child: Text('Нет проектов'));
                      return ListView.builder(
                        itemCount: projects.length,
                        itemBuilder: (context, index) {
                          final project = projects[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder, size: 20),
                            title: Text(project.name),
                            subtitle: Text('Статус: ${project.status}'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetailScreen(project: project),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Ошибка: $err')),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddProjectDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Проект'),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // 3. Секция задач
          Expanded(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Задачи', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: tasksAsync.when(
                    data: (tasks) {
                      if (tasks.isEmpty) return const Center(child: Text('Нет задач'));
                      return ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.task, size: 20),
                            title: Text(task.title),
                            subtitle: Text('Статус: ${task.status} | Приоритет: ${task.priority}'),
                            onTap: () => _showTaskHistoryDialog(context, ref, task),
                            onLongPress: () async {
                              // Мягкое удаление по долгому клику
                              final users = ref.read(usersStreamProvider).value;
                              final userId = users != null && users.isNotEmpty ? users.first.id : 1;
                              await ref.read(appRepositoryProvider).softDeleteTask(task.id, userId);
                              
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Задача перемещена в корзину')),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Ошибка: $err')),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddTaskDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Задача'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый пользователь'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Имя')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
                await ref.read(appRepositoryProvider).createUser(nameController.text, emailController.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddProjectDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый проект'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Описание')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await ref.read(appRepositoryProvider).createProject(nameController.text, descController.text, null, 'активный');
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    
    final projectsAsync = ref.read(projectsStreamProvider);
    final usersAsync = ref.read(usersStreamProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая задача'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название задачи')),
            const SizedBox(height: 8),
            const Text('Для теста: проект и пользователь берутся автоматически (первые из списков), если они есть.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final projects = projectsAsync.value;
              final users = usersAsync.value;

              if (projects != null && projects.isNotEmpty && users != null && users.isNotEmpty) {
                if (titleController.text.isNotEmpty) {
                  await ref.read(appRepositoryProvider).createTask(
                        title: titleController.text,
                        description: 'Тестовое описание',
                        projectId: projects.first.id,
                        assigneeId: users.first.id,
                        priority: 'medium',
                        status: 'todo',
                        dueDate: DateTime.now().add(const Duration(days: 3)),
                        currentUserId: users.first.id,
                      );
                  if (context.mounted) Navigator.pop(context);
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Сначала создайте хотя бы одного пользователя и проект!')),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}