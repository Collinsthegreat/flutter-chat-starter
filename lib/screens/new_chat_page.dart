import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_cubit.dart';
import '../blocs/new_chat/new_chat_cubit.dart';
import '../models/app_user.dart';
import '../services/chat_repository.dart';
import '../widgets/ui_states.dart';
import 'chat_screen.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.user?.uid ?? '';
    return BlocProvider(
      create: (context) => NewChatCubit(context.read<ChatRepository>(), uid),
      child: Builder(
        builder: (context) {
          return BlocListener<NewChatCubit, NewChatState>(
            listenWhen: (previous, current) =>
                previous.conversationId != current.conversationId &&
                current.conversationId != null,
            listener: (context, state) {
              final user = state.users.firstWhere(
                (candidate) => candidate.uid != uid,
                orElse: () => const AppUser(
                  uid: '',
                  email: '',
                  displayName: 'Chat',
                  photoUrl: '',
                ),
              );
              context.read<NewChatCubit>().clearNavigation();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    conversationId: state.conversationId!,
                    conversationTitle: user.displayName,
                    avatarUrl: user.photoUrl,
                  ),
                ),
              );
            },
            child: Scaffold(
              appBar: AppBar(title: const Text('New chat')),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: context.read<NewChatCubit>().queryChanged,
                      decoration: const InputDecoration(
                        hintText: 'Search by email or display name',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: BlocBuilder<NewChatCubit, NewChatState>(
                      builder: (context, state) {
                        return switch (state.status) {
                          NewChatStatus.idle => const EmptyState(
                            icon: Icons.person_search,
                            title: 'Search for someone to message',
                          ),
                          NewChatStatus.loading || NewChatStatus.opening =>
                            const ConversationListShimmer(count: 5),
                          NewChatStatus.empty => EmptyState(
                            icon: Icons.search_off,
                            title: state.query.trim().isEmpty
                                ? 'No users found'
                                : 'No users found for "${state.query}"',
                          ),
                          NewChatStatus.error => ErrorStateView(
                            message: 'Search failed. Check connection.',
                            onRetry: () => context.read<NewChatCubit>().search(
                              state.query,
                            ),
                          ),
                          NewChatStatus.loaded => ListView.separated(
                            itemCount: state.users.length,
                            separatorBuilder: (_, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = state.users[index];
                              return _UserResultTile(user: user);
                            },
                          ),
                        };
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.photoUrl.isEmpty
            ? null
            : CachedNetworkImageProvider(user.photoUrl),
        child: user.photoUrl.isEmpty ? const Icon(Icons.person_outline) : null,
      ),
      title: Text(user.displayName),
      subtitle: Text(user.email),
      onTap: () => context.read<NewChatCubit>().openConversation(user),
    );
  }
}
