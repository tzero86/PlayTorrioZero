import 'package:flutter/material.dart';
import '../../../services/theme/dock_settings.dart';
import '../../../widgets/common/app_liquid_dock.dart';
import '../../../services/theme/app_theme_service.dart';

class DockSettingsPage extends StatefulWidget {
  const DockSettingsPage({super.key});

  @override
  State<DockSettingsPage> createState() => _DockSettingsPageState();
}

class _DockSettingsPageState extends State<DockSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liquid Dock & Navbar',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await DockSettings.resetToDefaults();
              setState(() {});
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Dock items reset to default layout.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                ),
              );
            },
            icon: const Icon(Icons.restore_rounded, size: 18, color: Colors.white70),
            label: const Text(
              'Reset',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  children: [
                    // Header Description Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF12151E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.dock_rounded,
                              color: AppThemeService.currentPalette.value.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Customize Bottom Dock',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Choose which navigation items appear in your bottom liquid glass dock across all screens. Home & Settings are essential and stay pinned.',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Section Title
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Text(
                            'NAVIGATION SHORTCUTS',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List of Item Toggles
                    ValueListenableBuilder<Map<String, bool>>(
                      valueListenable: DockSettings.enabledNotifier,
                      builder: (context, enabledMap, _) {
                        return Column(
                          children: DockItemKey.values.map((item) {
                            final isEnabled = enabledMap[item.key] ?? true;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildItemCard(
                                item: item,
                                isEnabled: isEnabled,
                                onToggle: (val) async {
                                  if (!item.isRemovable) return;
                                  await DockSettings.setItemEnabled(item.key, val);
                                  setState(() {});
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 100), // Space for preview dock
                  ],
                ),
              ),

              // Live Preview Dock Section at Bottom
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1017),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LIVE DOCK PREVIEW',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const AppLiquidDock(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard({
    required DockItemKey item,
    required bool isEnabled,
    required ValueChanged<bool> onToggle,
  }) {
    final isPinned = !item.isRemovable;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled
              ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEnabled
                  ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              color: isEnabled
                  ? AppThemeService.currentPalette.value.primaryColor
                  : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isEnabled ? Colors.white : Colors.white60,
                      ),
                    ),
                    if (isPinned) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'REQUIRED',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF34D399),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: isPinned ? true : isEnabled,
            onChanged: isPinned ? null : onToggle,
            activeColor: AppThemeService.currentPalette.value.primaryColor,
          ),
        ],
      ),
    );
  }
}
