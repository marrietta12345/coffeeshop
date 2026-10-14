// Kafelo café import — puts the cafés in cafes.json into Firebase as
// regular cafés (shops/{id} + their menu), so they look and work exactly
// like owner cafés in the app. Images (logo, banner, photos, coffee
// photos) are uploaded to Supabase Storage (bucket shop-images).
//
//   node import_cafes.mjs            check cafes.json, then import
//   node import_cafes.mjs --dry-run  only check cafes.json (writes nothing)
//   node import_cafes.mjs --prune    also delete Kafelo-managed cafés that
//                                    were removed from cafes.json
//   node import_cafes.mjs --assign <cafe-id> <owner-email> [--dry-run]
//                                    hand a café over to its real owner (see
//                                    README → Handing a café to its owner)
//
// Needs the Firebase service-account key (Project settings → Service
// accounts → Generate new private key) saved as
// tool/cafes/service-account.json — never commit or share it.
//
// Re-running is safe: details are updated, while ratings, reviews,
// favorites, views and coffee hearts are kept.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, basename, extname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const here = dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);
const args = new Set(argv);
const dryRun = args.has('--dry-run');
const prune = args.has('--prune');

// Same values the app and firestore.rules accept.
const COFFEE_TYPES = ['Espresso', 'Latte', 'Cappuccino', 'Americano', 'Cold Brew', 'Pour-over', 'Non-coffee'];
const ATMOSPHERES = ['Cozy', 'Quiet', 'Lively', 'Modern', 'Rustic', 'Minimalist'];
const AMENITIES = ['studyFriendly', 'outdoorSeating', 'wifi', 'petFriendly'];
const MENU_CATEGORIES = ['Espresso', 'Latte', 'Cappuccino', 'Americano', 'Cold Brew', 'Pour-over',
  'Mocha', 'Macchiato', 'Spanish Latte', 'Iced Coffee', 'Hot Coffee', 'Other Coffee'];
const DAYS = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const IMAGE_TYPES = { '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.webp': 'image/webp' };

const SUPABASE_URL = 'https://mltdmmpyjdnjxfdxsmyg.supabase.co';
const SUPABASE_BUCKET = 'shop-images';

// ----------------------------------------------------------------- checks

const slug = (s) => s.normalize('NFKD').replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

/** "Gaisano Mall - Butuan" → "gaisano-mall-butuan" (same as MallService.mallKey). */
const mallKey = (name) => name.toLowerCase().replace(/&/g, ' and ').replace(/[^a-z0-9]+/g, ' ').trim()
  .split(' ').filter(Boolean).join('-');

function validate(data) {
  const errors = [];
  const ids = new Set();
  for (const [i, cafe] of (data.cafes ?? []).entries()) {
    const where = `cafe #${i + 1} (${cafe.name ?? cafe.id ?? '?'})`;
    const err = (msg) => errors.push(`${where}: ${msg}`);
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(cafe.id ?? '')) err('id must be lowercase letters, numbers and dashes');
    if (ids.has(cafe.id)) err('id is used twice');
    ids.add(cafe.id);
    if (!cafe.name?.trim()) err('name is required');
    if (!cafe.address?.trim()) err('address is required');
    const hasLat = cafe.latitude != null, hasLng = cafe.longitude != null;
    if (hasLat !== hasLng) err('set both latitude and longitude, or neither');
    if (hasLat && (Math.abs(cafe.latitude - 8.95) > 1 || Math.abs(cafe.longitude - 125.54) > 1)) {
      err('latitude/longitude are not near Butuan City — check them');
    }
    if (cafe.mall && !cafe.mall.name?.trim()) err('mall.name is required when mall is set');
    for (const [key, list] of [['coffeeTypes', COFFEE_TYPES], ['atmospheres', ATMOSPHERES], ['amenities', AMENITIES]]) {
      for (const v of cafe[key] ?? []) if (!list.includes(v)) err(`${key}: "${v}" must be one of ${list.join(', ')}`);
    }
    for (const [day, h] of Object.entries(cafe.hours ?? {})) {
      if (!DAYS.includes(day)) err(`hours: "${day}" must be one of ${DAYS.join(', ')}`);
      const time = /^([01]\d|2[0-3]):[0-5]\d$/;
      if (!time.test(h?.open ?? '') || !time.test(h?.close ?? '')) err(`hours.${day}: use {"open": "08:00", "close": "21:00"}`);
    }
    for (const image of [cafe.logo, cafe.banner, ...(cafe.photos ?? []), ...(cafe.menu ?? []).map((m) => m.image)]) {
      if (image) checkImage(image, err);
    }
    const menuIds = new Set();
    for (const [j, item] of (cafe.menu ?? []).entries()) {
      const at = (msg) => err(`menu #${j + 1} (${item.name ?? '?'}): ${msg}`);
      const id = item.id ?? slug(item.name ?? '');
      if (menuIds.has(id)) at('two coffees have the same name/id');
      menuIds.add(id);
      if (!item.name?.trim() || item.name.trim().length > 60) at('name is required (max 60 characters)');
      if ((item.description ?? '').length > 300) at('description is max 300 characters');
      // No price yet is allowed (the app shows "No price yet"); a price must be valid.
      if (item.price != null && (typeof item.price !== 'number' || item.price <= 0 || item.price > 99999)) {
        at('price must be a number above 0, or null when it isn\'t known yet');
      }
      if (!MENU_CATEGORIES.includes(item.category)) at(`category must be one of ${MENU_CATEGORIES.join(', ')}`);
    }
  }
  return errors;
}

function checkImage(image, err) {
  if (/^https:\/\//.test(image)) return;
  const file = join(here, image);
  if (!existsSync(file)) err(`image not found: ${image} (put it in tool/cafes/images/)`);
  else if (!IMAGE_TYPES[extname(file).toLowerCase()]) err(`image must be .jpg, .png or .webp: ${image}`);
}

// ----------------------------------------------------------------- images

const supabaseKey = () => {
  const main = readFileSync(join(here, '..', '..', 'lib', 'main.dart'), 'utf8');
  const match = main.match(/anonKey:\s*'([^']+)'/);
  if (!match) throw new Error('Supabase anon key not found in lib/main.dart');
  return match[1];
};

// Which version of each image is already uploaded (storage path → file
// hash), so re-imports skip unchanged images. Local only (git-ignored).
const uploadCacheFile = join(here, '.upload-cache.json');
let uploadCache = null;
const loadUploadCache = () =>
  (uploadCache ??= existsSync(uploadCacheFile) ? JSON.parse(readFileSync(uploadCacheFile, 'utf8')) : {});
const saveUploadCache = () => writeFileSync(uploadCacheFile, JSON.stringify(loadUploadCache(), null, 2), 'utf8');

/**
 * An https link is kept as-is; a local file is uploaded to
 * {folder}/{shopId}/ (only when new or changed) and its public link
 * returned. The link ends with ?v=<hash>, so phones show a replaced image
 * right away instead of an old cached copy.
 */
async function imageUrl(image, folder, shopId) {
  if (!image) return null;
  if (/^https:\/\//.test(image)) return image;
  const file = join(here, image);
  const path = `${folder}/${shopId}/${basename(file)}`;
  const bytes = readFileSync(file);
  const hash = createHash('sha1').update(bytes).digest('hex').slice(0, 12);
  const cache = loadUploadCache();
  if (cache[path] !== hash) {
    const key = supabaseKey();
    const res = await fetch(`${SUPABASE_URL}/storage/v1/object/${SUPABASE_BUCKET}/${path}`, {
      method: 'POST',
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        'Content-Type': IMAGE_TYPES[extname(file).toLowerCase()],
        'x-upsert': 'true',
      },
      body: bytes,
    });
    if (!res.ok) throw new Error(`Image upload failed for ${image}: ${res.status} ${await res.text()}`);
    cache[path] = hash;
    saveUploadCache();
  }
  return `${SUPABASE_URL}/storage/v1/object/public/${SUPABASE_BUCKET}/${path}?v=${hash}`;
}

// ----------------------------------------------------------------- firebase

async function firebase() {
  const keyFile = join(here, 'service-account.json');
  if (!existsSync(keyFile)) {
    console.error('Missing tool/cafes/service-account.json — see tool/cafes/README.md.');
    process.exit(1);
  }
  const { initializeApp, cert } = await import('firebase-admin/app');
  const { getFirestore, FieldValue } = await import('firebase-admin/firestore');
  const { getAuth } = await import('firebase-admin/auth');
  initializeApp({ credential: cert(JSON.parse(readFileSync(keyFile, 'utf8'))) });
  return { db: getFirestore(), auth: getAuth(), FieldValue };
}

// ----------------------------------------------------------------- handover

/** Nothing there: missing, blank, 0, or an empty list/map. */
const isBlank = (v) => v == null || v === '' || v === 0 ||
  (Array.isArray(v) && v.length === 0) ||
  (typeof v === 'object' && !Array.isArray(v) && Object.keys(v).length === 0);

// Details the owner may have entered at sign-up that fill gaps in the
// listing (the listing's own details always win).
const FILLABLE = ['description', 'phoneNumber', 'website', 'facebookUrl', 'instagramUrl', 'tiktokUrl',
  'logoUrl', 'bannerUrl', 'photoUrls', 'operatingHours', 'coffeeTypes', 'atmospheres', 'amenities'];
const LOCATION = ['address', 'latitude', 'longitude', 'locationType', 'mallId', 'mallName', 'mallFloor',
  'mallUnit', 'mallLandmark'];

/**
 * Hands Kafelo-managed café [cafeId] over to the owner account [email]:
 * the café keeps its id, reviews, rating, favorites and menu; the owner's
 * empty sign-up café is deleted (an owner has exactly one café); details
 * the owner already entered fill any gaps; and the café leaves cafes.json
 * so future imports never overwrite the owner's edits.
 */
async function assign(cafeId, email) {
  if (!cafeId || !email) {
    console.error('Usage: node import_cafes.mjs --assign <cafe-id> <owner-email> [--dry-run]');
    process.exit(1);
  }
  const { db, auth, FieldValue } = await firebase();
  const fail = (msg) => {
    console.error(`✗ ${msg}`);
    process.exit(1);
  };

  let user;
  try {
    user = await auth.getUserByEmail(email.trim());
  } catch {
    fail(`No Kafelo account with the email ${email}. Ask the owner to sign up first (Business Sign Up).`);
  }
  const profile = (await db.collection('users').doc(user.uid).get()).data();
  if (profile?.role !== 'owner') {
    fail(`${email} is not a Coffee Shop Owner account (it must be created with Business Sign Up).`);
  }

  const cafeRef = db.collection('shops').doc(cafeId);
  const cafe = await cafeRef.get();
  if (!cafe.exists) fail(`No café with id "${cafeId}" in Firebase. Check the id in cafes.json.`);
  const listing = cafe.data();
  if (listing.ownerId === user.uid) fail(`${listing.name} already belongs to ${email}.`);
  if (listing.ownerId) fail(`${listing.name} already belongs to another owner account.`);

  // The owner's own café — normally the single empty one from sign-up.
  const own = (await db.collection('shops').where('ownerId', '==', user.uid).get()).docs;
  for (const doc of own) {
    const [menu, reviews, coffeeReviews] = await Promise.all(
      ['menu', 'reviews', 'coffeeReviews'].map((c) => doc.ref.collection(c).limit(1).get()));
    if (!menu.empty || !reviews.empty || !coffeeReviews.empty) {
      fail(`${email} already has a café with a menu or reviews ("${doc.data().name}", shops/${doc.id}). ` +
        'Nothing was changed — merge them by hand in the Firebase console instead.');
    }
  }

  // Fill gaps in the listing with what the owner entered at sign-up.
  const fill = {};
  for (const doc of own) {
    const theirs = doc.data();
    for (const key of FILLABLE) {
      if (isBlank(listing[key]) && !isBlank(theirs[key]) && !(key in fill)) fill[key] = theirs[key];
    }
    const listingHasSpot = !isBlank(listing.latitude) || !isBlank(listing.longitude);
    const theirsHasSpot = !isBlank(theirs.latitude) || !isBlank(theirs.longitude);
    if (!listingHasSpot && theirsHasSpot && !('latitude' in fill)) {
      for (const key of LOCATION) fill[key] = theirs[key] ?? null;
    }
  }

  console.log(`${dryRun ? '[dry run — nothing changed] ' : ''}Hand "${listing.name}" (shops/${cafeId}) to ${email}`);
  console.log(`  • owner account: ${profile.fullName ?? ''} (${user.uid})`);
  console.log('  • the café keeps its reviews, rating, favorites, views and menu');
  if (Object.keys(fill).length) console.log(`  • fills in from their sign-up: ${Object.keys(fill).join(', ')}`);
  for (const doc of own) console.log(`  • deletes their empty sign-up café "${doc.data().name}" (shops/${doc.id})`);
  console.log(`  • removes "${cafeId}" from cafes.json — the owner edits it in the app from now on`);
  if (dryRun) return;

  await cafeRef.update({ ...fill, ownerId: user.uid, managedBy: FieldValue.delete() });
  for (const doc of own) await db.recursiveDelete(doc.ref);
  await db.collection('users').doc(user.uid).set({ shopName: listing.name }, { merge: true });

  const file = join(here, 'cafes.json');
  const data = JSON.parse(readFileSync(file, 'utf8'));
  data.cafes = data.cafes.filter((c) => c.id !== cafeId);
  writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');

  console.log(`✓ Done. ${email} now manages ${listing.name}. If they're signed in, they should sign out and back in.`);
}

// ----------------------------------------------------------------- import

async function main() {
  if (args.has('--assign')) {
    const i = argv.indexOf('--assign');
    return assign(argv[i + 1], argv[i + 2]);
  }

  const data = JSON.parse(readFileSync(join(here, 'cafes.json'), 'utf8'));
  const errors = validate(data);
  if (errors.length) {
    console.error(`cafes.json has ${errors.length} problem(s):\n  - ${errors.join('\n  - ')}`);
    process.exit(1);
  }
  const cafes = data.cafes;
  console.log(`cafes.json OK — ${cafes.length} cafés, ${cafes.reduce((n, c) => n + (c.menu?.length ?? 0), 0)} coffees.`);
  if (dryRun) return;

  const { db, FieldValue } = await firebase();

  for (const cafe of cafes) {
    const ref = db.collection('shops').doc(cafe.id);
    const existing = await ref.get();
    if (existing.exists && existing.data().ownerId) {
      console.warn(`! Skipped ${cafe.name}: shops/${cafe.id} belongs to an owner account.`);
      continue;
    }

    const [logoUrl, bannerUrl, ...photoUrls] = await Promise.all([
      imageUrl(cafe.logo, 'logos', cafe.id),
      imageUrl(cafe.banner, 'banners', cafe.id),
      ...(cafe.photos ?? []).map((p) => imageUrl(p, 'gallery', cafe.id)),
    ]);
    const mall = cafe.mall;
    const listing = {
      ownerId: null,
      managedBy: 'kafelo', // added by the import, not an owner account
      name: cafe.name.trim(),
      description: (cafe.description ?? '').trim(),
      address: cafe.address.trim(),
      // 0, 0 = location not set yet (no map pin, no distance) — as in the app.
      latitude: cafe.latitude ?? 0,
      longitude: cafe.longitude ?? 0,
      locationType: mall ? 'mall' : 'standalone',
      mallId: mall ? mallKey(mall.name) : null,
      mallName: mall ? mall.name.trim() : null,
      mallFloor: mall?.floor?.trim() || null,
      mallUnit: mall?.unit?.trim() || null,
      mallLandmark: mall?.landmark?.trim() || null,
      phoneNumber: cafe.phoneNumber?.trim() || null,
      website: cafe.website?.trim() || null,
      facebookUrl: cafe.facebookUrl?.trim() || null,
      instagramUrl: cafe.instagramUrl?.trim() || null,
      tiktokUrl: cafe.tiktokUrl?.trim() || null,
      operatingHours: cafe.hours ?? {},
      temporarilyClosed: false,
      coffeeTypes: cafe.coffeeTypes ?? [],
      atmospheres: cafe.atmospheres ?? [],
      amenities: cafe.amenities ?? [],
      logoUrl,
      bannerUrl,
      photoUrls,
    };
    // mergeFields replaces these fields completely (so a removed day,
    // photo or feature really disappears) and leaves the stats alone.
    if (existing.exists) {
      await ref.set(listing, { mergeFields: Object.keys(listing) });
    } else {
      await ref.set({
        ...listing,
        rating: 0,
        viewCount: 0,
        favoritesCount: 0,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    // Menu: add/update every coffee, remove the ones taken out of cafes.json.
    const menuRef = ref.collection('menu');
    const keep = new Set();
    for (const item of cafe.menu ?? []) {
      const id = item.id ?? slug(item.name);
      keep.add(id);
      const itemRef = menuRef.doc(id);
      const fields = {
        name: item.name.trim(),
        description: (item.description ?? '').trim(),
        price: item.price ?? null,
        category: item.category,
        available: item.available ?? true,
        bestSeller: item.bestSeller ?? false,
        featured: item.featured ?? false,
        imageUrl: await imageUrl(item.image, 'best-sellers', cafe.id),
        updatedAt: FieldValue.serverTimestamp(),
      };
      const before = await itemRef.get();
      if (before.exists) await itemRef.set(fields, { mergeFields: Object.keys(fields) });
      else await itemRef.set({ ...fields, likeCount: 0, createdAt: FieldValue.serverTimestamp() });
    }
    for (const doc of (await menuRef.get()).docs) {
      if (!keep.has(doc.id)) await db.recursiveDelete(doc.ref);
    }
    console.log(`✓ ${cafe.name}${existing.exists ? ' (updated)' : ' (added)'} — ${keep.size} coffee(s)`);
  }

  // Kafelo-managed cafés no longer in cafes.json.
  const listed = new Set(cafes.map((c) => c.id));
  const managed = await db.collection('shops').where('managedBy', '==', 'kafelo').get();
  for (const doc of managed.docs) {
    if (listed.has(doc.id)) continue;
    if (prune) {
      await db.recursiveDelete(doc.ref);
      console.log(`✗ Deleted ${doc.data().name} (removed from cafes.json)`);
    } else {
      console.warn(`! ${doc.data().name} (shops/${doc.id}) is no longer in cafes.json — run with --prune to delete it and its reviews.`);
    }
  }
  console.log('Done.');
}

// Exit when done — Firebase keeps its connection open otherwise.
main().then(
  () => process.exit(0),
  (e) => {
    console.error(e.message ?? e);
    process.exit(1);
  },
);
