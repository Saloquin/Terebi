interface Props {
  message?: string;
}

export default function LoadingSpinner({ message = 'Chargement…' }: Props) {
  return (
    <div className="flex flex-col items-center justify-center py-16 gap-3 text-gray-400">
      <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      <p className="text-sm">{message}</p>
    </div>
  );
}
