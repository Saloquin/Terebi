import { useCallback, useEffect, useState } from 'react';
import { ExternalLink, Save } from 'lucide-react';
import { api } from '../api/client';
import ErrorMessage from '../components/ErrorMessage';
import LoadingSpinner from '../components/LoadingSpinner';
import type { UserSettings } from '../types/anilist';

export default function SettingsPage() {
  const [form, setForm] = useState<UserSettings>({
    extension: 'to',
    anilistClientId: '',
    anilistClientSecret: '',
    anilistAccessToken: '',
  });
  const [hasClientSecret, setHasClientSecret] = useState(false);
  const [hasAccessToken, setHasAccessToken] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const settings = await api.getSettings();
      setForm({
        extension: settings.extension || 'to',
        anilistClientId: settings.anilistClientId || '',
        anilistClientSecret: '',
        anilistAccessToken: '',
      });
      setHasClientSecret(Boolean(settings.hasClientSecret));
      setHasAccessToken(Boolean(settings.hasAccessToken));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de chargement');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSaved(false);
    try {
      const payload: Partial<UserSettings> = {
        extension: form.extension,
        anilistClientId: form.anilistClientId,
      };
      if (form.anilistClientSecret) {
        payload.anilistClientSecret = form.anilistClientSecret;
      }
      if (form.anilistAccessToken) {
        payload.anilistAccessToken = form.anilistAccessToken;
      }
      const updated = await api.saveSettings(payload);
      setHasClientSecret(Boolean(updated.hasClientSecret));
      setHasAccessToken(Boolean(updated.hasAccessToken));
      setForm(prev => ({
        ...prev,
        anilistClientSecret: '',
        anilistAccessToken: '',
      }));
      setSaved(true);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Erreur de sauvegarde');
    } finally {
      setSaving(false);
    }
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

      <form onSubmit={handleSubmit} className="space-y-6">
        <section className="rounded-xl border border-surface-border bg-surface-raised p-5 space-y-4">
          <div>
            <h2 className="text-lg font-semibold">AniList API</h2>
            <p className="text-sm text-gray-400 mt-1">
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
              value={form.anilistClientId || ''}
              onChange={e => setForm(prev => ({ ...prev, anilistClientId: e.target.value }))}
              placeholder="Votre Client ID AniList"
              className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
            />
          </label>

          <label className="block space-y-1.5">
            <span className="text-sm text-gray-300">
              Client Secret
              {hasClientSecret && (
                <span className="text-gray-500 ml-2">(déjà configuré — laissez vide pour conserver)</span>
              )}
            </span>
            <input
              type="password"
              value={form.anilistClientSecret || ''}
              onChange={e => setForm(prev => ({ ...prev, anilistClientSecret: e.target.value }))}
              placeholder={hasClientSecret ? '••••••••' : 'Votre Client Secret'}
              className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
              autoComplete="off"
            />
          </label>

          <label className="block space-y-1.5">
            <span className="text-sm text-gray-300">
              Access Token (optionnel)
              {hasAccessToken && (
                <span className="text-gray-500 ml-2">(déjà configuré — laissez vide pour conserver)</span>
              )}
            </span>
            <input
              type="password"
              value={form.anilistAccessToken || ''}
              onChange={e => setForm(prev => ({ ...prev, anilistAccessToken: e.target.value }))}
              placeholder={hasAccessToken ? '••••••••' : 'Bearer token OAuth2'}
              className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
              autoComplete="off"
            />
            <p className="text-xs text-gray-500">
              Requis si l&apos;API renvoie une erreur 401. Obtenez un token via le flux OAuth2
              AniList (authorization code) ou laissez vide pour les requêtes publiques.
            </p>
          </label>
        </section>

        <section className="rounded-xl border border-surface-border bg-surface-raised p-5 space-y-4">
          <h2 className="text-lg font-semibold">Anime-sama</h2>
          <label className="block space-y-1.5">
            <span className="text-sm text-gray-300">Extension de site</span>
            <input
              type="text"
              value={form.extension}
              onChange={e => setForm(prev => ({ ...prev, extension: e.target.value }))}
              placeholder="to"
              className="w-full px-4 py-2 rounded-lg bg-surface border border-surface-border focus:border-accent focus:outline-none"
            />
          </label>
        </section>

        <div className="flex items-center gap-4">
          <button
            type="submit"
            disabled={saving}
            className="inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-accent hover:bg-accent-hover text-white font-medium disabled:opacity-50"
          >
            <Save className="w-4 h-4" aria-hidden />
            {saving ? 'Enregistrement…' : 'Enregistrer'}
          </button>
          {saved && <span className="text-sm text-green-400">Paramètres enregistrés</span>}
        </div>
      </form>
    </div>
  );
}
