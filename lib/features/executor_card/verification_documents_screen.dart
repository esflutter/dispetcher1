import 'package:flutter/material.dart';
import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

import 'widgets/document_upload_tile.dart';

/// Экран отправки документов на верификацию.
/// Загрузка фото / PDF: паспорт, ВУ, удостоверение на технику, СТС.
class VerificationDocumentsScreen extends StatelessWidget {
  const VerificationDocumentsScreen({super.key});

  static const _docs = <String>[
    'ФИО или название организации',
    'Паспорт (первая страница)',
    'Фото техники',
    'Документы на технику',
    'Удостоверение на право управления техникой',
    'Водительское удостоверение',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Верификация', style: AppTextStyles.titleS),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.screenH, AppSpacing.md, AppSpacing.screenH, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusL),
                ),
                child: Text(
                  'Отправьте, пожалуйста, фото документов, чтобы мы могли '
                  'подтвердить ваш профиль:\n\n'
                  '• ФИО или название организации\n'
                  '• Паспорт (первая страница)\n'
                  '• Фото техники\n'
                  '• Документы на технику\n'
                  '• Удостоверение на право управления техникой\n'
                  '• Водительское удостоверение\n\n'
                  'Можно отправить всё одним сообщением или по отдельности.',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textPrimary),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              SizedBox(height: AppSpacing.lg),
              for (final d in _docs) ...[
                DocumentUploadTile(
                  title: d,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Загрузка: $d'),
                      duration: const Duration(seconds: 2),
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
              ],
              SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Отправить на проверку',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
