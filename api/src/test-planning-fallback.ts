/**
 * Run: npx ts-node src/test-planning-fallback.ts
 * Verifies planning fallback when AniList is disabled.
 */
import { AniListApiError } from './services/anilist.service';
import { computeNextAiringFromBroadcast } from './services/jikan.service';
import { isAnilistPlanningUnavailable } from './services/planning-fallback.service';

let passed = 0;
let failed = 0;

function assert(name: string, condition: boolean) {
    if (condition) {
        passed++;
        console.log(`  ✓ ${name}`);
    } else {
        failed++;
        console.error(`  ✗ ${name}`);
    }
}

console.log('planning-fallback tests\n');

assert(
    'ANILIST_DISABLED triggers fallback',
    isAnilistPlanningUnavailable(new AniListApiError('disabled', 503, 'ANILIST_DISABLED'))
);
assert(
    '403 triggers fallback',
    isAnilistPlanningUnavailable(new AniListApiError('forbidden', 403, 'ANILIST_FORBIDDEN'))
);
assert(
    '401 does not trigger fallback',
    !isAnilistPlanningUnavailable(new AniListApiError('auth', 401, 'ANILIST_AUTH'))
);
assert(
    'network error triggers fallback',
    isAnilistPlanningUnavailable(new Error('fetch failed'))
);

const next = computeNextAiringFromBroadcast({ day: 'Mondays', time: '23:00', timezone: 'Asia/Tokyo' });
assert('broadcast maps to next airing timestamp', Boolean(next?.airingAt && next.airingAt > 0));
assert(
    'unknown broadcast day returns undefined',
    computeNextAiringFromBroadcast({ day: 'Unknown', time: '12:00' }) === undefined
);

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
