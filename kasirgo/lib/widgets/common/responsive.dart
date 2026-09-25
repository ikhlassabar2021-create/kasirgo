import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';
import 'centennial_background.dart';

class AppNavItem {
  final IconData icon;
  final String label;

  const AppNavItem({required this.icon, required this.label});
}

class AppResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const AppResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = AppTheme.contentMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  final Widget body;
  final List<AppNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget? drawer;
  final Widget? brand;
  final Widget? sidebarFooter;
  final String headerTitle;
  final Widget? mobileTitle;
  final List<Widget> mobileActions;
  final bool showBottomNav;

  const AppShell({
    super.key,
    required this.body,
    required this.navItems,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.headerTitle,
    this.drawer,
    this.brand,
    this.sidebarFooter,
    this.mobileTitle,
    this.mobileActions = const [],
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isDesktop(context)) {
      return _buildDesktop(context);
    }
    return _buildMobile(context);
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CentennialBackground(
        child: Row(
          children: [
            Container(
              width: AppTheme.sidebarWidth,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceColor,
                border: Border(right: BorderSide(color: AppTheme.borderColor)),
              ),
              child: Column(
                children: [
                  if (brand != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      child: Align(alignment: Alignment.centerLeft, child: brand),
                    ),
                  const Divider(height: 1, color: AppTheme.borderColor),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (var i = 0; i < navItems.length; i++)
                          _buildNavItem(i),
                      ],
                    ),
                  ),
                  if (sidebarFooter != null) ...[
                    const Divider(height: 1, color: AppTheme.borderColor),
                    sidebarFooter!,
                  ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: AppTheme.headerHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          headerTitle,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        ...mobileActions,
                      ],
                    ),
                  ),
                  Expanded(
                    child: AppResponsiveContent(child: body),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = currentIndex == index;
    final item = navItems[index];
    return AnimatedContainer(
      duration: AppTheme.durationFast,
      curve: AppTheme.curveDefault,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: isSelected ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)) : null,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        dense: true,
        leading: Icon(
          item.icon,
          size: 20,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
        ),
        title: Text(
          item.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
          ),
        ),
        onTap: () => onIndexChanged(index),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      drawer: drawer,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: mobileTitle,
        actions: mobileActions.isEmpty ? null : mobileActions,
      ),
      body: CentennialBackground(child: body),
      bottomNavigationBar: showBottomNav ? _buildBottomNav() : null,
    );
  }

  Widget _buildBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.85),
            border: const Border(top: BorderSide(color: AppTheme.borderColor)),
          ),
          child: BottomNavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            currentIndex: currentIndex,
            selectedItemColor: AppTheme.primaryColor,
            unselectedItemColor: AppTheme.textSecondary,
            selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11),
            onTap: onIndexChanged,
            items: [
              for (final item in navItems)
                BottomNavigationBarItem(icon: Icon(item.icon), label: item.label),
            ],
          ),
        ),
      ),
    );
  }
}
