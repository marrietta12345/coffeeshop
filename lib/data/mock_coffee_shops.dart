import '../models/coffee_shop.dart';
import '../models/menu_item.dart';
import '../models/review.dart';

/// Placeholder data centered on Butuan City, Philippines.
/// Replace with real data from Firestore once your `coffee_shops`
/// collection is set up.
final List<CoffeeShop> mockCoffeeShops = [
  CoffeeShop(
    id: '1',
    name: 'Brewpoint Coffee Co.',
    description:
        'Cozy specialty coffee shop known for single-origin pour-overs, '
        'a relaxed study-friendly vibe, and friendly baristas who remember '
        'your order.',
    address: 'J.C. Aquino Ave, Butuan City',
    openTime: '8 AM',
    closeTime: '10 PM',
    latitude: 8.9475,
    longitude: 125.5406,
    rating: 4.8,
    category: ShopCategory.coffee,
    photoCount: 8,
    menu: [
      MenuItem(name: 'Hazelnut Latte', description: 'Nutty flavor with creamy milk.', price: 120, likes: 24),
      MenuItem(name: 'Caramel Macchiato', description: 'Espresso, milk, and caramel drizzle.', price: 130, likes: 11),
      MenuItem(name: 'Cappuccino', description: 'Espresso with steamed milk foam.', price: 150, originalPrice: 180, likes: 31),
      MenuItem(name: 'Spanish Latte', description: 'Sweet milk and espresso blend.', price: 140, likes: 9),
      MenuItem(name: 'Americano', description: 'Smooth espresso and hot water.', price: 140, originalPrice: 160, likes: 27),
      MenuItem(name: 'Mocha', description: 'A delicious combination of espresso, chocolate, and steamed milk.', price: 140, likes: 6),
      MenuItem(name: 'Classic Latte', description: 'A smooth espresso drink blended with steamed milk for a creamy finish.', price: 140, likes: 3),
    ],
    reviews: [
      Review(
        userName: 'Sophia Reyes',
        rating: 5,
        timeAgo: '1 week ago',
        text: 'The coffee has a rich and inviting aroma that immediately '
            'captures your attention. It freshly brewed each cup tastes '
            'bold with a smooth finish.',
        likes: 12,
        photoCount: 3,
      ),
      Review(
        userName: 'Marco Villanueva',
        rating: 4.5,
        timeAgo: '3 weeks ago',
        text: 'Great coffee, friendly staff, and a relaxing ambiance. I '
            'highly recommend it for a quality cafe experience.',
        likes: 7,
      ),
    ],
  ),
  CoffeeShop(
    id: '2',
    name: 'Historya by Antigo',
    description:
        'A heritage-inspired coffee shop blending local history with '
        'modern cafe culture — great food, excellent service, and a cozy '
        'atmosphere.',
    address: 'Osmeña St, Butuan City',
    openTime: '9 AM',
    closeTime: '10 PM',
    latitude: 8.9439,
    longitude: 125.5435,
    rating: 4.8,
    category: ShopCategory.coffee,
    photoCount: 10,
    menu: [
      MenuItem(name: 'Hazelnut Latte', description: 'Nutty flavor with creamy milk.', price: 120, likes: 18),
      MenuItem(name: 'Caramel Macchiato', description: 'Espresso, milk, and caramel drizzle.', price: 130, likes: 22),
      MenuItem(name: 'Cappuccino', description: 'Espresso with steamed milk foam.', price: 150, originalPrice: 180, likes: 35),
      MenuItem(name: 'Spanish Latte', description: 'Sweet milk and espresso blend.', price: 140, likes: 14),
      MenuItem(name: 'Americano', description: 'Smooth espresso and not water.', price: 140, likes: 8),
      MenuItem(name: 'Mocha', description: 'A delicious combination of espresso, chocolate, and steamed milk.', price: 140, likes: 5),
      MenuItem(name: 'Classic Latte', description: 'A smooth espresso drink blended with steamed milk for a creamy finish.', price: 140, likes: 4),
    ],
    reviews: [
      Review(
        userName: 'Supersw',
        rating: 4,
        timeAgo: '2 days ago',
        text: 'The coffee has a rich and inviting aroma that immediately '
            'captures your attention. It freshly brewed each cup tastes '
            'bold and rich.',
        likes: 1,
        photoCount: 3,
      ),
    ],
  ),
  CoffeeShop(
    id: '3',
    name: 'The Daily Grind',
    description: 'Neighborhood coffee shop known for its house blend and fresh-baked treats.',
    address: 'A.D. Curato St, Butuan City',
    openTime: '7 AM',
    closeTime: '9 PM',
    latitude: 8.9510,
    longitude: 125.5380,
    rating: 4.3,
    category: ShopCategory.coffee,
    menu: [
      MenuItem(name: 'Cinnamon Roll Latte', description: 'Espresso with cinnamon-vanilla syrup.', price: 130, likes: 15),
      MenuItem(name: 'Iced Brown Sugar Latte', description: 'Espresso, brown sugar syrup, oat milk.', price: 135, likes: 19),
    ],
    reviews: const [],
  ),
  CoffeeShop(
    id: '4',
    name: 'Kape Kubo',
    description: 'Local roast served in a laid-back garden seating area.',
    address: 'National Hwy, Butuan City',
    openTime: '6 AM',
    closeTime: '8 PM',
    latitude: 8.9455,
    longitude: 125.5325,
    rating: 4.9,
    category: ShopCategory.coffee,
    menu: [
      MenuItem(name: 'Barako Brew', description: 'Strong local Batangas-style coffee.', price: 90, likes: 41),
    ],
    reviews: const [],
  ),
  CoffeeShop(
    id: '5',
    name: 'Sweet Steam',
    description: 'Cozy coffee bar with cold brew and light bites for the afternoon crowd.',
    address: 'Montilla Blvd, Butuan City',
    openTime: '10 AM',
    closeTime: '11 PM',
    latitude: 8.9525,
    longitude: 125.5420,
    rating: 4.2,
    category: ShopCategory.coffee,
    isOpenNow: false,
    menu: [
      MenuItem(name: 'Vanilla Cold Brew', description: 'Slow-steeped cold brew with vanilla.', price: 120, likes: 10),
    ],
    reviews: const [],
  ),
];