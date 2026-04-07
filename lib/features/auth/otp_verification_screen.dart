import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import 'package:dispatcher_1/core/theme/app_colors.dart';
import 'package:dispatcher_1/core/theme/app_text_styles.dart';
import 'package:dispatcher_1/core/theme/app_spacing.dart';
import 'package:dispatcher_1/core/widgets/primary_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, this.phone = '+7 (900) 123-45-67'});

  final String phone;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _otpLength = 6;
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  bool _hasError = false;
  int _secondsLeft = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _onCompleted(String code) {
    // Демонстрация состояния ошибки: код "000000" — неверный.
    if (code == '000000') {
      setState(() => _hasError = true);
      return;
    }
    context.go('/auth/registration');
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 54.w,
      height: 68.h,
      textStyle: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        border: Border.all(color: AppColors.primaryTint, width: 1),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.primary, width: 1.5),
        color: AppColors.surface,
      ),
    );

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: AppColors.error, width: 1.5),
        color: AppColors.surface,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.go('/auth/phone'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12.h),
              Text('Верификация', style: AppTextStyles.h1SemiBold),
              SizedBox(height: 12.h),
              Text(
                'Код был выслан по номеру\n${widget.phone}',
                style: AppTextStyles.bodyL,
              ),
              SizedBox(height: 32.h),
              Center(
                child: Pinput(
                  controller: _pinController,
                  focusNode: _pinFocusNode,
                  length: _otpLength,
                  autofocus: true,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  forceErrorState: _hasError,
                  separatorBuilder: (int _) => SizedBox(width: 4.w),
                  onChanged: (_) {
                    if (_hasError) {
                      setState(() => _hasError = false);
                    }
                  },
                  onCompleted: _onCompleted,
                ),
              ),
              if (_hasError) ...[
                SizedBox(height: 12.h),
                Center(
                  child: Text(
                    'Неверный код',
                    style: AppTextStyles.body.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              SizedBox(height: 24.h),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Отправить повторно через 0:${_secondsLeft.toString().padLeft(2, '0')}',
                        style: AppTextStyles.resendLink,
                      )
                    : GestureDetector(
                        onTap: () {
                          _pinController.clear();
                          setState(() => _hasError = false);
                          _startTimer();
                        },
                        child: Text(
                          'Не пришел код? Отправить повторно',
                          style: AppTextStyles.resendLink,
                        ),
                      ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Далее',
                enabled: _pinController.text.length == _otpLength && !_hasError,
                onPressed: () => _onCompleted(_pinController.text),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
