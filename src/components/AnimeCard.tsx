import { Link } from 'react-router-dom';
import type { AniListMedia } from '../types/anilist';
import { displayTitle } from '../types/anilist';

interface Props {
  media: AniListMedia;
  hidden?: boolean;
  onToggleHidden?: () => void;
  actions?: React.ReactNode;
}

export default function AnimeCard({ media, hidden, onToggleHidden, actions }: Props) {
  const title = displayTitle(media);
  const cover = media.coverImage?.large || media.coverImage?.medium;

  return (
    <article className="group relative bg-surface-raised border border-surface-border rounded-xl overflow-hidden hover:border-accent/50 transition-colors">
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
        <div className="p-3">
          <h3 className="font-medium text-sm line-clamp-2 leading-snug">{title}</h3>
          {media.averageScore != null && (
            <p className="text-xs text-gray-400 mt-1">{media.averageScore / 10}/10</p>
          )}
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
            className="px-2 py-1 text-xs rounded-md bg-black/70 hover:bg-black/90 text-white"
            title={hidden ? 'Afficher' : 'Masquer'}
          >
            {hidden ? '👁' : '🙈'}
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
