/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SITE_EXTENSION: string
  // Ajoutez d'autres variables d'environnement ici si nécessaire
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
