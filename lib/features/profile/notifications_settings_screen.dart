import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/profile/profile_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Экран настроек пуш-уведомлений для приложения заказчика.
///
/// У заказчика только один тумблер — мастер-выключатель «Все уведомления».
/// Тумблер «новые заказы рядом» — это исполнительская фича, у заказчика
/// нет.
class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _loading = true;
  bool _pushEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final MyPrivate? p = await ProfileService.instance.loadMyPrivate();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _pushEnabled = p?.pushEnabled ?? true;
    });
  }

  Future<void> _setMaster(bool v) async {
    setState(() => _pushEnabled = v);
    try {
      await ProfileService.instance.updatePushEnabled(v);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pushEnabled = !v);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить настройку')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Уведомления')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: <Widget>[
                SizedBox(height: 12.h),
                Container(
                  color: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Все уведомления',
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Если выключить — приложение перестанет '
                              'присылать любые пуши на это устройство',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Switch(
                        value: _pushEnabled,
                        onChanged: _setMaster,
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
