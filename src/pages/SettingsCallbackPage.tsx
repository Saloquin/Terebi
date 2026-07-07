import { useEffect, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../api/client';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import {
  consumeOAuthCredentials,
  consumeTokenFromHash,
  setAnilistToken,
} from '../lib/storage';

const CALLBACK_TIMEOUT_MS = 10_000;

export default function SettingsCallbackPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  const [timedOut, setTimedOut] = useState(false);
  const completedRef = useRef(false);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (!completedRef.current) setTimedOut(true);
    }, CALLBACK_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
  }, []);

  useEffect(() => {
    const run = async () => {
      const finish = () => {
        completedRef.current = true;
      };

      const tokenFromHash = consumeTokenFromHash();
      if (tokenFromHash) {
        finish();
        navigate('/settings', { replace: true, state: { oauthSuccess: true } });
        return;
      }

      const status = searchParams.get('anilist');
      if (status === 'error') {
        const message = searchParams.get('message') || 'Échec de la connexion AniList.';
        finish();
        setError(message);
        return;
      }

      const code = searchParams.get('code')?.trim();
      if (!code) {
        finish();
        setError('Code OAuth manquant.');
        return;
      }

      const creds = consumeOAuthCredentials();
      if (!creds) {
        finish();
        setError(
          'Identifiants OAuth expirés ou introuvables (sessionStorage perdu). Reconnectez-vous depuis les paramètres en saisissant à nouveau Client ID et Client Secret.',
        );
        return;
      }

      try {
        const { accessToken } = await api.exchangeAuthCode(
          code,
          creds.clientId,
          creds.clientSecret,
          creds.redirectUri,
        );
        setAnilistToken(accessToken);
        finish();
        navigate('/settings', { replace: true, state: { oauthSuccess: true } });
      } catch (e) {
        finish();
        setError(e instanceof Error ? e.message : "Échec de l'échange OAuth");
      }
    };

    void run();
  }, [navigate, searchParams]);

  if (error) {
    return (
      <div className="max-w-lg space-y-4">
        <h1 className="text-xl font-semibold">Connexion AniList</h1>
        <ErrorMessage message={error} onRetry={() => navigate('/settings')} showSettingsLink />
      </div>
    );
  }

  if (timedOut) {
    return (
      <div className="max-w-lg space-y-4">
        <h1 className="text-xl font-semibold">Connexion AniList</h1>
        <ErrorMessage
          message="La connexion prend trop de temps. Vérifiez que l'API est accessible et que le Redirect URI enregistré sur AniList correspond exactement à celui affiché dans les paramètres."
          onRetry={() => navigate('/settings')}
          showSettingsLink
        />
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <h1 className="text-xl font-semibold">Connexion AniList</h1>
      <LoadingSpinner />
      <p className="text-sm text-gray-400">Échange du code OAuth en cours…</p>
    </div>
  );
}
