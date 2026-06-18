class NavItem {
  const NavItem(this.label, this.href, this.component);

  final String label;
  final String href;
  final String component;
}

class CardInfo {
  const CardInfo(this.title, this.body);

  final String title;
  final String body;
}

class GalleryInfo {
  const GalleryInfo(this.title, this.color);

  final String title;
  final String color;
}

const navItems = [
  NavItem('Home', '/', 'Home'),
  NavItem('About Us', '/about-us', 'About'),
  NavItem('Services', '/services', 'Services'),
  NavItem('Products', '/products', 'Products'),
  NavItem('Why Choose Us', '/why-choose-us', 'WhyChooseUs'),
  NavItem('Gallery', '/gallery', 'Gallery'),
  NavItem('Contact Us', '/contact-us', 'Contact'),
];

const services = [
  CardInfo(
    'Crop Farming',
    'Cultivation support and farm operations for reliable seasonal and year-round crop production.',
  ),
  CardInfo(
    'Livestock Farming',
    'Animal farming services focused on care, productivity, and dependable product availability.',
  ),
  CardInfo(
    'Farm Produce Supply',
    'Structured sourcing and supply of quality produce for homes, retailers, and businesses.',
  ),
  CardInfo(
    'Agro Processing',
    'Value-added processing that improves shelf life, packaging, and market readiness.',
  ),
  CardInfo(
    'Farm Consultation',
    'Practical guidance for farm setup, operations, planning, and productivity improvement.',
  ),
  CardInfo(
    'Agricultural Investment Support',
    'Agribusiness insight and operational support for agriculture-focused investment decisions.',
  ),
  CardInfo(
    'Food Distribution',
    'Reliable distribution channels that move farm products closer to the communities that need them.',
  ),
];

const products = [
  CardInfo(
    'Fresh Vegetables',
    'Clean, fresh vegetable selections for daily consumption and business supply.',
  ),
  CardInfo(
    'Grains',
    'Quality grain produce for households, vendors, processors, and institutional buyers.',
  ),
  CardInfo(
    'Livestock Products',
    'Dependable livestock-based products sourced and supplied with care.',
  ),
  CardInfo(
    'Processed Agro Products',
    'Agro products prepared for better handling, storage, and market use.',
  ),
  CardInfo(
    'Seasonal Farm Produce',
    'Fresh seasonal produce supplied according to market availability and demand.',
  ),
];

const galleryItems = [
  GalleryInfo('Crop Fields', '#1f7a3d'),
  GalleryInfo('Fresh Harvest', '#6ea33a'),
  GalleryInfo('Livestock Care', '#c79b2b'),
  GalleryInfo('Agro Processing', '#0f4b2a'),
  GalleryInfo('Produce Supply', '#8aa879'),
  GalleryInfo('Food Distribution', '#8b6b3f'),
];
