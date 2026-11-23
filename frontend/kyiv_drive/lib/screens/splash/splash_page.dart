import 'package:flutter/material.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../services/home_map_startup.dart';
import '../../widgets/app_brand_header.dart';

class SplashPage extends StatefulWidget {
  final bool prepareHomeMap;

  const SplashPage({super.key, this.prepareHomeMap = true});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    if (widget.prepareHomeMap) HomeMapStartup.prepare();
  }

  @override
  void dispose() {
    if (widget.prepareHomeMap) HomeMapStartup.discard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppDimens.authPagePadding,
            ),
            child: AppBrandHeader(),
          ),
        ),
      ),
    );
  }
}
