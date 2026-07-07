import { useCallback, useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { ExternalLink, Link2, Trash2 } from 'lucide-react';
import { api } from '../api/client';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import {
  clearAnilistToken,
  getAnilistRedirectUri,
  getAnilistToken,
  storeOAuthCredentials,
} from '../lib/storage';

export default function SettingsPage() {
  const location = useLocation();
  const [clientId, setClientId] = useState('');
  const [clientSecret, setClientSecret] = useState('');
  const [extension, setExtension] = useState('to');
  const [connected, setConnected] = useState(false);
  const [username, setUsername] = useState<string | null>(null);
  const [redirectUri, setRedirectUri] = useState(getAnilistRedirectUri);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const loadStatus = useCallback(async () => {
    if (!getAnilistToken()) {
      setConnected(false);
      setUsername(null);
      return;
    }
    try {
      const status = await api.getOAuthStatus();
      setConnected(status.connected);
      setUsername(status.username ?? null);
      if (status.expired) {
        clearAnilistToken();
        setConnected(false);
        setUsername(null);
        setError('Votre token AniList est invalide ou expiré. Reconnectez votre compte.');
      }
    } catch {
      setConnected(false);
      setUsername(null);
    }
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const config = await api.getConfig();
      setExtension(config.extension || 'to');
      await loadStatus();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      setLoading(false);
    }
  }, [loadStatus]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const state = location.state as { oauthSuccess?: boolean } | null;
    if (state?.oauthSuccess) {
      setMessage('Connexion AniList réussie.');
      void loadStatus();
      window.history.replaceState({}, '', location.pathname);
    }
  }, [location, loadStatus]);

  const handleSaveExtension = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setMessage(null);
    try {
      await api.setExtension(extension);
      setMessage('Extension enregistrée.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de sauvegarde');
    } finally {
      setSaving(false);
    }
  };

  const handleConnect = async () => {
    setConnecting(true);
    setError(null);
    setMessage(null);
    try {
      const id = clientId.trim();
      const secret = clientSecret.trim();
      if (!id || !secret) {
        setError('Saisissez votre Client ID et Client Secret avant de connecter.');
        return;
      }
      storeOAuthCredentials(id, secret);
      const { url, redirectUri: uri } = await api.buildOAuthUrl(id, redirectUri);
      setRedirectUri(uri);
      setClientSecret('');
      window.location.href = url;
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de connexion');
    } finally {
      setConnecting(false);
    }
  };

  const handleDisconnect = () => {
    clearAnilistToken();
    setConnected(false);
    setUsername(null);
    setMessage('Compte AniList déconnecté.');
  };

  if (loading) return <LoadingSpinner />;

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-bold">Paramètres</h1>
        <p className="text-sm text-gray-400 mt-1">
          Configuration AniList et préférences de l&apos;application
        </p>
      </div>

      {error && <ErrorMessage message={error} onRetry={load} />}
      {message && <p className="text-sm text-green-400">{message}</p>}

      <section className="rounded-xl border border-surface-border bg-surface-raised p-5 space-y-4">
        <div>
          <h2 className="text-lg font-semibold">AniList — Connexion OAuth</h2>
          <p className="text-sm text-gray-400 mt-1">
            Le planning, le catalogue et la recherche fonctionnent sans connexion.
            Connectez votre compte uniquement pour synchroniser vos listes AniList.
          </p>
          <p className="text-sm text-gray-400 mt-2">
            Créez une application sur{' '}
            <a
              href="https://anilist.co/settings/developer"
              target="_blank"
              rel="noopener noreferrer"
              className="text-accent hover:text-accent-hover inline-flex items-center gap-1"
            >
              anilist.co/settings/developer
              <ExternalLink className="w-3.5 h-3.5" aria-hidden />
            </a>
          </p>
        </div>

        <label className="block space-y-1.5">
          <span className="text-sm text-gray-300">Client ID</span>
          <input
            type="text"
            value={clientId}
            onChange={e => setClientId(e.target.value)}
            placeholder="Votre Client ID AniList"
            className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
            autoComplete="off"
          />
        </label>

        <label className="block space-y-1.5">
          <span className="text-sm text-gray-300">Client Secret</span>
          <input
            type="password"
            value={clientSecret}
            onChange={e => setClientSecret(e.target.value)}
            placeholder="Votre Client Secret"
            className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
            autoComplete="off"
          />
        </label>

        <p className="text-xs text-gray-500">
          Les identifiants ne sont pas enregistrés — utilisés uniquement pour la connexion OAuth.
          Seul le token AniList est conservé localement.
        </p>

        <p className="text-xs text-gray-500">
          Redirect URI à enregistrer sur AniList :{' '}
          <code className="bg-surface px-1.5 py-0.5 rounded">{redirectUri}</code>
        </p>

        <div className="flex flex-wrap items-center gap-3 pt-1">
          <button
            type="button"
            onClick={handleConnect}
            disabled={connecting}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-accent hover:bg-accent-hover text-white font-medium disabled:opacity-50"
          >
            <Link2 className="w-4 h-4" aria-hidden />
            {connecting ? 'Redirection…' : connected ? 'Reconnecter AniList' : 'Connecter AniList'}
          </button>
          {connected && (
            <>
              <span className="text-sm text-green-400">
                Connecté{username ? ` — ${username}` : ''}
              </span>
              <button
                type="button"
                onClick={handleDisconnect}
                className="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg border border-red-500/50 text-red-400 hover:bg-red-500/10 text-sm"
              >
                <Trash2 className="w-4 h-4" aria-hidden />
                Déconnecter
              </button>
            </>
          )}
        </div>
      </section>

      <form onSubmit={handleSaveExtension} className="rounded-xl border border-surface-border bg-surface-raised p-5 space-y-4">
        <h2 className="text-lg font-semibold">Anime-sama</h2>
        <label className="block space-y-1.5">
          <span className="text-sm text-gray-300">Extension de site</span>
          <input
            type="text"
            value={extension}
            onChange={e => setExtension(e.target.value)}
            placeholder="to"
            className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
          />
        </label>
        <button
          type="submit"
          disabled={saving}
          className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-surface-raised border border-surface-border hover:bg-surface font-medium disabled:opacity-50"
        >
          {saving ? 'Enregistrement…' : 'Enregistrer l\'extension'}
        </button>
      </form>
    </div>
  );
}

