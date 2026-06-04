import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/features/auth/presentation/create_account_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  static const _primaryGreen = Color(0xFF00E676);
  static const _titleColor = Color(0xFF030303);
  static const _subtitleColor = Color(0xFF545454);
  static const _inactiveDotColor = Color(0xFFCFCFD3);

  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _OnboardingSlide(
      imagePath: 'assets/onboarding/onboarding_1.png',
      title: 'Отслеживайте\nкаждое движение',
      subtitle: 'Записывайте пробежки, поездки и прогулки.',
    ),
    _OnboardingSlide(
      imagePath: 'assets/onboarding/onboarding_2.png',
      title: 'Присоединяйтесь\nк сообществу',
      subtitle: 'Группы, чаты и соревнования с друзьями.',
    ),
    _OnboardingSlide(
      imagePath: 'assets/onboarding/onboarding_3.png',
      title: 'Достигайте целей',
      subtitle: 'Получайте достижения и бейте рекорды.',
    ),
  ];

  TextStyle get _skipStyle => GoogleFonts.lexendDeca(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _subtitleColor,
      );

  TextStyle get _titleStyle => GoogleFonts.lexendDeca(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _titleColor,
        height: 1.2,
      );

  TextStyle get _subtitleStyle => GoogleFonts.lexendDeca(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: _subtitleColor,
        height: 1.5,
      );

  TextStyle get _buttonStyle => GoogleFonts.lexendDeca(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateAccountPage()),
      );
    }
  }

  void _onSkip() {
    Navigator.pushReplacementNamed(context, '/login_page');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _slides.length,
                itemBuilder: (context, index) => _buildSlide(_slides[index]),
              ),
            ),
            _buildPageIndicator(),
            const SizedBox(height: 24),
            _buildActionButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const StrideTrackLogo(size: 24),
          const Spacer(),
          TextButton(
            onPressed: _onSkip,
            style: TextButton.styleFrom(
              foregroundColor: _subtitleColor,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Пропустить', style: _skipStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Image.asset(
                slide.imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: _titleStyle,
          ),
          const SizedBox(height: 12),
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: _subtitleStyle,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? _primaryGreen : _inactiveDotColor,
          ),
        );
      }),
    );
  }

  Widget _buildActionButton() {
    final isLastPage = _currentPage == _slides.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isLastPage ? 'Начать' : 'Далее',
            style: _buttonStyle,
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  final String imagePath;
  final String title;
  final String subtitle;
}
