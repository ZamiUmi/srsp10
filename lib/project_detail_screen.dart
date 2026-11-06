import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/app_database.dart';
import 'providers/app_providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем задачи только для этого проекта с помощью нашего нового метода
    final projectTasksAsync = ref.watch(tasksForProjectStreamProvider(project.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Проект: ${project.name}'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация о проекте
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(project.description ?? 'Нет описания'),
                    const SizedBox(height: 8),
                    Text('Статус: ${project.status}', style: const TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Задачи этого проекта:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Список задач проекта
            Expanded(
              child: projectTasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return const Center(child: Text('В этом проекте пока нет задач'));
                  }
                  return ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.task_alt, color: Colors.green),
                          title: Text(task.title),
                          subtitle: Text('Статус: ${task.status} | Приоритет: ${task.priority}'),
                          trailing: DropdownButton<String>(
                            value: task.status,
                            items: const [
                              DropdownMenuItem(value: 'todo', child: Text('Todo')),
                              DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                              DropdownMenuItem(value: 'done', child: Text('Done')),
                            ],
                            onChanged: (newStatus) {
                              if (newStatus != null) {
                                ref.read(appRepositoryProvider).updateTaskStatusSimple(task.id, newStatus);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Ошибка: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}