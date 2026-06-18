import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class AboutPage extends FlintComponent {
  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: 'About',
      children: [
        PageHero(
          eyebrow: 'About FARMS BENEFIT LIMITED',
          title: 'A dependable agribusiness company built around value.',
          body:
              'Learn how FARMS BENEFIT LIMITED supports food value chains through practical farming, responsible sourcing, quality produce handling, and market-focused agribusiness services.',
          primaryHref: '/services',
          primaryLabel: 'Explore Services',
        ),
        AboutSection(),
        WhyChooseUsSection(),
        ContactSection(),
      ],
    );
  }
}
