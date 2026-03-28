#!/usr/bin/env node

const axios = require('axios');

const API_URL = 'http://localhost:3001/api';

async function testSeasonScraping() {
    try {
        console.log('\n🚀 Test de scraping des saisons...\n');
        
        // Attendre que l'API démarre
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        console.log('📝 Test 1: Dr Stone');
        const response1 = await axios.get(`${API_URL}/animes/seasons/dr-stone`);
        console.log('✅ Réponse reçue:');
        console.log(JSON.stringify(response1.data, null, 2));
        
        console.log('\n📝 Test 2: Jujutsu Kaisen');
        const response2 = await axios.get(`${API_URL}/animes/seasons/jujutsu-kaisen`);
        console.log('✅ Réponse reçue:');
        console.log(JSON.stringify(response2.data, null, 2));
        
    } catch (error: any) {
        console.error('❌ Erreur:', error.message);
        if (error.response) {
            console.error('Réponse:', error.response.data);
        }
    }
}

testSeasonScraping();
