/** ~18 req/min — conservative under AniList degraded limit of 30/min per IP */
const MIN_INTERVAL_MS = 3300;

function sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
}

class AniListRequestQueue {
    private lastRequestAt = 0;
    private chain: Promise<void> = Promise.resolve();

    enqueue<T>(fn: () => Promise<T>): Promise<T> {
        const run = this.chain.then(async () => {
            const now = Date.now();
            const wait = MIN_INTERVAL_MS - (now - this.lastRequestAt);
            if (wait > 0) await sleep(wait);
            this.lastRequestAt = Date.now();
        });

        this.chain = run.catch(() => {});
        return run.then(() => fn());
    }
}

export const anilistQueue = new AniListRequestQueue();
