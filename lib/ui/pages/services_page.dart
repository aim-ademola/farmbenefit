import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class ServicesPage extends FlintComponent {
  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: 'Services',
      children: [
        PageHero(
          eyebrow: 'Agribusiness Services',
          title:
              'Farm, supply, processing, consultation, and distribution services.',
          body:
              'Our services help individuals, retailers, institutions, and agricultural investors access dependable farming operations, farm produce supply, and practical agribusiness support.',
          primaryHref: '/contact-us',
          primaryLabel: 'Request Support',
        ),
        ServicesSection(),
        WhyChooseUsSection(),
        ContactSection(),
      ],
    );
  }
}
