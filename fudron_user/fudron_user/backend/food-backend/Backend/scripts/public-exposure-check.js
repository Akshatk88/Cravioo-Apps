/**
 * Asserts that no public endpoint hands out a seller's private data.
 *
 * Written after `GET /food/restaurant/restaurants/:id` was found returning the
 * entire restaurant document to anonymous callers — bank account number, IFSC,
 * PAN number and a URL to the scan of the PAN card among them. The fix is an
 * allowlist projection; this is the check that stops it regressing, because the
 * failure mode is silent: nothing errors, the response merely contains too much.
 *
 *   node scripts/public-exposure-check.js [baseUrl]
 *
 * Runs against a live host with no credentials, which is the only way to test
 * what an anonymous caller actually receives.
 *
 * Note the cache: /restaurants/:id sits behind cacheResponse(600). After
 * deploying a projection change, purge the `restaurant_detail:*` keys or this
 * will keep reporting the pre-fix payload for up to ten minutes.
 */
const BASE = process.argv[2] || 'https://suvio.appzeto.com/api/v1';

/** Nothing here may ever appear in a response served without authentication. */
const FORBIDDEN = [
  'accountNumber', 'accountHolderName', 'accountType', 'ifscCode', 'upiId',
  'upiQrImage',
  'nameOnPan', 'panNumber', 'panImage',
  'gstImage', 'gstRegistered', 'gstNumber', 'gstLegalName', 'gstAddress',
  'fssaiNumber', 'fssaiImage', 'fssaiExpiry',
  'ownerName', 'ownerEmail', 'ownerPhone', 'ownerPhoneDigits',
  'ownerPhoneLast10', 'primaryContactNumber',
  'password', 'fcmTokens', 'fcmTokenMobile', 'tokenVersion',
  'subscriptionAmount', 'subscriptionDueAmount', 'subscriptionPaidAmount',
  'subscriptionAutoDeductedAmount', 'subscriptionStatus', 'subscriptionPlan',
  'onboardingFeeAmount', 'onboardingFeePaid', 'onboardingFeePaymentId',
  'onboardingFeePaymentOrderId', 'onboardingFeePaymentSignature',
];

let failures = 0;

/** Walks the whole payload: a leak nested one level down is still a leak. */
function scan(node, path, label) {
  if (Array.isArray(node)) {
    node.forEach((v, i) => scan(v, `${path}[${i}]`, label));
    return;
  }
  if (!node || typeof node !== 'object') return;

  for (const key of Object.keys(node)) {
    if (FORBIDDEN.includes(key)) {
      console.log(`  LEAK  ${label} -> ${path}.${key} = ${JSON.stringify(node[key]).slice(0, 40)}`);
      failures++;
    }
    scan(node[key], `${path}.${key}`, label);
  }
}

async function getJson(url) {
  const res = await fetch(url);
  if (!res.ok) return null;
  // A route that does not exist answers with an HTML error page, which would
  // otherwise blow up JSON.parse and abort the whole run.
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

async function check(label, url) {
  const body = await getJson(url);
  if (!body) {
    console.log(`  skip  ${label} (no JSON response)`);
    return;
  }
  const before = failures;
  scan(body?.data, 'data', label);
  if (failures === before) console.log(`  ok    ${label}`);
}

async function main() {
  console.log(`checking ${BASE} with no credentials\n`);

  // The public listing is the id source on purpose: it is exactly how an
  // outsider would find a restaurant id to probe with.
  const list = await getJson(`${BASE}/food/restaurant/restaurants?limit=5`);
  const restaurants = list?.data?.restaurants || list?.data?.list || [];
  const ids = restaurants.map((r) => r?._id).filter(Boolean);

  if (ids.length === 0) {
    console.error('no restaurant id available to test with');
    process.exit(1);
  }

  await check('restaurant/restaurants', `${BASE}/food/restaurant/restaurants?limit=5`);
  for (const id of ids.slice(0, 3)) {
    await check(`restaurants/${id}`, `${BASE}/food/restaurant/restaurants/${id}`);
    await check(`restaurants/${id}/menu`, `${BASE}/food/restaurant/restaurants/${id}/menu`);
  }
  await check('restaurant/public/foods', `${BASE}/food/restaurant/public/foods?limit=5`);
  await check('search/unified', `${BASE}/food/search/unified?q=a`);

  console.log(`\n${failures === 0 ? 'PASS — no private field exposed' : `FAIL — ${failures} leaked field(s)`}`);
  process.exit(failures === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error('check failed to run:', err.message);
  process.exit(1);
});
