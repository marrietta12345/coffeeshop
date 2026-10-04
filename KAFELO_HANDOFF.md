# Kafelo — Session Handoff

> Read this first when continuing work on Kafelo in a new session.
> It summarizes the project, what has been built so far, how the data is
> stored, the rules to follow, and what is still open.
> Last updated: 2026-10-04.

---

## 1. Project at a glance

- **App:** Kafelo — a Flutter mobile app (thesis project) for discovering
  local coffee shops around **Butuan City, Philippines**.
- **Repo:** cloned from `https://github.com/marrietta12345/coffeeshop.git`
  into `C:\Users\Alexa\THESIS MOBILE APPLICATION`.
- **Git state:** only the original `first commit` exists. **All work from
  this session is uncommitted** (~75 changed/new files). Commit it before
  making big changes so it can be rolled back.
- **Two account types:**
  - **Coffee Explorer** (customer) — map, Explore, Profile tabs.
  - **Coffee Shop Owner** — Dashboard, Menu*, Best Sellers*, Reviews*,
    Profile tabs (*still "coming soon" placeholders).
- **Run:** `flutter run` (Android emulator `Medium_Phone_API_37` is used).
  After big changes, **fully restart** the app (hot reload is not enough).

### Tech stack
| Area | Used for |
|---|---|
| Firebase Auth | Email/password sign-in for both roles |
| Cloud Firestore | Users, shops, reviews, collections, all app data |
| Supabase Storage (bucket `shop-images`) | Images only: shop gallery/logos/banners, avatars, review photos |
| flutter_map + OpenStreetMap tiles | Map (Google Maps was tried and **fully removed** at the user's request) |
| geolocator / geocoding | GPS location, address lookup |
| image_picker | Gallery photo picking |
| url_launcher | Directions, call, website/social links |

Firebase project id: `kafelo-mobile-application`.

---

## 2. Working rules / user preferences (follow these)

1. **Keep the existing Kafelo UI unchanged** — layout, colors, fonts,
   navigation, styling. Only add/fix what is asked. Brand color is
   `AppColors.primaryBrown` (#A67C5B); dark bg `#1C1C1C`; light inputs
   `AppColors.inputFill`.
2. **No mock / sample / hardcoded café data.** All cafés come from Firestore
   (`shops`). The old demo data file was deleted. No placeholder stock
   photos (picsum was removed). No hardcoded operating hours.
3. Design tone: clean, modern, fun, appealing to Gen Z & millennials, but
   simple — avoid unnecessary buttons/features.
4. Philippine conventions: phone `+639XXXXXXXXX`, time zone **Asia/Manila
   (UTC+8)**, currency ₱.
5. When unsure what the user means, ask (they sometimes send short
   instructions, e.g. "remove X", then change their mind — Coffee
   Preferences was removed and restored).
6. The user tests on an Android emulator and sends screenshots; they
   expect alignment/spacing to look polished.
7. Verify changes: `flutter analyze` (no errors/warnings) and the test
   suite (see §8). Widget tests can't render screens that touch Firebase on
   load (e.g. `ShopDetailPage`).

---

## 3. Firestore data model (current)

### `users/{uid}` (private — owner of the doc only)
- `role`: `'customer' | 'owner'` (set at sign-up, **cannot be changed** — enforced by rules)
- `fullName`, `email`, `phoneNumber`, `username`, `photoUrl`, `createdAt`
- Owner sign-up also stores: `shopName`, `locationType`, `mallName`,
  `mallFloor`, `mallLandmark`, `address`, `latitude`, `longitude`
- `notificationSettings`: `{nearbyRecommendations, favoriteUpdates, newDiscoveries, general}` (bools)
- `coffeePreferences`: `{coffeeTypes[], atmospheres[], studyFriendly, outdoorSeating, wifi, petFriendly}`
- Visited Cafés / discovery:
  - `visitedShops.{shopId}`: `{shopName, address, visitedAt, visitCount}` (history; user can remove entries)
  - `discoveredCafes.{shopId}`: `{shopName, discoveredAt}` (permanent; never decreases)
  - legacy `cafePassport.{shopId}` (old name, still read)
  - `totalVisits` (permanent counter)
- Subcollections:
  - `savedShops/{shopId}` — Favorites (heart)
  - `collections/{id}` — see §5.4

### `shops/{shopId}` (public read)
- `ownerId`, `name`, `description`, `createdAt`
- Location: `locationType` (`'mall' | 'standalone'`), `address`, `latitude`,
  `longitude`, `mallName`, `mallFloor`, `mallLandmark`
- Contact/online: `phoneNumber` (+639…), `website`, `facebookUrl`,
  `instagramUrl`, `tiktokUrl`
- Hours: `operatingHours` = `{mon: {open:'08:00', close:'21:00'}, …}`
  (missing day = closed; close < open = past midnight; open == close = 24h),
  `temporarilyClosed` (bool), `closureNote`
- Features (for recommendations/search): `coffeeTypes[]`, `atmospheres[]`,
  `amenities[]` (keys `studyFriendly|outdoorSeating|wifi|petFriendly`)
- Images: `logoUrl`, `bannerUrl`, `photoUrls[]`, `photoCount`
- Stats: `rating` (avg), `ratingSum`, `reviewCount`, `viewCount`, `favoritesCount`
- Legacy (no longer used for display): `openTime`, `closeTime`, `isOpenNow`

### `shops/{shopId}/reviews/{uid}` (one review per user per shop)
- `shopId`, `userId`, `userName`, `rating` (1–5), `text`, `photoUrl` (optional),
  `likes`, `createdAt`
- Posting/editing runs in a transaction that also updates the shop's
  `rating`, `ratingSum`, `reviewCount`.

### Security rules
- Full rules live in **`firestore.rules`** (repo root; also referenced in
  `firebase.json`). They were **published** in the Firebase console.
- Key points: users private; role immutable; shops public-read, owners edit
  their own but can't edit stats/ownerId; any signed-in user can only
  `viewCount +1`, `favoritesCount ±1`, and rating totals that exactly match
  their own review in the same transaction; reviews: author-only write,
  validated fields, no delete.
- If a new field/collection is added, check it against these rules.

### Supabase
- Bucket `shop-images`, folders: `gallery/`, `logos/`, `banners/`,
  `best-sellers/`, `avatars/`, `reviews/`.
- Known limitation: storage writes are not tied to Firebase auth (anyone
  with the anon key can upload) — acceptable for thesis, mention as limitation.

---

## 4. App structure (key files)

```
lib/
  main.dart                      Firebase + Supabase init, routes
  models/
    coffee_shop.dart             CoffeeShop (+ locationLabel, mallDetails, isInMall, hours)
    operating_hours.dart         Weekly schedule + Open/Closed logic (Manila time)
    review.dart                  Review (+ formatTimeAgo)
    shop_collection.dart         CollectionCategory (8 built-ins), CollectionIconOption, ShopCollection
    coffee_preferences.dart      Coffee Preferences model + option lists
    cafe_journey.dart            VisitedShop, CafeDiscovery, CafeJourney (streak, daily discovery)
    notification_settings.dart
  utils/
    cafe_search.dart             Explore search + autocomplete logic
    recommendations.dart         "Recommended for You" ranking
    collections_service.dart     Collections CRUD (built-in + custom)
    review_service.dart          Reviews + rating transaction
    visited_shops_service.dart   Visited Cafés / discoveries
    form_validators.dart         Required, email, PH mobile (+ PhMobileInputFormatter), password
    online_links.dart            Website/FB/IG/TikTok validation + link list
    shop_lookup.dart             resolveShop / fetchAllShops (Firestore only)
    user_profile_service.dart, saved_shops_service.dart, shop_stats_service.dart,
    supabase_image_service.dart, location_service.dart, owner_shop_service.dart
  widgets/
    settings_widgets.dart        SettingsPageScaffold, ProfileMenuTile, SettingsSwitchTile,
                                 ShopListRow, ResolvedShopRow, SettingsEmptyState
    open_status.dart             OpenStatusLine / OpenStatusBadge (auto-refresh 30s)
    schedule_editor.dart         Owner weekly hours editor
    online_action_button.dart    Adaptive "Online" button + menu
    shop_photo.dart              ShopPhoto, ShopCoverImage
    shop_mini_card.dart          Explore/map carousel card (status + mall badges)
    category_chip.dart, auth_text_field.dart (isRequired *, inputFormatters), ...
  pages/  (customer)
    home_page.dart               Map (OSM), search autocomplete → fly to café, highlighted pin
    explore_page.dart            Search+suggestions, Recommended for You, Popular (≥4.0), All Cafés, Best Sellers
    shop_list_page.dart          "View all" list (ShopListCard)
    shop_detail_page.dart        Café details (header status, mall line, actions, tabs, reviews)
    add_review_page.dart         Write/edit review + optional photo
    you_page.dart                Profile tab
    account_settings_page.dart   Personal Info, Notifications, Location, Visited Cafés, My Collections, Coffee Preferences
    personal_info_page.dart, notification_settings_page.dart, location_settings_page.dart,
    visited_cafes_page.dart, coffee_preferences_page.dart, saved_shops_page.dart
    collections_page.dart, collection_detail_page.dart, create_collection_page.dart,
    save_to_collection_sheet.dart
  pages/  (owner)
    business_sign_up_page.dart   Owner sign-up (validation, location type, GPS, hours, online presence)
    owner_edit_profile_page.dart Edit profile (phone, online presence, location/mall, café features)
    owner_hours_page.dart        Weekly hours + temporary closure
    owner_shop_profile_page.dart, owner_dashboard_page.dart, owner_gallery_page.dart, ...
firestore.rules                  Published Firestore security rules
```

---

## 5. Features built this session (in order)

### 5.1 Account Settings (customer)
Personal Information (photo → Supabase `avatars/`, name, username, email
change via re-auth + verify email), Notifications (4 toggles, saved only —
no push yet), Location (permission status, open settings), Visited Cafés,
My Collections, Coffee Preferences.

### 5.2 Visited Cafés + Daily Discovery (simplified version is current)
- Opening a café's details records a visit (= "visited"; no GPS check).
- Visited Cafés page: total discovered (permanent), visits, % explored,
  **Daily Discovery** (goal: 1 new café/day, resets at midnight),
  **streak** (consecutive days with a new café), "Today's pick" (nearest
  undiscovered café), history with remove (count never drops).
- A larger "Café Journey / Café Passport / levels" version was built then
  **removed** at the user's request.

### 5.3 Map (home_page)
- OpenStreetMap via flutter_map. Search with autocomplete → animates map to
  café, highlighted pulsing pin, preview card with "View Details".

### 5.4 Collections
- **8 built-in categories** (only shown once created/used): Want to Visit
  (pin), Best Study Spots (book), Cozy Cafés (sofa), Work & Productivity
  (laptop), Best for Hangouts (people), Hidden Gems (gem), Instagrammable
  Spots (camera), Late-Night Cafés (moon). Doc id = category id.
- **Custom collections**: user name + icon (27 icons), unlimited,
  edit/delete. Doc has `name, icon, shopIds, custom, createdAt`.
- My Collections shows only collections the user created/saved to; empty
  state with "Create Collection". Create Collection is a **full screen with
  a back button** (`create_collection_page.dart`).
- Café cards in collections show cover image (banner → photo → logo →
  placeholder), name, location, rating.
- Bookmark button on café page → "Save to collection" sheet.
- "My Favorites" is NOT a collection (Favorites = separate heart feature).

### 5.5 Reviews
- Reviews saved per shop; optional photo (Supabase `reviews/`); one per
  user per shop (re-posting edits it); live list; average rating updates.
- Owner "Reviews" tab is still "coming soon".

### 5.6 Explore page
- **Search bar**: live autocomplete over real cafés — names (partial, accent
  insensitive), locations/malls, coffee types, atmospheres, features (only
  suggested if a café has it). Results replace sections; "Clear" returns.
- **Recommended for You**: ranks cafés by matches with the user's Coffee
  Preferences (needs owners to fill Café Features). No prefs → prompt.
- **Popular Coffee Shops**: rating ≥ 4.0, "View all" works.
- **All Cafés**: every café, nearest first, "View all".
- Best Sellers: empty until owners can add menus; its "View all" is not wired.

### 5.7 Mall-located cafés
- Display "Inside {mall}" (+ "Floor · Landmark"); standalone cafés show
  their address unchanged. Badge on Explore cards; header line on café page.

### 5.8 Owner sign-up form
- Required fields marked `*`, "This field is required." errors.
- Phone: `+639` prefix locked, digits only, 12 digits after `+`
  ("Please enter a valid Philippine mobile number.").
- Email placeholder `example@gmail.com`, format validation.
- **Location Type**: Standalone (Café Address*) or Inside a Mall (Mall
  Name*, Floor Level*, Landmark optional) + **Café GPS Location*** (Use
  Current Location / Pick on Map). Can't submit without GPS.
- Optional **Operating Hours** and **Online Presence** sections.

### 5.9 Owner Edit Profile
- Shows the sign-up phone (falls back to `users/{uid}.phoneNumber` and
  copies it to the shop), PH phone validation, Online Presence, Location
  (mall fields), Café Features (coffee types, atmosphere, must-haves).

### 5.10 Online Presence
- Optional Website / Facebook / Instagram / TikTok with URL validation
  (social links must match their platform; https:// added automatically).
- Café page: single adaptive **Online** button (one link → that platform;
  several → "Online" menu; none → hidden).

### 5.11 Automatic Open/Closed status (latest feature)
- Owner sets per-day hours (Hours page + optional at sign-up) and an
  optional Temporarily Closed + note. No manual switch.
- Customer sees: ● Open Now · Closes at 9:00 PM / ● Closed Now · Opens
  tomorrow at 8:00 AM / Temporarily Closed / Hours unavailable.
  Manila time, past-midnight, 24h, auto-refresh every 30s.
- Shown on café header, About tab (weekly list), Explore cards, list
  cards, map preview/list, owner profile.
- **Existing cafés show "Hours unavailable" until the owner sets hours.**

### 5.12 UI polish done
- Owner forms: equal-width Location Type tiles, equal GPS buttons, icon
  labels for Online Presence, consistent section spacing (28 above heading /
  16 below description), aligned Description field.
- Café detail header: equal-width action buttons, fixed (non-scrolling)
  tabs, pin icon + aligned mall/floor lines.

### Removed / reverted
- Google Maps integration (back to OpenStreetMap).
- Mock café data, picsum placeholder photos.
- Price Range from Coffee Preferences.
- Café Journey hub / Café Passport / levels.
- "About the App" from profile; "About Us" from owner shop profile.

---

## 6. Known gaps / possible next steps

- Commit the work to git (nothing committed since the original clone).
- Owner **Menu / Best Sellers / Reviews** tabs are still placeholders;
  menus can't be added yet (so Best Sellers is empty, and menu-based
  matching in search/recommendations has no data).
- Owner Reviews tab could list real reviews now that they're stored.
- Coffee Explorer sign-up form doesn't yet use the new validators (owner form does).
- Notifications toggles are saved but no push notifications exist.
- "Visited" = opening café details (optional idea: GPS-verified visits).
- Explore filter (tune) icon does nothing; Best Sellers "View all" not wired.
- Supabase storage isn't secured per owner.
- The default `test/widget_test.dart` is the stale Flutter counter test
  and always fails — can be deleted/replaced.
- Old Firestore test data may reference deleted demo café ids `1`–`5`.

---

## 7. Gotchas learned

- Always fully restart the app after changes (several "it doesn't work"
  reports were stale builds).
- Firestore `set(..., merge: true)` deep-merges maps — use `update()` to
  replace a whole map (e.g. `operatingHours`) so removed keys disappear.
- Pending server timestamps read as `null` right after a write — code
  treats them as "now".
- `ShopDetailPage` header uses a fixed `preferredSize` (460, or 504 for mall
  cafés); adding lines there requires adjusting it.
- Test font has no emoji; prefer Material icons in UI labels.
- Windows paths have spaces — quote them in shell commands.

---

## 8. Verify / test

```bash
flutter analyze --no-pub
flutter test test/operating_hours_test.dart test/schedule_widgets_test.dart test/online_presence_test.dart test/owner_edit_profile_phone_test.dart test/business_sign_up_validation_test.dart test/form_validators_test.dart test/cafe_search_test.dart test/recommendations_test.dart test/create_collection_page_test.dart test/collection_categories_test.dart test/review_test.dart test/mall_location_test.dart test/cafe_journey_test.dart
```
Expected: no analyzer errors/warnings (only existing `info` lints such as
`withOpacity` deprecation) and **115 tests passing**.
