import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class WhyChooseUsPage extends FlintComponent {
  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: 'WhyChooseUs',
      children: [
        PageHero(
          eyebrow: 'Why Choose Us',
          title: 'Trustworthy agricultural value from farm gate to market.',
          body:
              'Choose FARMS BENEFIT LIMITED for quality standards, responsive supply coordination, sustainable thinking, and professional agribusiness communication.',
          primaryHref: '/contact-us',
          primaryLabel: 'Work With Us',
        ),
        WhyChooseUsSection(),
        AboutSection(),
        ContactSection(),
      ],
    );
  }
}
