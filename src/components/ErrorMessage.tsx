import { Link } from 'react-router-dom';
import { AlertCircle, Settings } from 'lucide-react';

interface Props {
  message: string;
  onRetry?: () => void;
  showSettingsLink?: boolean;
}

export default function ErrorMessage({ message, onRetry, showSettingsLink }: Props) {
  return (
    <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-red-200">
      <div className="flex items-start gap-3">
        <AlertCircle className="w-5 h-5 shrink-0 mt-0.5" aria-hidden />
        <div className="space-y-3 min-w-0">
          <p className="text-sm">{message}</p>
          {showSettingsLink && (
            <Link
              to="/settings"
              className="inline-flex items-center gap-2 text-sm font-medium text-accent hover:text-accent-hover"
            >
              <Settings className="w-4 h-4" aria-hidden />
              Configurer AniList
            </Link>
          )}
          {onRetry && (
            <button
              type="button"
              onClick={onRetry}
              className="block text-sm underline hover:text-white"
            >
              Réessayer
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
