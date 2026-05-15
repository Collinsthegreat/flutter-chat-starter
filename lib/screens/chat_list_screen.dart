import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/auth/auth_cubit.dart';
import '../blocs/chat_list/chat_list_cubit.dart';
import '../models/conversation.dart';
import '../services/chat_repository.dart';
import '../widgets/ui_states.dart';
import 'chat_screen.dart';
import 'new_chat_page.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.user?.uid ?? '';
    return BlocProvider(
      create: (context) => ChatListCubit(context.read<ChatRepository>(), uid),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Chats'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthCubit>().signOut(),
            ),
          ],
        ),
        body: BlocBuilder<ChatListCubit, ChatListState>(
          builder: (context, state) {
            return switch (state.status) {
              ChatListStatus.loading => const ConversationListShimmer(),
              ChatListStatus.error => ErrorStateView(
                message: 'Failed to load conversations',
                onRetry: () => context.read<ChatListCubit>().watch(),
              ),
              ChatListStatus.loaded when state.conversations.isEmpty =>
                EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  action: FilledButton.icon(
                    onPressed: () => _openNewChat(context),
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Start a new chat'),
                  ),
                ),
              ChatListStatus.loaded => ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.conversations.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final conversation = state.conversations[index];
                  return _ConversationTile(
                    conversation: conversation,
                    currentUid: uid,
                  );
                },
              ),
            };
          },
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'New chat',
          onPressed: () => _openNewChat(context),
          child: const Icon(Icons.add_comment_outlined),
        ),
      ),
    );
  }

  void _openNewChat(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewChatPage()));
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.currentUid,
  });

  final Conversation conversation;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    final avatar = conversation.avatarFor(currentUid);
    final unread = conversation.unreadCount[currentUid] ?? 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: avatar == null || avatar.isEmpty
            ? null
            : CachedNetworkImageProvider(avatar),
        child: avatar == null || avatar.isEmpty
            ? const Icon(Icons.person_outline)
            : null,
      ),
      title: Text(
        conversation.displayNameFor(currentUid),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        conversation.lastMessage.isEmpty
            ? 'No messages yet'
            : conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastMessageTime),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (unread > 0) ...[
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 10,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                unread.toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversation.id,
              conversationTitle: conversation.displayNameFor(currentUid),
              avatarUrl: avatar,
            ),
          ),
        );
      },
    );
  }

  String _formatTime(dynamic timestamp) {
    final date = timestamp?.toDate() as DateTime?;
    if (date == null) {
      return '';
    }
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, date)) {
      return DateFormat.jm().format(date);
    }
    return DateFormat.MMMd().format(date);
  }
}
