import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/primary_button.dart';

class _OnbStep {
  const _OnbStep({
    required this.image,
    required this.title,
    required this.description,
  });

  final String image;
  final String title;
  final String description;
}

const List<_OnbStep> _steps = <_OnbStep>[
  _OnbStep(
    image: 'assets/images/onboarding/onb_1.webp',
    title: 'Откликайтесь на заказы',
    description:
        'Предлагайте свои услуги и получайте предложения от заказчиков',
  ),
  _OnbStep(
    image: 'assets/images/onboarding/onb_2.webp',
    title: 'Находите заказы рядом',
    description: 'Выбирайте подходящие заявки\nпод свою технику',
  ),
  _OnbStep(
    image: 'assets/images/onboarding/onb_3.webp',
    title: 'Работайте напрямую',
    description:
        'Получайте контакты заказчика\nи договаривайтесь без посредников',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_index < _steps.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      context.go('/auth/phone');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _OnbPage(step: _steps[i]),
              ),
            ),
            SizedBox(height: 8.h),
            SmoothPageIndicator(
              controller: _controller,
              count: _steps.length,
              effect: ExpandingDotsEffect(
                dotHeight: 8.h,
                dotWidth: 8.w,
                spacing: 8.w,
                expansionFactor: 3,
                activeDotColor: AppColors.primary,
                dotColor: AppColors.divider,
              ),
            ),
            SizedBox(height: 24.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: PrimaryButton(
                label: 'Далее',
                onPressed: _onNext,
              ),
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

class _OnbPage extends StatelessWidget {
  const _OnbPage({required this.step});

  final _OnbStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Image.asset(
            step.image,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                Container(
              color: AppColors.surfaceVariant,
              alignment: Alignment.center,
              child: Icon(Icons.image_outlined,
                  size: 80, color: AppColors.textTertiary),
            ),
          ),
        ),
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                step.title,
                style: AppTextStyles.h2,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                step.description,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
