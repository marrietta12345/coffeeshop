class MenuItem {
  final String name;
  final String description;
  final double price;
  final double? originalPrice; // set when the item is on sale/discounted
  int likes; // mutable — grows as customers heart it
  final String? imageUrl; // real uploaded photo (Supabase Storage), if any

  MenuItem({
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    this.likes = 0,
    this.imageUrl,
  });
}