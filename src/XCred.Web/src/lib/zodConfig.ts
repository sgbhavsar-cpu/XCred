import { z } from 'zod'

// zod probes for `new Function()` support to JIT-compile its parsers. Our Content-Security-Policy
// (no 'unsafe-eval') blocks that probe — harmlessly, it falls back — but the browser logs a violation each
// time. Opting out of the JIT path keeps the console clean without weakening the policy.
//
// This lives in its own module, imported FIRST by main.tsx: ES imports run in order, and the form pages
// build their zod schemas at module load, so the setting has to be applied before they are imported.
z.config({ jitless: true })
