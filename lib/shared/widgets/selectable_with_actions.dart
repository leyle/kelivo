import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/models/selection_action.dart';
import 'snackbar.dart';
import '../../l10n/app_localizations.dart';

/// Global state for tracking running actions across all SelectableWithActions instances.
/// Uses a separate overlay for compact loading mode that persists during scroll.
class _GlobalActionState {
  static _GlobalActionState? _instance;
  static _GlobalActionState get instance => _instance ??= _GlobalActionState._();
  
  _GlobalActionState._();
  
  bool isRunning = false;
  String? actionName;
  OverlayEntry? compactOverlay;
  VoidCallback? onComplete;
  
  void startAction(String name, BuildContext context) {
    isRunning = true;
    actionName = name;
  }
  
  void enterCompactMode(BuildContext context) {
    if (!isRunning || actionName == null) return;
    
    // Remove any existing compact overlay
    compactOverlay?.remove();
    
    // Create new compact overlay
    compactOverlay = OverlayEntry(
      builder: (ctx) => _GlobalCompactLoadingBar(
        actionName: actionName!,
        onHoverEnter: () {
          // When hovering back on compact overlay, do nothing special
          // It stays compact until action completes
        },
      ),
    );
    
    Overlay.of(context).insert(compactOverlay!);
  }
  
  void completeAction() {
    isRunning = false;
    actionName = null;
    compactOverlay?.remove();
    compactOverlay = null;
    onComplete?.call();
    onComplete = null;
  }
  
  void reset() {
    isRunning = false;
    actionName = null;
    compactOverlay?.remove();
    compactOverlay = null;
    onComplete = null;
  }
}

/// Global compact loading bar widget
class _GlobalCompactLoadingBar extends StatefulWidget {
  const _GlobalCompactLoadingBar({
    required this.actionName,
    required this.onHoverEnter,
  });
  
  final String actionName;
  final VoidCallback onHoverEnter;
  
  @override
  State<_GlobalCompactLoadingBar> createState() => _GlobalCompactLoadingBarState();
}

class _GlobalCompactLoadingBarState extends State<_GlobalCompactLoadingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  
  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    
    const bottomPadding = 100.0;
    final leftPadding = (screenSize.width * 0.2).clamp(200.0, 350.0);
    
    return Positioned(
      left: leftPadding,
      bottom: bottomPadding,
      child: MouseRegion(
        onEnter: (_) => widget.onHoverEnter(),
        child: TapRegion(
          onTapOutside: null,
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.05),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.15),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.8),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotationTransition(
                        turns: _spinController,
                        child: Icon(
                          LucideIcons.loader,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.actionName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapper widget that provides a floating action bar when text is selected.
/// Only active on desktop platforms (macOS, Windows, Linux).
/// 
/// The action bar appears near the selection and provides quick actions
/// configured in settings (scripts, commands) plus a built-in Copy action.
class SelectableWithActions extends StatefulWidget {
  const SelectableWithActions({
    super.key,
    required this.child,
    this.messageId,
  });

  final Widget child;
  final String? messageId;

  @override
  State<SelectableWithActions> createState() => _SelectableWithActionsState();
}

class _SelectableWithActionsState extends State<SelectableWithActions> {
  String? _selectedText;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  Timer? _hideTimer;
  Offset? _lastTapPosition;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void dispose() {
    _hideOverlay(preserveGlobalCompact: true);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _hideOverlay({bool preserveGlobalCompact = false}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // Only reset global state if not preserving compact mode
    if (!preserveGlobalCompact && !_GlobalActionState.instance.isRunning) {
      _GlobalActionState.instance.reset();
    }
  }

  void _showActionBar(Offset position) {
    // Don't show new toolbar if an action is already running
    if (_GlobalActionState.instance.isRunning) return;
    
    _hideOverlay();
    _hideTimer?.cancel();

    final settings = context.read<SettingsProvider>();
    final actions = settings.selectionActions.where((a) => a.enabled).toList();

    _overlayEntry = OverlayEntry(
      builder: (context) => _SelectionActionBar(
        position: position,
        layerLink: _layerLink,
        selectedText: _selectedText ?? '',
        actions: actions,
        onRunAction: _runAction,
        onCopy: _copyToClipboard,
        onDismiss: () => _hideOverlay(),
        onHoverChanged: _handleBarHoverChanged,
        onEnterCompactMode: () {
          // Transfer to global compact overlay
          _GlobalActionState.instance.enterCompactMode(context);
          // Remove the local overlay
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);

    // Auto-hide after 5 seconds of inactivity
    _hideTimer = Timer(const Duration(seconds: 5), () => _hideOverlay());
  }

  void _handleBarHoverChanged(bool isHovering, bool isLoading) {
    _hideTimer?.cancel();
    if (!isHovering && !isLoading) {
      // Restart timer when cursor leaves the bar (only if not loading)
      _hideTimer = Timer(const Duration(seconds: 5), () => _hideOverlay());
    }
  }

  Future<void> _runAction(SelectionAction action) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    // Cancel auto-hide timer while script runs
    _hideTimer?.cancel();
    
    // Mark action as running globally
    _GlobalActionState.instance.startAction(action.name, context);

    try {
      // Run the script with selected text as argument
      final result = await Process.run(
        action.scriptPath,
        [_selectedText!],
        runInShell: true,
      );
      
      if (result.exitCode != 0 && mounted) {
        final stderr = result.stderr.toString().trim();
        showAppSnackBar(
          context,
          message: '${action.name} error: ${stderr.isNotEmpty ? stderr : 'Exit code ${result.exitCode}'}',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Failed to run ${action.name}: $e',
          type: NotificationType.error,
        );
      }
    }
    
    // Action completed - reset global state (this removes compact overlay too)
    _GlobalActionState.instance.completeAction();
  }

  void _copyToClipboard() {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _selectedText!));
    _hideOverlay();
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      showAppSnackBar(
        context,
        message: l10n?.chatMessageWidgetCopiedToClipboard ?? 'Copied to clipboard',
        type: NotificationType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return widget.child;
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _lastTapPosition = event.position;
        },
        onPointerMove: (event) {
          // Track pointer during selection drag
          _lastTapPosition = event.position;
        },
        onPointerUp: (event) {
          // Final position when releasing mouse
          _lastTapPosition = event.position;
        },
        child: SelectionArea(
          key: ValueKey('selectable_${widget.messageId ?? hashCode}'),
          onSelectionChanged: (content) {
            _hideTimer?.cancel();
            
            if (content != null && content.plainText.trim().isNotEmpty) {
              _selectedText = content.plainText;
              // Use the last known position or screen center as fallback
              final position = _lastTapPosition ?? 
                  Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
              
              // Debounce to let selection stabilize and avoid flicker
              _hideTimer = Timer(const Duration(milliseconds: 150), () {
                if (mounted && _selectedText != null && _selectedText!.isNotEmpty) {
                  _showActionBar(position);
                }
              });
            } else {
              _selectedText = null;
              // Delay hiding to allow clicking on the action bar
              // But don't hide if an action is currently running
              _hideTimer = Timer(const Duration(milliseconds: 250), () {
                if ((_selectedText == null || _selectedText!.isEmpty) && 
                    !_GlobalActionState.instance.isRunning) {
                  _hideOverlay();
                }
              });
            }
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// The floating action bar that appears on text selection.
class _SelectionActionBar extends StatefulWidget {
  const _SelectionActionBar({
    required this.position,
    required this.layerLink,
    required this.selectedText,
    required this.actions,
    required this.onRunAction,
    required this.onCopy,
    required this.onDismiss,
    required this.onHoverChanged,
    required this.onEnterCompactMode,
  });

  final Offset position;
  final LayerLink layerLink;
  final String selectedText;
  final List<SelectionAction> actions;
  final Future<void> Function(SelectionAction) onRunAction;
  final VoidCallback onCopy;
  final VoidCallback onDismiss;
  final void Function(bool isHovering, bool isLoading) onHoverChanged;
  final VoidCallback onEnterCompactMode;

  @override
  State<_SelectionActionBar> createState() => _SelectionActionBarState();
}

class _SelectionActionBarState extends State<_SelectionActionBar> {
  String? _loadingActionId;
  bool _isHovering = false;

  bool get _isLoading => _loadingActionId != null;

  Future<void> _handleAction(SelectionAction action) async {
    if (_isLoading) return;
    
    setState(() {
      _loadingActionId = action.id;
    });
    
    try {
      await widget.onRunAction(action);
      if (mounted) {
        // Only dismiss if not hovering; if hovering, just reset to normal
        if (_isHovering) {
          // Stay visible, reset loading state so button is clickable again
          setState(() {
            _loadingActionId = null;
          });
        } else {
          // Not hovering - dismiss
          widget.onDismiss();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingActionId = null;
        });
      }
    }
  }

  void _handleHoverEnter() {
    setState(() => _isHovering = true);
    widget.onHoverChanged(true, _isLoading);
  }

  void _handleHoverExit() {
    setState(() => _isHovering = false);
    // If loading and hover exits, switch to global compact mode
    if (_isLoading) {
      widget.onEnterCompactMode();
    }
    widget.onHoverChanged(false, _isLoading);
  }

  IconData _getIconForAction(SelectionAction action) {
    switch (action.iconName) {
      case 'volume2': return LucideIcons.volume2;
      case 'languages': return LucideIcons.languages;
      case 'search': return LucideIcons.search;
      case 'sparkles': return LucideIcons.sparkles;
      case 'brain': return LucideIcons.brain;
      case 'terminal': return LucideIcons.terminal;
      case 'code': return LucideIcons.code;
      case 'fileText': return LucideIcons.fileText;
      case 'link': return LucideIcons.link;
      case 'share': return LucideIcons.share;
      case 'bookmark': return LucideIcons.bookmark;
      case 'zap': return LucideIcons.zap;
      case 'wand': return LucideIcons.wand;
      case 'bot': return LucideIcons.bot;
      case 'messageCircle': return LucideIcons.messageCircle;
      default: return LucideIcons.play;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionCount = widget.actions.length + 1; // +1 for Copy
    final barWidth = actionCount * 80.0 + 20; // Estimate width

    return Positioned(
      left: widget.position.dx - barWidth / 2,
      top: widget.position.dy - 70, // Position higher to avoid blocking text
      child: MouseRegion(
        onEnter: (_) => _handleHoverEnter(),
        onExit: (_) => _handleHoverExit(),
        child: TapRegion(
          onTapOutside: _isLoading ? null : (_) => widget.onDismiss(),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    // iOS 26-style glass: truly transparent with blur
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.05),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.15),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.8),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                      // Inner glow for depth
                      BoxShadow(
                        color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.3),
                        blurRadius: 1,
                        spreadRadius: 0,
                        offset: const Offset(0, -0.5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Configured actions
                      for (int i = 0; i < widget.actions.length; i++) ...[
                        _buildActionButton(widget.actions[i], cs),
                        _divider(cs),
                      ],
                      // Built-in Copy action
                      _ActionButton(
                        icon: LucideIcons.copy,
                        label: 'Copy',
                        onTap: widget.onCopy,
                        enabled: !_isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(SelectionAction action, ColorScheme cs) {
    final isLoading = _loadingActionId == action.id;
    
    // Determine what to show based on display mode
    final showIcon = action.displayMode != ActionDisplayMode.textOnly;
    final showLabel = action.displayMode != ActionDisplayMode.iconOnly;
    
    return _ActionButton(
      icon: isLoading ? null : _getIconForAction(action),
      isLoading: isLoading,
      label: action.name,
      onTap: () => _handleAction(action),
      enabled: !_isLoading,
      showIcon: showIcon || isLoading,
      showLabel: showLabel || isLoading,
    );
  }

  Widget _divider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant.withValues(alpha: 0.3),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.showIcon = true,
    this.showLabel = true,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final bool showIcon;
  final bool showLabel;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_ActionButton old) {
    super.didUpdateWidget(old);
    if (widget.isLoading && !old.isLoading) {
      _spinController.repeat();
    } else if (!widget.isLoading && old.isLoading) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = 
        _hovering && widget.enabled ? cs.primary : cs.onSurface.withValues(alpha: widget.enabled ? 0.8 : 0.4);
    
    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hovering = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovering = false) : null,
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovering && widget.enabled ? cs.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                RotationTransition(
                  turns: _spinController,
                  child: Icon(
                    LucideIcons.loader,
                    size: 16,
                    color: effectiveColor,
                  ),
                )
              else if (widget.showIcon && widget.icon != null)
                Icon(
                  widget.icon,
                  size: 16,
                  color: effectiveColor,
                ),
              if (widget.showIcon && widget.showLabel && (widget.icon != null || widget.isLoading))
                const SizedBox(width: 6),
              if (widget.showLabel)
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: effectiveColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
