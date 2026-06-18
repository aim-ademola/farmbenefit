import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class ContactPage extends FlintComponent {
  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: 'Contact',
      children: [
        PageHero(
          eyebrow: 'Contact Us',
          title: 'Speak with FARMS BENEFIT LIMITED.',
          body:
              'Contact us for farm produce supply, crop and livestock services, agro processing, farm consultation, investment support, or food distribution.',
          primaryHref: '#contact',
          primaryLabel: 'Send a Message',
        ),
        ContactSection(),
      ],
    );
  }
}
