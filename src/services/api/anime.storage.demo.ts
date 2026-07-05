/**
 * Demo/Test helper pour tester la logique de reclassification
 * À exécuter dans la console du navigateur
 * 
 * Importer et exécuter :
 * import { runTests } from './anime.storage.test';
 * runTests();
 */

import { classifyAnime, testCases } from './anime.storage.test';

export const runTests = () => {
    console.log('🧪 Lancement des tests de reclassification...\n');

    let passed = 0;
    let failed = 0;

    Object.values(testCases).forEach((testCase) => {
        const result = classifyAnime(testCase.anime);
        const success = result === testCase.expected;

        if (success) {
            console.log(`✅ PASS: ${testCase.name}`);
            console.log(`   Résultat: ${result} ✓\n`);
            passed++;
        } else {
            console.log(`❌ FAIL: ${testCase.name}`);
            console.log(`   Attendu: ${testCase.expected}`);
            console.log(`   Reçu: ${result}\n`);
            failed++;
        }
    });

    console.log(`\n📊 Résultats: ${passed}/${passed + failed} tests réussis`);
    if (failed === 0) {
        console.log('🎉 Tous les tests sont passés!');
    }

    return { passed, failed };
};

// Export pour la console
declare global {
    interface Window {
        testAnimeMClassification: {
            runTests: typeof runTests;
            classifyAnime: typeof classifyAnime;
            testCases: typeof testCases;
        };
    }
}

if (typeof window !== 'undefined') {
    (window as any).testAnimeClassification = {
        runTests,
        classifyAnime,
        testCases,
    };
    console.log('✅ Test helper disponible: window.testAnimeClassification');
    console.log('   Utiliser: window.testAnimeClassification.runTests()');
}

export { classifyAnime, testCases };
