import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class GalleryPage extends FlintComponent {
  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: 'Gallery',
      children: [
        PageHero(
          eyebrow: 'Gallery',
          title: 'Snapshots of our farm, produce, and distribution focus.',
          body:
              'Browse visual highlights for crop fields, fresh harvests, livestock care, agro processing, produce supply, and food distribution.',
          primaryHref: '/products',
          primaryLabel: 'View Products',
        ),
        GallerySection(),
        ProductsSection(),
        ContactSection(),
      ],
    );
  }
}
