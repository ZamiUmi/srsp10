import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedTasksAsync = ref.watch(deletedTasksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🗑️ Корзина удаленных задач'),
        backgroundColor: Colors.red.shade100,
      ),
      body: deletedTasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('Корзина пуста'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(task.title),
                  subtitle: Text('Удалено: ${task.deletedAt?.toLocal().toString().substring(0, 16) ?? ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.restore, color: Colors.green),
                    tooltip: 'Восстановить',
                    onPressed: () async {
                      // Для примера используем ID первого попавшегося пользователя (или фиксированный)
                      // Позже можно будет передавать текущего залогиненного пользователя
                      final users = ref.read(usersStreamProvider).value;
                      final userId = users != null && users.isNotEmpty ? users.first.id : 1;

                      await ref.read(appRepositoryProvider).restoreTask(task.id, userId);
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
    );
  }
}