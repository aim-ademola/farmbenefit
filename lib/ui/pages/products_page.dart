import 'package:flint_ui/flint_ui.dart';

import '../components/site_layout.dart';

class ProductsPage extends FlintComponent {
  @override
  FlintNode build() {
    return SiteFrame(
      activeComponent: 'Products',
      children: [
        PageHero(
          eyebrow: 'Products / Farm Produce',
          title: 'Fresh, seasonal, and processed agricultural products.',
          body:
              'FARMS BENEFIT LIMITED supplies fresh vegetables, grains, livestock products, processed agro products, and seasonal produce for homes, businesses, and institutions.',
          primaryHref: '/contact-us',
          primaryLabel: 'Ask About Supply',
        ),
        ProductsSection(),
        GallerySection(),
        ContactSection(),
      ],
    );
  }
}
