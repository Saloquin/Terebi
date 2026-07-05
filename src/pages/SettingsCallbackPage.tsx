import { useEffect, useState } from 'react';

import { useNavigate, useSearchParams } from 'react-router-dom';

import { api } from '../api/client';

import ErrorMessage from '../components/ErrorMessage';

import LoadingSpinner from '../components/LoadingSpinner';

import { consumeOAuthCredentials, consumeTokenFromHash, setAnilistToken, DEFAULT_ANILIST_REDIRECT_URI } from '../lib/storage';



export default function SettingsCallbackPage() {

  const [searchParams] = useSearchParams();

  const navigate = useNavigate();

  const [error, setError] = useState<string | null>(null);



  useEffect(() => {

    const run = async () => {

      const tokenFromHash = consumeTokenFromHash();

      if (tokenFromHash) {

        navigate('/settings', { replace: true, state: { oauthSuccess: true } });

        return;

      }



      const status = searchParams.get('anilist');

      if (status === 'error') {

        const message = searchParams.get('message') || 'Échec de la connexion AniList.';

        setError(message);

        return;

      }



      const code = searchParams.get('code')?.trim();

      if (!code) {

        setError('Code OAuth manquant.');

        return;

      }



      const creds = consumeOAuthCredentials();

      if (!creds) {

        setError('Identifiants OAuth expirés — reconnectez-vous depuis les paramètres.');

        return;

      }



      try {

        const { accessToken } = await api.exchangeAuthCode(

          code,

          creds.clientId,

          creds.clientSecret,

          DEFAULT_ANILIST_REDIRECT_URI

        );

        setAnilistToken(accessToken);

        navigate('/settings', { replace: true, state: { oauthSuccess: true } });

      } catch (e) {

        setError(e instanceof Error ? e.message : 'Échec de l\'échange OAuth');

      }

    };



    void run();

  }, [navigate, searchParams]);



  if (error) {

    return (

      <div className="max-w-lg space-y-4">

        <ErrorMessage message={error} onRetry={() => navigate('/settings')} />

      </div>

    );

  }



  return <LoadingSpinner />;

}


