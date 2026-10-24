// The app can be served from the site root (portable / IIS, the default) or from a sub-path behind a
// reverse proxy (e.g. https://host:1976/xcred/). Vite bakes the prefix in at build time from the
// VITE_BASE_PATH env var (see vite.config.ts); everything that builds a URL goes through here.
// BASE_URL always starts and ends with '/', e.g. '/' or '/xcred/'.
export const BASE_PATH: string = import.meta.env.BASE_URL;

/** React Router's `basename`: the prefix without the trailing slash ('' at the root). */
export const ROUTER_BASENAME = BASE_PATH.replace(/\/$/, '');

/** Where the API lives, e.g. '/api' or '/xcred/api'. */
export const API_BASE = `${BASE_PATH}api`;
