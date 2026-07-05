import { Link } from 'react-router-dom';
import { Eye, EyeOff } from 'lucide-react';
import type { AniListMedia } from '../types/anilist';
import { displayTitle } from '../types/anilist';

interface Props {
  media: AniListMedia;
  hidden?: boolean;
  onToggleHidden?: () => void;
  actions?: React.ReactNode;
  airingTime?: string;
  airingEpisode?: number;
  compact?: boolean;
}

export default function AnimeCard({
  media,
  hidden,
  onToggleHidden,
  actions,
  airingTime,
  airingEpisode,
  compact,
}: Props) {
  const title = displayTitle(media);
  const cover = media.coverImage?.large || media.coverImage?.medium;

  return (
    <article className={`group relative bg-surface-raised border border-surface-border rounded-xl overflow-hidden hover:border-accent/50 transition-colors ${compact ? 'text-xs' : ''}`}>
      <Link to={`/anime/${media.id}`} className="block">
        <div className="aspect-[2/3] bg-surface overflow-hidden">
          {cover ? (
            <img
              src={cover}
              alt={title}
              className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
              loading="lazy"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-gray-500 text-sm p-4 text-center">
              {title}
            </div>
          )}
        </div>
        <div className={compact ? 'p-2' : 'p-3'}>
          <h3 className={`font-medium line-clamp-2 leading-snug ${compact ? 'text-xs' : 'text-sm'}`}>{title}</h3>
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1 mt-1">
            {airingTime && (
              <p className="text-xs text-accent font-medium">
                {airingTime}
                {airingEpisode != null && ` · Ep. ${airingEpisode}`}
              </p>
            )}
            {media.averageScore != null && (
              <p className="text-xs text-gray-400">{media.averageScore / 10}/10</p>
            )}
          </div>
        </div>
      </Link>
      <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
        {onToggleHidden && (
          <button
            type="button"
            onClick={e => {
              e.preventDefault();
              onToggleHidden();
            }}
            className="p-1.5 rounded-md bg-black/70 hover:bg-black/90 text-white"
            title={hidden ? 'Afficher' : 'Masquer'}
          >
            {hidden ? (
              <Eye className="w-4 h-4" aria-hidden />
            ) : (
              <EyeOff className="w-4 h-4" aria-hidden />
            )}
          </button>
        )}
        {actions}
      </div>
      {hidden && (
        <div className="absolute inset-0 bg-black/40 pointer-events-none flex items-center justify-center">
          <span className="text-xs bg-black/60 px-2 py-1 rounded">Masqué</span>
        </div>
      )}
    </article>
  );
}
