import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/disaster_provider.dart';

// ── Data Models ────────────────────────────────────────────────────────────────

enum _Sender { user, bot }

class _ChatMessage {
  final String text;
  final _Sender sender;
  final DateTime timestamp;
  final String? llmProvider;
  final String? language;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.sender,
    DateTime? timestamp,
    this.llmProvider,
    this.language,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Quick suggestion chips ─────────────────────────────────────────────────────
const _kSuggestions = [
  '🌊 Flood risk in Karachi?',
  '🌡️ Heatwave alert for Lahore?',
  '🏔️ Earthquake danger in Peshawar?',
  'سیلاب کا خطرہ کیا ہے؟',
  'Karachi mein mosam kaisa hai?',
];

// ── Screen ─────────────────────────────────────────────────────────────────────

class AdvisorChatScreen extends StatefulWidget {
  /// City passed from the Home screen (user's nearest city).
  final String? initialCity;

  const AdvisorChatScreen({super.key, this.initialCity});

  @override
  State<AdvisorChatScreen> createState() => _AdvisorChatScreenState();
}

class _AdvisorChatScreenState extends State<AdvisorChatScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _dotAnimController;

  /// Active city context — starts as the user's location city,
  /// then updates to whatever city the backend resolves from the conversation.
  String? _activeCity;

  @override
  void initState() {
    super.initState();
    _activeCity = widget.initialCity;
    _dotAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    final cityPart = _activeCity != null
        ? 'I\'m already tuned to **$_activeCity** based on your location.'
        : 'Tell me your city or I\'ll detect it from your question.';

    _messages.add(_ChatMessage(
      sender: _Sender.bot,
      text:
          "Hello! I'm **DisasterSense AI** 🤖\n\n"
          "I'm your multilingual weather & disaster risk advisor for Pakistan. "
          "$cityPart\n\n"
          "Ask me anything in **English**, **Roman Urdu**, or **اردو**.",
    ));
  }

  @override
  void dispose() {
    _dotAnimController.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── API call ─────────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    _inputController.clear();
    setState(() {
      _messages.add(_ChatMessage(sender: _Sender.user, text: trimmed));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      // Always pass the active city as a default context.
      // The backend's _resolve_city() will override it if the user mentions
      // a different city explicitly in the message.
      final body = json.encode({
        'message': trimmed,
        if (_activeCity != null) 'city': _activeCity,
      });

      final response = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        // Backend wraps metadata under the 'metadata' key
        final meta = data['metadata'] as Map<String, dynamic>? ?? {};
        final resolvedCity = meta['city_resolved'] as String?;
        final llmTier = meta['llm_tier'] as String?;
        final detectedLang = meta['detected_language'] as String?;

        // Update the active city if the backend resolved a different one
        if (resolvedCity != null && resolvedCity != _activeCity) {
          setState(() => _activeCity = resolvedCity);
        }

        setState(() {
          _isTyping = false;
          _messages.add(_ChatMessage(
            sender: _Sender.bot,
            text: data['response'] as String? ?? 'No response received.',
            llmProvider: llmTier,
            language: detectedLang,
          ));
        });
      } else {
        final err = json.decode(response.body);
        _addError(err['detail']?.toString() ?? 'Server error ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _addError('Could not reach the advisor. Check your connection.');
    }

    _scrollToBottom();
  }

  void _addError(String msg) {
    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(sender: _Sender.bot, text: msg, isError: true));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FB),
      appBar: _buildAppBar(context, cs, isDark),
      body: Column(
        children: [
          // Location context banner
          if (_activeCity != null)
            _LocationBanner(city: _activeCity!, cs: cs, isDark: isDark),
          Expanded(
            child: _messages.length == 1
                ? _WelcomePlaceholder(
                    cs: cs,
                    city: _activeCity,
                    onSuggestionTap: _sendMessage,
                  )
                : _MessageList(
                    messages: _messages,
                    scrollController: _scrollController,
                    isTyping: _isTyping,
                    dotAnimController: _dotAnimController,
                    cs: cs,
                    isDark: isDark,
                    onSuggestionTap: _sendMessage,
                  ),
          ),
          _InputBar(
            controller: _inputController,
            focusNode: _focusNode,
            isTyping: _isTyping,
            cs: cs,
            isDark: isDark,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, ColorScheme cs, bool isDark) {
    return AppBar(
      backgroundColor:
          isDark ? const Color(0xFF1A1A24) : cs.primary.withValues(alpha: 0.06),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DisasterSense AI',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Online · Multilingual',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.75),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_outlined),
          tooltip: 'Clear chat',
          onPressed: () {
            setState(() {
              _messages.clear();
              _activeCity = widget.initialCity; // reset to original location
              _messages.add(_ChatMessage(
                sender: _Sender.bot,
                text: "Chat cleared. Ask me anything about disaster risks in Pakistan!",
              ));
            });
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Location context banner ────────────────────────────────────────────────────────

class _LocationBanner extends StatelessWidget {
  final String city;
  final ColorScheme cs;
  final bool isDark;

  const _LocationBanner(
      {required this.city, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.45),
        border: Border(
          bottom: BorderSide(
              color: cs.primary.withValues(alpha: 0.12), width: 1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location_rounded,
              size: 13, color: cs.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            'Answering for: ',
            style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
          Text(
            city,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '· mention another city to switch',
            style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

// ── Welcome placeholder (shown before first user message) ─────────────────────

class _WelcomePlaceholder extends StatelessWidget {
  final ColorScheme cs;
  final String? city;
  final ValueChanged<String> onSuggestionTap;

  const _WelcomePlaceholder(
      {required this.cs, this.city, required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          // Hero icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.15),
                  cs.tertiary.withValues(alpha: 0.15),
                ],
              ),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Icon(Icons.smart_toy_rounded,
                size: 50, color: cs.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Ask me anything',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            city != null
                ? 'Tuned to $city · Weather, floods, earthquakes & more\nEnglish · Roman Urdu · اردو'
                : 'Disaster risks · Weather · Safety tips\nin English, Roman Urdu, or اردو',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          Text(
            'Try asking…',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _kSuggestions
                .map((s) => _SuggestionChip(text: s, cs: cs, onTap: onSuggestionTap))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Message list ───────────────────────────────────────────────────────────────


class _MessageList extends StatelessWidget {
  final List<_ChatMessage> messages;
  final ScrollController scrollController;
  final bool isTyping;
  final AnimationController dotAnimController;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<String> onSuggestionTap;

  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.isTyping,
    required this.dotAnimController,
    required this.cs,
    required this.isDark,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length + (isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _TypingBubble(
              dotAnimController: dotAnimController, cs: cs, isDark: isDark);
        }
        final msg = messages[index];
        final isUser = msg.sender == _Sender.user;

        // Show suggestions after the first bot greeting
        final showSuggestions = !isUser && index == 0 && messages.length == 1;

        return Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _MessageBubble(msg: msg, cs: cs, isDark: isDark),
            if (showSuggestions) ...[
              const SizedBox(height: 12),
              _SuggestionsRow(cs: cs, onTap: onSuggestionTap),
            ],
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

// ── Individual message bubble ──────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage msg;
  final ColorScheme cs;
  final bool isDark;

  const _MessageBubble(
      {required this.msg, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.sender == _Sender.user;
    final theme = Theme.of(context);

    final userBg = LinearGradient(
      colors: [cs.primary, cs.tertiary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final botBg = isDark
        ? const Color(0xFF1E1E2C)
        : cs.surfaceContainerHighest.withValues(alpha: 0.8);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: msg.text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1)),
            );
          },
          child: Container(
            margin: EdgeInsets.only(
              top: 4,
              bottom: 2,
              left: isUser ? 48 : 0,
              right: isUser ? 0 : 48,
            ),
            decoration: BoxDecoration(
              gradient: isUser ? userBg : null,
              color: isUser ? null : (msg.isError ? cs.errorContainer : botBg),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isUser ? cs.primary : Colors.black)
                      .withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RichText(
                  text: msg.text,
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? cs.onErrorContainer
                          : theme.textTheme.bodyMedium!.color!,
                ),
                if (!isUser && (msg.llmProvider != null || msg.language != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.llmProvider != null) ...[
                          Icon(Icons.auto_awesome,
                              size: 11, color: cs.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 3),
                          Text(
                            msg.llmProvider!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.primary.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (msg.llmProvider != null && msg.language != null)
                          const SizedBox(width: 8),
                        if (msg.language != null) ...[
                          Icon(Icons.translate,
                              size: 11,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(width: 3),
                          Text(
                            msg.language!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Simple bold markdown renderer ──────────────────────────────────────────────

class _RichText extends StatelessWidget {
  final String text;
  final Color color;

  const _RichText({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        children: spans,
        style: TextStyle(color: color, fontSize: 14.5, height: 1.5),
      ),
    );
  }
}

// ── Typing indicator ───────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  final AnimationController dotAnimController;
  final ColorScheme cs;
  final bool isDark;

  const _TypingBubble(
      {required this.dotAnimController, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E2C) : cs.surfaceContainerHighest;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 2, right: 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) => _Dot(controller: dotAnimController, index: i, cs: cs)),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final ColorScheme cs;

  const _Dot({required this.controller, required this.index, required this.cs});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = (controller.value - index * 0.15).clamp(0.0, 1.0);
        final scale = 0.6 + 0.4 * (1 - (2 * t - 1).abs());
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Suggestion chips row (shown inline after first bot msg) ────────────────────

class _SuggestionsRow extends StatelessWidget {
  final ColorScheme cs;
  final ValueChanged<String> onTap;

  const _SuggestionsRow({required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 4),
        itemCount: _kSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) =>
            _SuggestionChip(text: _kSuggestions[i], cs: cs, onTap: onTap),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  final ValueChanged<String> onTap;

  const _SuggestionChip(
      {required this.text, required this.cs, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      onPressed: () => onTap(text),
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.6),
      side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
      labelStyle: TextStyle(color: cs.onPrimaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isTyping;
  final ColorScheme cs;
  final bool isDark;
  final ValueChanged<String> onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isTyping,
    required this.cs,
    required this.isDark,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1A1A24) : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF252535)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: cs.primary.withValues(alpha: 0.15), width: 1),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: isTyping ? null : onSend,
                style: const TextStyle(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Ask about disaster risks…',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(cs: cs, isTyping: isTyping, onSend: () {
            onSend(controller.text);
          }),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final ColorScheme cs;
  final bool isTyping;
  final VoidCallback onSend;

  const _SendButton(
      {required this.cs, required this.isTyping, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isTyping
            ? null
            : LinearGradient(
                colors: [cs.primary, cs.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isTyping ? cs.surfaceContainerHighest : null,
        boxShadow: isTyping
            ? []
            : [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isTyping ? null : onSend,
          child: Center(
            child: isTyping
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.primary),
                  )
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
